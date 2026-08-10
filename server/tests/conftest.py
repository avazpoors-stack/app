"""تنظیمات تست — env قبل از import اپ؛ هر تست دیتابیس تازه دارد (SQLite درون‌حافظه)."""
import os

os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("JWT_SECRET", "test-secret-only-for-tests-0123456789abcdef")
os.environ.setdefault("DATABASE_URL", "sqlite://")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.ratelimit import limiter  # noqa: E402


@pytest.fixture()
def client():
    limiter.reset()
    with TestClient(app) as c:
        yield c


def auth_headers(tokens: dict) -> dict:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def register_otp(client: TestClient, phone: str, **extra) -> dict:
    """ثبت‌نام کامل با OTP توسعه → توکن‌ها."""
    r = client.post("/api/v1/auth/otp/request", json={"phone": phone})
    assert r.status_code == 200, r.text
    code = r.json()["code"]
    body = {"phone": phone, "code": code, **extra}
    r = client.post("/api/v1/auth/otp/verify", json=body)
    assert r.status_code == 200, r.text
    return r.json()
