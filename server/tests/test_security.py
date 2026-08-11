"""تست‌های امنیت P2: rate-limit، اعتبارسنجی ورودی، دسترسی نقش."""
import time

from app.ratelimit import limiter
from tests.conftest import register_otp


class _FakeClock:
    def __init__(self) -> None:
        self.t = 0.0

    def __call__(self) -> float:
        return self.t


def test_otp_request_rate_limited_per_minute(client):
    r1 = client.post("/api/v1/auth/otp/request", json={"phone": "09120000017"})
    assert r1.status_code == 200
    r2 = client.post("/api/v1/auth/otp/request", json={"phone": "09120000017"})
    assert r2.status_code == 429


def test_otp_hourly_cap(client):
    # ۵ درخواست در ساعت مجاز است؛ ششمی ۴۲۹ (با ساعت جعلی فاصلهٔ ۶۱ ثانیه‌ای)
    clock = _FakeClock()
    limiter.clock = clock
    try:
        for i in range(5):
            r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000018"})
            assert r.status_code == 200, (i, r.text)
            clock.t += 61
        r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000018"})
        assert r.status_code == 429
    finally:
        limiter.clock = time.time
        limiter.reset()


def test_login_attempt_rate_limited(client):
    register_otp(client, "09120000019", password="S3cret-pass-123")
    for _ in range(5):
        r = client.post(
            "/api/v1/auth/login", json={"phone": "09120000019", "password": "Wrong-pass-123"}
        )
        assert r.status_code == 401
    r = client.post(
        "/api/v1/auth/login", json={"phone": "09120000019", "password": "S3cret-pass-123"}
    )
    assert r.status_code == 429


def test_sync_input_validation(client):
    tokens = register_otp(client, "09120000020")
    h = {"Authorization": f"Bearer {tokens['access_token']}"}
    # تاریخ نامعتبر
    r = client.post(
        "/api/v1/sync/push",
        headers=h,
        json={"entries": [{"date": "1404/01/01", "program_id": "x", "session_id": "y", "points": 5, "updated_at": "2026-08-10T10:00:00"}]},
    )
    assert r.status_code == 422
    # امتیاز منفی
    r = client.post(
        "/api/v1/sync/push",
        headers=h,
        json={"entries": [{"date": "2026-08-10", "program_id": "x", "session_id": "y", "points": -5, "updated_at": "2026-08-10T10:00:00"}]},
    )
    assert r.status_code == 422
    # تعداد بیش از حد رکورد
    many = [
        {"date": f"2026-01-{d:02d}", "program_id": "x", "session_id": "y", "points": 1, "updated_at": "2026-08-10T10:00:00"}
        for d in range(1, 32)
    ]
    r = client.post("/api/v1/sync/push", headers=h, json={"entries": many})
    assert r.status_code == 200
