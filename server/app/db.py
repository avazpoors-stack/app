"""دیتابیس — SQLAlchemy با SQLite در توسعه و PostgreSQL در تولید (از DATABASE_URL).

قرارداد: هر سرویس فقط از طریق `get_db` به دیتابیس دست می‌زند (تزریق‌پذیر برای تست).

ساخت جدول‌ها:
- توسعه/تست: `init_db()` جدول‌ها را می‌سازد (سریع و بدون مهاجرت).
- تولید: فقط Alembic — `alembic upgrade head` (نگاه: server/migrations).
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


def _make_engine(url: str) -> Engine:
    kwargs: dict = {"pool_pre_ping": True}
    if url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
    if url == "sqlite://":
        kwargs["poolclass"] = StaticPool
    return create_engine(url, **kwargs)


def configure_engine(url: Optional[str] = None) -> None:
    """فقط اتصال را آماده می‌کند — هیچ جدولی نمی‌سازد (مسیر امنِ تولید)."""
    global engine, SessionLocal
    url = url or settings.database_url
    engine = _make_engine(url)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def init_db(url: Optional[str] = None) -> None:
    """ساخت موتور و جدول‌ها — فقط توسعه/تست.

    ⚠️ در تولید صدا زدن این تابع خطا می‌دهد؛ آنجا باید `alembic upgrade head` اجرا شود
    تا تغییرات schema قابل ردیابی و برگشت‌پذیر باشد.
    """
    if settings.is_production:
        raise RuntimeError(
            "init_db() در حالت production مجاز نیست. "
            "برای ساخت/به‌روزرسانی جدول‌ها از مهاجرت استفاده کن: alembic upgrade head"
        )
    configure_engine(url)
    Base.metadata.create_all(bind=engine)


def get_db():
    """وابستگی FastAPI — یک نشست دیتابیس در هر درخواست."""
    if SessionLocal is None:
        # در تولید فقط اتصال ساخته می‌شود؛ جدول‌ها کار Alembic است
        configure_engine() if settings.is_production else init_db()
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
