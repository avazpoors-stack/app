"""دیتابیس — SQLAlchemy با SQLite در توسعه و PostgreSQL در تولید (از DATABASE_URL).

قرارداد: هر سرویس فقط از طریق `get_db` به دیتابیس دست می‌زند (تزریق‌پذیر برای تست).
"""
from typing import Optional

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from .config import Settings
from .models import Base

settings = Settings()

engine: Optional[Engine] = None
SessionLocal: Optional[sessionmaker] = None


def init_db(url: Optional[str] = None) -> None:
    """ساخت موتور و جدول‌ها — در تست با SQLite درون‌حافظه صدا زده می‌شود."""
    global engine, SessionLocal
    url = url or settings.database_url
    kwargs = {"pool_pre_ping": True}
    if url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
    if url == "sqlite://":
        kwargs["poolclass"] = StaticPool
    engine = create_engine(url, **kwargs)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)


def get_db():
    """وابستگی FastAPI — یک نشست دیتابیس در هر درخواست."""
    if SessionLocal is None:
        init_db()
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
