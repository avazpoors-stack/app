"""تست‌های تکمیلی احراز هویت: قدرت رمز، اعتبارسنجی ورودی، محدودیت نرخ، مهاجرت."""
import time

import pytest
from pydantic import ValidationError

from app.ratelimit import limiter
from app.schemas import LoginIn, OtpVerifyIn, PasswordSetIn, PasswordValidator
from tests.conftest import auth_headers, register_otp


class _FakeClock:
    def __init__(self) -> None:
        self.t = 0.0

    def __call__(self) -> float:
        return self.t


# ================= قدرت رمز عبور =================


@pytest.mark.parametrize(
    "password, reason",
    [
        ("Short1a", "کمتر از ۸ کاراکتر"),
        ("nouppercase1", "بدون حرف بزرگ"),
        ("NOLOWERCASE1", "بدون حرف کوچک"),
        ("NoDigitPass", "بدون عدد"),
        ("Password1", "رمز رایج"),
    ],
)
def test_weak_passwords_rejected(password, reason):
    with pytest.raises(ValidationError):
        OtpVerifyIn(phone="09120000001", code="123456", password=password)


def test_strong_password_accepted():
    body = OtpVerifyIn(phone="09120000001", code="123456", password="ValidPass1")
    assert body.password == "ValidPass1"


def test_password_optional_on_otp_verify():
    """رمز اختیاری است — ثبت‌نام فقط با OTP باید کار کند."""
    body = OtpVerifyIn(phone="09120000001", code="123456")
    assert body.password is None


def test_password_validator_rules():
    assert PasswordValidator.validate("ValidPass1")
    assert not PasswordValidator.validate("short")
    assert "حداقل یک عدد" in PasswordValidator.problems("NoDigitsHere")
    assert "حداقل یک حرف بزرگ" in PasswordValidator.problems("nouppercase1")
    # رمز بیش از حد بلند
    assert PasswordValidator.problems("A1" + "a" * 200)


def test_password_set_schema():
    assert PasswordSetIn(password="ValidPass1").password == "ValidPass1"
    with pytest.raises(ValidationError):
        PasswordSetIn(password="weak")


def test_login_does_not_enforce_strength():
    """ورود نباید سیاست رمز را افشا کند یا کاربر قدیمی را قفل کند."""
    assert LoginIn(phone="09120000001", password="oldweak").password == "oldweak"


def test_weak_password_rejected_by_api(client):
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000040"})
    code = r.json()["code"]
    r = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "09120000040", "code": code, "password": "weakpass"},
    )
    assert r.status_code == 422
    assert "رمز عبور" in r.text


def test_strong_password_accepted_by_api(client):
    tokens = register_otp(client, "09120000041", password="StrongPass1")
    r = client.post(
        "/api/v1/auth/login", json={"phone": "09120000041", "password": "StrongPass1"}
    )
    assert r.status_code == 200
    assert r.json()["access_token"]
    # توکن صادرشده معتبر است
    me = client.get("/api/v1/auth/me", headers=auth_headers(tokens))
    assert me.status_code == 200


# ================= قالب شماره و کد =================


@pytest.mark.parametrize(
    "phone",
    ["123", "9120000001", "08120000001", "0912000000a", "091200000012"],
)
def test_invalid_phone_rejected(phone):
    with pytest.raises(ValidationError):
        OtpVerifyIn(phone=phone, code="123456")


@pytest.mark.parametrize("code", ["12ab34", "12345", "1234567", ""])
def test_invalid_otp_code_rejected(code):
    with pytest.raises(ValidationError):
        OtpVerifyIn(phone="09120000001", code=code)


def test_valid_phone_and_code_accepted():
    body = OtpVerifyIn(phone="09120000001", code="123456")
    assert body.phone == "09120000001"
    assert body.code == "123456"


# ================= محدودیت نرخ =================


def test_otp_request_rate_limit_message(client):
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000050"})
    assert r.status_code == 200

    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000050"})
    assert r.status_code == 429
    assert "تلاش زیاد" in r.json()["detail"]
    assert "دقیقه" in r.json()["detail"]


def test_otp_verify_rate_limited(client):
    """تلاش‌های مکرر روی verify هم محدود می‌شود (نه فقط تعداد تلاش کد)."""
    client.post("/api/v1/auth/otp/request", json={"phone": "09120000051"})
    statuses = [
        client.post(
            "/api/v1/auth/otp/verify",
            json={"phone": "09120000051", "code": "000000"},
        ).status_code
        for _ in range(8)
    ]
    assert 429 in statuses


def test_login_rate_limited_with_persian_message(client):
    register_otp(client, "09120000052", password="StrongPass1")
    for _ in range(5):
        client.post(
            "/api/v1/auth/login",
            json={"phone": "09120000052", "password": "WrongPass1"},
        )
    r = client.post(
        "/api/v1/auth/login", json={"phone": "09120000052", "password": "StrongPass1"}
    )
    assert r.status_code == 429
    assert "تلاش زیاد" in r.json()["detail"]


def test_refresh_endpoint_is_rate_limited(client):
    """endpoint رفرش هم باید محدودیت داشته باشد (قبلاً نداشت)."""
    clock = _FakeClock()
    limiter.clock = clock
    try:
        limiter.reset()
        statuses = [
            client.post(
                "/api/v1/auth/refresh", json={"refresh_token": "x" * 40}
            ).status_code
            for _ in range(70)
        ]
        assert 429 in statuses
    finally:
        limiter.clock = time.time
        limiter.reset()


def test_rate_limit_hit_is_audited(client):
    """عبور از حد در لاگ ممیزی ثبت می‌شود — بدون شماره/IP."""
    admin = register_otp(client, "09120000053", role="admin")

    client.post("/api/v1/auth/otp/request", json={"phone": "09120000054"})
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000054"})
    assert r.status_code == 429

    audit = client.get("/api/v1/admin/audit", headers=auth_headers(admin))
    assert audit.status_code == 200
    hits = [row for row in audit.json() if row["action"] == "ratelimit.hit"]
    assert hits, "رخداد ratelimit.hit باید در لاگ ممیزی باشد"
    # نباید شماره یا IP در meta باشد
    assert "09120000054" not in hits[0]["meta"]


def test_rate_limit_is_per_phone(client):
    """محدودیت یک شماره نباید شمارهٔ دیگر را قفل کند."""
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000055"})
    assert r.status_code == 200
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000055"})
    assert r.status_code == 429
    # شمارهٔ دیگر همچنان آزاد است
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000056"})
    assert r.status_code == 200
