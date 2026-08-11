"""محیط اجرای مهاجرت‌های Alembic — آدرس دیتابیس از env (DATABASE_URL) خوانده می‌شود."""
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.config import Settings
from app.models import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# متادیتای مدل‌ها — مبنای autogenerate
target_metadata = Base.metadata

settings = Settings()


def _database_url() -> str:
    """اولویت: -x db_url=... سپس DATABASE_URL از تنظیمات."""
    x_args = context.get_x_argument(as_dictionary=True)
    return x_args.get("db_url") or settings.database_url


def run_migrations_offline() -> None:
    """تولید SQL بدون اتصال به دیتابیس (alembic upgrade head --sql)."""
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        render_as_batch=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """اجرای مهاجرت‌ها روی دیتابیس واقعی."""
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = _database_url()
    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            # batch mode برای SQLite لازم است (ALTER محدود دارد)
            render_as_batch=connection.dialect.name == "sqlite",
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
