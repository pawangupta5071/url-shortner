from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.schemas.url import URLCreate, URLResponse
from app.services.url_service import (
    AliasAlreadyExists,
    InvalidExpiry,
    URLExpired,
    URLNotFound,
    create_url,
    resolve_url,
)


router = APIRouter(tags=["URLS"])

DBSession = Annotated[Session,Depends(get_db)]

@router.post("api/v1/urls",response_model=URLResponse,status_code=201)
def shorten_url(data: URLCreate, db: DBSession):
    try:
        url = create_url(data=data,db=db)
    except AliasAlreadyExists:
        raise HTTPException(
            status_code=409,
            detail="Custom Alias already exists"
        )
    except InvalidExpiry as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc)
        )
    except IntegrityError:
        raise HTTPException(
            status_code=409,
            detail="short code already exists"
        )
        
    return URLResponse(
        short_code=url.short_code,
        short_url=f"{settings.base_url.rstrip('/')}/{url.short_code}",
        long_url=url.long_url,
        expires_at=url.expires_at,
    )
        

@router.get("/{short_code}")
def redirect_url(short_code:str, db :DBSession):
    try:
        original_url = resolve_url(short_code=short_code,db=db)
    except URLNotFound:
        raise HTTPException(
            status_code=404,
            detail="Short URL not found"
        )
    except URLExpired:
        raise HTTPException(
            status_code=410,
            detail="Short URL has expired"
        )
    return RedirectResponse(
        url=original_url,
        status_code=302,
    )