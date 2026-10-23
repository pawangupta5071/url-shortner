from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    String,
    Text,
    func,
    ForeignKey
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

class URL(Base):
    __tablename__ = "urls"
    
    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
        autoincrement=True
    )
    short_code: Mapped[str] = mapped_column(
        String(32),
        unique=True,
        nullable=False
    )
    long_url: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default= func.now(),
        nullable=False
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )
    click_count: Mapped[int] = mapped_column(
        BigInteger,
        default=0,
        server_default="0",
        nullable=False
    )