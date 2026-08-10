"""تست‌های سینک: push/pull، ادغام آخرین‌تغییر-برنده، پروفایل، ادعای مهمان."""
from datetime import datetime, timedelta

from tests.conftest import auth_headers, register_otp


def _entry(date: str, points: int, updated: str, **extra) -> dict:
    base = {
        "date": date,
        "program_id": "starter",
        "session_id": "s1",
        "points": points,
        "client_uid": "dev-1",
        "updated_at": updated,
    }
    base.update(extra)
    return base


def _push(client, headers, entries, profile=None):
    return client.post("/api/v1/sync/push", headers=headers, json={"entries": entries, "profile": profile})


def test_push_and_pull_roundtrip(client):
    tokens = register_otp(client, "09120000011")
    h = auth_headers(tokens)
    now = datetime.utcnow().isoformat()

    r = _push(client, h, [_entry("2026-08-10", 45, now)])
    assert r.status_code == 200, r.text
    state = r.json()
    assert len(state["entries"]) == 1
    assert state["entries"][0]["points"] == 45

    r = client.get("/api/v1/sync/pull", headers=h)
    assert r.status_code == 200
    assert len(r.json()["entries"]) == 1


def test_last_write_wins_per_day(client):
    tokens = register_otp(client, "09120000012")
    h = auth_headers(tokens)
    t1 = datetime.utcnow().isoformat()
    t2 = (datetime.utcnow() + timedelta(seconds=5)).isoformat()

    _push(client, h, [_entry("2026-08-09", 10, t1)])
    # رکورد تازه‌تر برای همان روز → برنده
    _push(client, h, [_entry("2026-08-09", 30, t2, session_id="s2")])
    # رکورد کهنه‌تر → نادیده گرفته می‌شود
    _push(client, h, [_entry("2026-08-09", 5, t1)])

    state = client.get("/api/v1/sync/pull", headers=h).json()
    assert len(state["entries"]) == 1
    assert state["entries"][0]["points"] == 30
    assert state["entries"][0]["session_id"] == "s2"


def test_profile_push_last_write_wins(client):
    tokens = register_otp(client, "09120000013")
    h = auth_headers(tokens)
    t1 = datetime.utcnow().isoformat()
    t2 = (datetime.utcnow() + timedelta(seconds=5)).isoformat()

    _push(client, h, [], {"total_points": 100, "tone": "supportive", "active_program_id": "starter", "updated_at": t1})
    state = _push(client, h, [], {"total_points": 250, "tone": "playful", "active_program_id": "grow", "updated_at": t2}).json()
    assert state["total_points"] == 250
    assert state["profile"]["tone"] == "playful"

    # پروفایل کهنه‌تر نادیده گرفته می‌شود
    state = _push(client, h, [], {"total_points": 1, "tone": "direct", "active_program_id": "x", "updated_at": t1}).json()
    assert state["total_points"] == 250


def test_pull_since_filter(client):
    tokens = register_otp(client, "09120000014")
    h = auth_headers(tokens)
    _push(client, h, [_entry("2026-08-08", 10, datetime.utcnow().isoformat())])
    _push(client, h, [_entry("2026-08-09", 20, (datetime.utcnow() + timedelta(seconds=5)).isoformat())])

    since = (datetime.utcnow() + timedelta(seconds=2)).isoformat()
    r = client.get("/api/v1/sync/pull", headers=h, params={"since": since})
    dates = [e["date"] for e in r.json()["entries"]]
    assert "2026-08-08" not in dates
    assert "2026-08-09" in dates


def test_guest_claim_merges_once(client):
    tokens = register_otp(client, "09120000015")
    h = auth_headers(tokens)
    now = datetime.utcnow().isoformat()

    body = {
        "entries": [_entry("2026-08-07", 70, now), _entry("2026-08-08", 50, now)],
        "total_points": 120,
        "tone": "direct",
        "active_program_id": "starter",
    }
    r = client.post("/api/v1/sync/claim", headers=h, json=body)
    assert r.status_code == 200, r.text
    state = r.json()
    assert len(state["entries"]) == 2
    assert state["total_points"] == 120

    # ادعای دوباره → بدون تکرار (idempotent)
    r = client.post("/api/v1/sync/claim", headers=h, json=body)
    state = r.json()
    assert len(state["entries"]) == 2


def test_claim_with_newer_local_keeps_merge(client):
    tokens = register_otp(client, "09120000016")
    h = auth_headers(tokens)
    t_old = "2026-08-05T10:00:00"
    t_new = "2026-08-05T12:00:00"
    body = {
        "entries": [_entry("2026-08-05", 40, t_new, program_id="grow")],
        "total_points": 40,
        "tone": "supportive",
        "active_program_id": "starter",
    }
    client.post("/api/v1/sync/claim", headers=h, json=body)
    # بعداً سینک با رکورد کهنه‌تر برای همان روز → سرور رکورد تازه را حفظ می‌کند
    _push(client, h, [_entry("2026-08-05", 10, t_old)])
    state = client.get("/api/v1/sync/pull", headers=h).json()
    assert state["entries"][0]["points"] == 40


def test_sync_requires_auth(client):
    r = client.post("/api/v1/sync/push", json={"entries": []})
    assert r.status_code == 401
    r = client.get("/api/v1/sync/pull")
    assert r.status_code == 401
