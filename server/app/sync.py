"""سینک آفلاین-اول: push (ادغام آخرین‌تغییر-برنده)، pull (از timestamp)، ادعای مهمان.

سیاست تعارض (ROADMAP ۲.۶/تکمیلی P2): برای هر (کاربر، روز) یک رکورد تمرین؛
هر طرف `updated_at` می‌فرستد و رکوردی با timestamp تازه‌تر برنده است.
"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from .audit import log_audit
from .db import get_db
from .models import ServerWorkout, User, utcnow
from .schemas import SyncClaimIn, SyncEntryOut, SyncPushIn, SyncStateOut
from .security import get_current_user

router = APIRouter(prefix="/sync", tags=["sync"])

_PROFILE_KEYS = ("total_points", "tone", "active_program_id")


def _parse_iso(value: datetime) -> datetime:
    """ISO از کلاینت → datetime UTC بدون zoneinfo (سازگار با SQLite)."""
    if value.tzinfo is not None:
        value = value.astimezone().replace(tzinfo=None)
    return value


def _entry_out(row: ServerWorkout) -> SyncEntryOut:
    return SyncEntryOut(
        date=row.date,
        program_id=row.program_id,
        session_id=row.session_id,
        points=row.points,
        client_uid=row.client_uid,
        updated_at=row.updated_at,
    )


def _state(user: User, db: Session, since: datetime | None = None) -> SyncStateOut:
    query = select(ServerWorkout).where(ServerWorkout.user_id == user.id)
    if since is not None:
        query = query.where(ServerWorkout.updated_at > since)
    rows = db.execute(query.order_by(ServerWorkout.date)).scalars().all()
    return SyncStateOut(
        entries=[_entry_out(r) for r in rows],
        profile={
            "total_points": user.total_points,
            "tone": user.tone,
            "active_program_id": user.active_program_id,
            "updated_at": user.profile_updated_at,
        },
        total_points=user.total_points,
        server_time=utcnow(),
    )


def _merge_entries(db: Session, user: User, entries) -> None:
    """آخرین تغییر برنده بر اساس (تاریخ). رکورد سرور با timestamp تازه‌تر حفظ می‌شود."""
    for e in entries:
        updated = _parse_iso(e.updated_at)
        row = db.scalar(
            select(ServerWorkout).where(
                ServerWorkout.user_id == user.id, ServerWorkout.date == e.date
            )
        )
        if row is None:
            db.add(
                ServerWorkout(
                    user_id=user.id,
                    date=e.date,
                    program_id=e.program_id,
                    session_id=e.session_id,
                    points=e.points,
                    client_uid=e.client_uid,
                    updated_at=updated,
                )
            )
        elif updated > row.updated_at:
            row.program_id = e.program_id
            row.session_id = e.session_id
            row.points = e.points
            row.client_uid = e.client_uid
            row.updated_at = updated


@router.post("/push", response_model=SyncStateOut)
def push(body: SyncPushIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _merge_entries(db, user, body.entries)

    if body.profile is not None:
        profile_updated = _parse_iso(body.profile.updated_at)
        if profile_updated > user.profile_updated_at:
            user.total_points = body.profile.total_points
            user.tone = body.profile.tone
            user.active_program_id = body.profile.active_program_id
            user.profile_updated_at = profile_updated

    log_audit(db, "sync.push", user_id=user.id, meta={"entries": len(body.entries)})
    db.commit()
    return _state(user, db)


@router.get("/pull", response_model=SyncStateOut)
def pull(
    since: str | None = Query(default=None, description="ISO؛ فقط رکوردهای تازه‌تر از این زمان"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    since_dt: datetime | None = None
    if since:
        try:
            since_dt = _parse_iso(datetime.fromisoformat(since.replace("Z", "+00:00")))
        except ValueError:
            raise HTTPException(status_code=422, detail="قالب since درست نیست (ISO)")
    log_audit(db, "sync.pull", user_id=user.id)
    db.commit()
    return _state(user, db, since=since_dt)


@router.post("/claim", response_model=SyncStateOut)
def claim(body: SyncClaimIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """انتقال دادهٔ مهمان (P1) به حساب تازه — فقط یک بار؛ بعد از آن idempotent است."""
    if not user.guest_claimed:
        _merge_entries(db, user, body.entries)
        # دادهٔ مهمان به‌عنوان پایهٔ حساب تازه
        if user.total_points < body.total_points:
            user.total_points = body.total_points
        user.tone = body.tone
        user.active_program_id = body.active_program_id
        user.profile_updated_at = utcnow()
        user.guest_claimed = True
        log_audit(db, "sync.claim", user_id=user.id, meta={"entries": len(body.entries)})
        db.commit()
    else:
        log_audit(db, "sync.claim.duplicate", user_id=user.id)
        db.commit()
    return _state(user, db)
