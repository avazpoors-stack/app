"""تست‌های احراز هویت: OTP، رمز عبور، رفرش چرخشی، خروج، پروفایل، RBAC."""
from datetime import datetime, timedelta

from app.models import OtpCode
from tests.conftest import auth_headers, register_otp


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_otp_register_flow(client):
    tokens = register_otp(client, "09120000001", name="سارا", role="coach")
    assert tokens["access_token"]
    assert tokens["refresh_token"]

    me = client.get("/api/v1/auth/me", headers=auth_headers(tokens))
    assert me.status_code == 200
    body = me.json()
    assert body["phone"] == "09120000001"
    assert body["role"] == "coach"
    assert body["name"] == "سارا"


def test_otp_wrong_code_and_attempt_limit(client):
    client.post("/api/v1/auth/otp/request", json={"phone": "09120000002"})
    for _ in range(4):
        r = client.post(
            "/api/v1/auth/otp/verify", json={"phone": "09120000002", "code": "000000"}
        )
        assert r.status_code == 400
    # تلاش پنجم اشتباه → حساب مسدود می‌شود
    r = client.post(
        "/api/v1/auth/otp/verify", json={"phone": "09120000002", "code": "000000"}
    )
    assert r.status_code == 400
    # حتی با کد درست هم دیگر قبول نیست (حداکثر تلاش)
    r = client.post(
        "/api/v1/auth/otp/verify", json={"phone": "09120000002", "code": "999999"}
    )
    assert r.status_code in (400, 429)


def test_otp_expired_code_rejected(client):
    from app.db import SessionLocal  # بعد از بالا آمدن اپ (lifespan) مقدار می‌گیرد

    client.post("/api/v1/auth/otp/request", json={"phone": "09120000003"})
    with SessionLocal() as db:
        row = db.query(OtpCode).filter(OtpCode.phone == "09120000003").one()
        row.expires_at = datetime.utcnow() - timedelta(seconds=10)
        db.commit()
    r = client.post(
        "/api/v1/auth/otp/verify", json={"phone": "09120000003", "code": "000000"}
    )
    assert r.status_code == 400
    assert "منقضی" in r.json()["detail"]


def test_password_login_and_refresh_rotation(client):
    tokens = register_otp(client, "09120000004", password="s3cret-pass-123")
    # ورود با رمز
    r = client.post(
        "/api/v1/auth/login", json={"phone": "09120000004", "password": "s3cret-pass-123"}
    )
    assert r.status_code == 200
    login_tokens = r.json()

    # رفرش → جفت تازه + ابطال قبلی
    r = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": login_tokens["refresh_token"]}
    )
    assert r.status_code == 200
    refreshed = r.json()
    assert refreshed["access_token"]

    # توکن رفرش قبلی دیگر کار نمی‌کند (چرخش)
    r = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": login_tokens["refresh_token"]}
    )
    assert r.status_code == 401


def test_logout_revokes_refresh(client):
    tokens = register_otp(client, "09120000005")
    r = client.post("/api/v1/auth/logout", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 204
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 401


def test_wrong_password_rejected(client):
    register_otp(client, "09120000006", password="s3cret-pass-123")
    r = client.post(
        "/api/v1/auth/login", json={"phone": "09120000006", "password": "wrong-pass-123"}
    )
    assert r.status_code == 401


def test_rbac_admin_audit(client):
    seller = register_otp(client, "09120000007", role="seller")
    r = client.get("/api/v1/admin/audit", headers=auth_headers(seller))
    assert r.status_code == 403

    admin = register_otp(client, "09120000008", role="admin")
    r = client.get("/api/v1/admin/audit", headers=auth_headers(admin))
    assert r.status_code == 200
    actions = [row["action"] for row in r.json()]
    assert "otp.verify" in actions
    assert "sync.push" not in actions  # هنوز سینکی انجام نشده


def test_validation_errors(client):
    r = client.post("/api/v1/auth/otp/request", json={"phone": "123"})
    assert r.status_code == 422
    r = client.post("/api/v1/auth/otp/request", json={"phone": "09120000009"})
    assert r.status_code == 200
    r = client.post(
        "/api/v1/auth/otp/verify", json={"phone": "09120000009", "code": "12ab"}
    )
    assert r.status_code == 422


def test_me_requires_token(client):
    r = client.get("/api/v1/auth/me")
    assert r.status_code == 401
    r = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid"})
    assert r.status_code == 401


def test_profile_update(client):
    tokens = register_otp(client, "09120000010", name="علی")
    r = client.put(
        "/api/v1/auth/me",
        headers=auth_headers(tokens),
        json={"name": "علی رضایی", "tone": "direct", "active_program_id": "grow"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["name"] == "علی رضایی"
    assert body["tone"] == "direct"
    assert body["active_program_id"] == "grow"
    # مقدار نامعتبر لحن → 422
    r = client.put("/api/v1/auth/me", headers=auth_headers(tokens), json={"tone": "angry"})
    assert r.status_code == 422
