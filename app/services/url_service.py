from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.url import URL
from app.schemas.url import URLCreate
from app.services.short_code_generator import encode_base62



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
    url = db.scalar(
        select(URL).where(URL.short_code == short_code)
    )
    if url is None:
        raise URLNotFound(short_code)
    
    if (
        url.expires_at is not None 
        and url.expires_at<=datetime.now(timezone.utc)
    ):
        raise URLExpired(short_code)
    return url.long_url