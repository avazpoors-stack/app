"""بک‌اند «بدنه» — پلتفرم ورزشی (P2: حساب‌ها، OTP، سینک).

اجرا (توسعه):
    uvicorn app.main:app --reload
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings
from .db import init_db
from . import auth, sync, search

APP_VERSION = "0.3.0"

settings = Settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # در توسعه جدول‌ها ساخته می‌شوند؛ در production مهاجرت با Alembic (A7)
    init_db()
    yield


app = FastAPI(
    title="Badane API",
    description="بک‌اند پلتفرم ورزشی «بدنه» — حساب‌ها، OTP، سینک آفلاین-اول",
    version=APP_VERSION,
    lifespan=lifespan,
)

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.get("/health")
def health() -> dict:
    """سلامتی سرویس — برای پایش و تست."""
    return {"status": "ok", "version": APP_VERSION}


app.include_router(auth.router, prefix="/api/v1")
app.include_router(auth.admin_router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")
app.include_router(search.router, prefix="/api/v1")
