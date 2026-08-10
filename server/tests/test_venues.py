"""تست مکان‌های ورزشی P4: دسته‌ها، ثبت، تأیید ادمین و اعتبارسنجی."""

from tests.conftest import auth_headers, register_otp


def _venue_payload(**extra):
    body = {
        "name": "باشگاه نمونه بدنه",
        "category": "gym",
        "city": "تهران",
        "address": "تهران، خیابان نمونه، پلاک ۱",
        "phone": "02112345678",
        "description": "باشگاه نمونه برای تست P4",
        "lat": 35.7,
        "lng": 51.4,
        "tariffs": [{"title": "جلسه آزاد", "price_toman": 150000, "note": "بدون مربی"}],
    }
    body.update(extra)
    return body


def test_venue_categories_are_public_and_separate(client):
    response = client.get("/api/v1/venues/categories")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 9
    ids = {item["id"] for item in body}
    assert {"pool", "gym", "martial_arts", "yoga", "corrective"}.issubset(ids)


def test_customer_cannot_create_venue(client):
    customer = register_otp(client, "09120000101", role="customer")
    response = client.post(
        "/api/v1/venues",
        headers=auth_headers(customer),
        json=_venue_payload(),
    )
    assert response.status_code == 403


def test_venue_creation_pending_then_admin_approval_publishes(client):
    venue_user = register_otp(client, "09120000102", role="venue")
    response = client.post(
        "/api/v1/venues",
        headers=auth_headers(venue_user),
        json=_venue_payload(),
    )
    assert response.status_code == 201, response.text
    created = response.json()
    assert created["status"] == "pending"
    assert created["tariffs"][0]["price_toman"] == 150000

    # مکان pending عمومی نمی‌شود
    response = client.get("/api/v1/venues")
    assert response.status_code == 200
    assert response.json() == []

    mine = client.get("/api/v1/venues/mine", headers=auth_headers(venue_user))
    assert mine.status_code == 200
    assert mine.json()[0]["name"] == "باشگاه نمونه بدنه"

    admin = register_otp(client, "09120000103", role="admin")
    pending = client.get("/api/v1/admin/venues/pending", headers=auth_headers(admin))
    assert pending.status_code == 200
    assert pending.json()[0]["id"] == created["id"]

    approved = client.post(
        f"/api/v1/admin/venues/{created['id']}/approve",
        headers=auth_headers(admin),
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"

    public = client.get("/api/v1/venues", params={"category": "gym", "q": "نمونه"})
    assert public.status_code == 200
    assert public.json()[0]["name"] == "باشگاه نمونه بدنه"


def test_venue_validation_and_admin_reject(client):
    venue_user = register_otp(client, "09120000104", role="venue")
    bad = client.post(
        "/api/v1/venues",
        headers=auth_headers(venue_user),
        json=_venue_payload(category="not-a-category"),
    )
    assert bad.status_code == 422

    bad_lat = client.post(
        "/api/v1/venues",
        headers=auth_headers(venue_user),
        json=_venue_payload(lat=120),
    )
    assert bad_lat.status_code == 422

    created = client.post(
        "/api/v1/venues",
        headers=auth_headers(venue_user),
        json=_venue_payload(name="استخر تست", category="pool"),
    ).json()
    admin = register_otp(client, "09120000105", role="admin")
    rejected = client.post(
        f"/api/v1/admin/venues/{created['id']}/reject",
        headers=auth_headers(admin),
        json={"reason": "آدرس ناقص است"},
    )
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "rejected"
    assert "آدرس" in rejected.json()["rejection_reason"]
