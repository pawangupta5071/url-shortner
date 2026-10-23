from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.url import URL
from app.schemas.url import URLCreate
from app.services.short_code_generator import encode_base62
from app.services.cache import get_cached_url,cache_url



class AliasAlreadyExists(Exception):
    pass

class URLNotFound(Exception):
    pass

class URLExpired(Exception):
    pass

class InvalidExpiry(Exception):
    pass


def create_url(data:URLCreate,db:Session)->URL:
    now = datetime.now(timezone.utc)
    
    if data.expires_at is not None and data.expires_at <= now:
        raise InvalidExpiry("Expiration should be in the future")
    
    if data.custom_alias:
        existing = db.scalar(
            select(URL.id).where(
                URL.short_code == data.custom_alias
            )
        )
        if existing is not None:
            raise AliasAlreadyExists(data.custom_alias)
        
        url = URL(
            short_code = data.custom_alias,
            long_url = data.long_url,
            expires_at = data.expires_at
        )
        db.add(url)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise
        db.refresh(url)
        return url
    
    url = URL(
        short_code="pending",
        long_url=str(data.long_url),
        expires_at=data.expires_at,
    )

    db.add(url)
    db.flush()
    
    url.short_code = encode_base62(url.id)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    
    db.refresh()
    return url
        
    

def resolve_url(short_code:str,db:Session)->str:
    cached_url = get_cached_url(short_code=short_code)
    if cached_url is not None:
        return cached_url
    
    url = db.scalar(
        select(URL).where(URL.short_code == short_code)
    )
        
    if url is None:
        raise URLNotFound(short_code)
    
    now = datetime.now(timezone.utc)
    
    if url.expires_at is not None:
        if url.expires_at <= now:
            raise URLExpired(short_code)
        remaining_seconds = int((url.expires_at-now).total_seconds())
        ttl = min(remaining_seconds,ttl)
    else:
        ttl = 300
    
    if ttl>0:
        cache_url(
            short_code=short_code,
            long_url=url.long_url,
            ttl=ttl
        )
    return url.long_url