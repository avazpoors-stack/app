"""تست مهاجرت‌ها — schema تولیدشده توسط Alembic باید با مدل‌ها یکی باشد.

اگر کسی مدلی را عوض کند و مهاجرت نسازد، این تست قرمز می‌شود.
"""
from pathlib import Path

import pytest
from sqlalchemy import create_engine, inspect

from app.models import Base

pytest.importorskip("alembic", reason="alembic نصب نیست")

from alembic.autogenerate import compare_metadata  # noqa: E402
from alembic.command import upgrade  # noqa: E402
from alembic.config import Config  # noqa: E402
from alembic.migration import MigrationContext  # noqa: E402

SERVER_DIR = Path(__file__).resolve().parents[1]


def _alembic_config(db_url: str) -> Config:
    cfg = Config(str(SERVER_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(SERVER_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    cfg.cmd_opts = None
    return cfg


@pytest.fixture()
def migrated_db(tmp_path, monkeypatch):
    db_file = tmp_path / "migrated.db"
    url = f"sqlite:///{db_file}"
    monkeypatch.setenv("DATABASE_URL", url)
    upgrade(_alembic_config(url), "head")
    return url


def test_migration_creates_all_tables(migrated_db):
    engine = create_engine(migrated_db)
    tables = set(inspect(engine).get_table_names())
    expected = set(Base.metadata.tables) | {"alembic_version"}
    assert expected.issubset(tables), f"جدول‌های جامانده: {expected - tables}"


def test_migration_matches_models(migrated_db):
    """بدون drift: مقایسهٔ schema مهاجرت‌شده با متادیتای مدل‌ها."""
    engine = create_engine(migrated_db)
    with engine.connect() as conn:
        ctx = MigrationContext.configure(conn)
        diff = compare_metadata(ctx, Base.metadata)
    # تفاوت‌های صرفاً نوعی در SQLite نادیده گرفته نمی‌شوند؛ باید خالی باشد
    assert not diff, f"schema با مدل‌ها همگام نیست: {diff}"


def test_init_db_blocked_in_production(monkeypatch):
    """در production ساخت مستقیم جدول‌ها ممنوع است — فقط Alembic."""
    import app.db as db_module

    monkeypatch.setattr(db_module.settings, "env", "production")
    with pytest.raises(RuntimeError, match="alembic"):
        db_module.init_db("sqlite://")
