from datetime import datetime
from typing import Self
from urllib.parse import urlsplit

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    HttpUrl,
    model_validator
)

class URLCreate(BaseModel):
    long_url: HttpUrl
    custom_alias: str | None = Field(
        default=None,
        min_length=1,
        max_length=32,
        pattern= r"^[a-zA-Z0-9_-]+$"
    )
    expires_at:datetime | None = None
    
    @model_validator(mode="after")
    def validate_url_and_expiry(self)->Self:
        parts = urlsplit(str(self.long_url))
        
        if parts.scheme not in ("http","https"):
            raise ValueError("only HTTP or HTTPS URLs are allowed")
        if self.expires_at is not None:
            if self.expires_at.tzinfo is None:
                raise ValueError("expires_at must include a timzone")
        return self
    
class URLResponse(BaseModel):
    short_code:str
    short_url:str
    long_url:str
    expires_at:datetime | None
    
    model_config = ConfigDict(from_attributes=True)