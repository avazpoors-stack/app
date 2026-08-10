"""مکان‌های ورزشی (P4) — دسته‌بندی جدا، ثبت مکان، تعرفه و تأیید ادمین.

امنیت P4:
- ثبت/ویرایش فقط برای نقش «باشگاه/مکان» یا ادمین؛ انتشار عمومی فقط پس از تأیید ادمین.
- ورودی‌ها با pydantic محدود می‌شوند؛ هیچ SQL خامی وجود ندارد.
- کلید نشان در سرور/اپ از env می‌آید و این endpoint هیچ کلیدی برنمی‌گرداند.
- audit بدون آدرس/شماره/عبارت حساس ذخیره می‌شود.
"""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .audit import log_audit
from .db import get_db
from .models import Role, User, Venue, VenueCategory, VenueStatus, utcnow
from .ratelimit import limiter
from .schemas import (
    VenueCategoryOut,
    VenueCreateIn,
    VenueOut,
    VenueRejectIn,
    VenueUpdateIn,
)
from .security import get_current_user, require_roles

router = APIRouter(prefix="/venues", tags=["venues"])
admin_router = APIRouter(prefix="/admin/venues", tags=["admin-venues"])

_CATEGORY_LABELS: dict[VenueCategory, tuple[str, str]] = {
    VenueCategory.pool: ("استخر", "شنا، آب‌درمانی و سانس‌های آزاد"),
    VenueCategory.gym: ("باشگاه بدنسازی", "وزنه، دستگاه، تمرین قدرتی و فیتنس"),
    VenueCategory.martial_arts: ("رزمی", "بوکس، کاراته، تکواندو، MMA و رشته‌های رزمی"),
    VenueCategory.yoga: ("یوگا/پیلاتس", "یوگا، پیلاتس، انعطاف و تنفس"),
    VenueCategory.crossfit: ("کراس‌فیت/ایروبیک", "کلاس‌های گروهی، HIIT، کراس‌فیت و ایروبیک"),
    VenueCategory.ball_sports: ("ورزش‌های توپی", "فوتبال، والیبال، بسکتبال و سالن‌های توپی"),
    VenueCategory.tennis: ("تنیس/راکت", "تنیس، پدل، بدمینتون و ورزش‌های راکتی"),
    VenueCategory.running: ("دو/پارک", "پیست دو، پارک و مسیرهای تمرین هوازی"),
    VenueCategory.corrective: ("حرکت اصلاحی/فیزیوتراپی", "حرکات اصلاحی، فیزیوتراپی و بازتوانی غیرتشخیصی"),
}


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _tariffs_json(body: VenueCreateIn | VenueUpdateIn) -> str:
    tariffs = body.tariffs
    if tariffs is None:
        return "[]"
    return json.dumps([t.model_dump() for t in tariffs], ensure_ascii=False)


def _tariffs_list(value: str) -> list[dict]:
    try:
        data = json.loads(value or "[]")
        return data if isinstance(data, list) else []
    except json.JSONDecodeError:
        return []


def _venue_out(row: Venue) -> VenueOut:
    return VenueOut(
        id=row.id,
        owner_id=row.owner_id,
        name=row.name,
        category=row.category,
        city=row.city,
        address=row.address,
        phone=row.phone,
        description=row.description,
        lat=row.lat,
        lng=row.lng,
        tariffs=_tariffs_list(row.tariffs_json),
        status=row.status,
        rejection_reason=row.rejection_reason,
        created_at=row.created_at,
        updated_at=row.updated_at,
        approved_at=row.approved_at,
    )


def _ensure_owner_or_admin(row: Venue, user: User) -> None:
    if user.role == Role.admin:
        return
    if row.owner_id == user.id:
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی مجاز نیست")


@router.get("/categories", response_model=list[VenueCategoryOut])
def categories() -> list[VenueCategoryOut]:
    """۹ دستهٔ جدا طبق تصمیم کاربر؛ بدون نیاز به ورود."""
    return [
        VenueCategoryOut(id=category, label=label, description=description)
        for category, (label, description) in _CATEGORY_LABELS.items()
    ]


@router.get("", response_model=list[VenueOut])
def list_venues(
    request: Request,
    category: VenueCategory | None = Query(default=None),
    q: str | None = Query(default=None, min_length=2, max_length=40),
    city: str | None = Query(default=None, max_length=64),
    limit: int = Query(default=50, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[VenueOut]:
    """فهرست عمومی مکان‌های تأییدشده؛ مکان pending/rejected منتشر نمی‌شود."""
    limiter.check(f"venues-list:{_client_ip(request)}", 120, 60)
    query = select(Venue).where(Venue.status == VenueStatus.approved)
    if category is not None:
        query = query.where(Venue.category == category)
    if city:
        query = query.where(Venue.city == city.strip())
    if q:
        pattern = f"%{q.strip()}%"
        query = query.where(or_(Venue.name.like(pattern), Venue.address.like(pattern), Venue.description.like(pattern)))
    rows = db.execute(query.order_by(Venue.approved_at.desc(), Venue.id.desc()).limit(limit)).scalars().all()
    return [_venue_out(row) for row in rows]


@router.get("/mine", response_model=list[VenueOut])
def my_venues(
    user: User = Depends(require_roles(Role.venue, Role.admin)),
    db: Session = Depends(get_db),
) -> list[VenueOut]:
    """مکان‌های ثبت‌شدهٔ خود کاربر؛ ادمین همه را می‌بیند."""
    query = select(Venue)
    if user.role != Role.admin:
        query = query.where(Venue.owner_id == user.id)
    rows = db.execute(query.order_by(Venue.updated_at.desc())).scalars().all()
    return [_venue_out(row) for row in rows]


@router.post("", response_model=VenueOut, status_code=status.HTTP_201_CREATED)
def create_venue(
    body: VenueCreateIn,
    request: Request,
    user: User = Depends(require_roles(Role.venue, Role.admin)),
    db: Session = Depends(get_db),
) -> VenueOut:
    """ثبت مکان؛ نقش venue در حالت pending می‌ماند، ادمین می‌تواند مستقیم approved ثبت کند."""
    limiter.check(f"venues-create-user:{user.id}", 20, 3600)
    limiter.check(f"venues-create-ip:{_client_ip(request)}", 40, 3600)
    now = utcnow()
    row = Venue(
        owner_id=user.id,
        name=body.name.strip(),
        category=body.category,
        city=body.city.strip(),
        address=body.address.strip(),
        phone=body.phone.strip(),
        description=body.description.strip(),
        lat=body.lat,
        lng=body.lng,
        tariffs_json=_tariffs_json(body),
        status=VenueStatus.approved if user.role == Role.admin else VenueStatus.pending,
        created_at=now,
        updated_at=now,
        approved_at=now if user.role == Role.admin else None,
    )
    db.add(row)
    db.flush()
    log_audit(db, "venue.create", user_id=user.id, meta={"venue_id": row.id, "category": row.category.value})
    db.commit()
    return _venue_out(row)


@router.put("/{venue_id}", response_model=VenueOut)
def update_venue(
    venue_id: int,
    body: VenueUpdateIn,
    user: User = Depends(require_roles(Role.venue, Role.admin)),
    db: Session = Depends(get_db),
) -> VenueOut:
    row = db.get(Venue, venue_id)
    if row is None:
        raise HTTPException(status_code=404, detail="مکان پیدا نشد")
    _ensure_owner_or_admin(row, user)

    for field in ("name", "category", "city", "address", "phone", "description", "lat", "lng"):
        value = getattr(body, field)
        if value is not None:
            setattr(row, field, value.strip() if isinstance(value, str) else value)
    if body.tariffs is not None:
        row.tariffs_json = _tariffs_json(body)
    row.updated_at = utcnow()
    if user.role != Role.admin:
        row.status = VenueStatus.pending
        row.approved_at = None
        row.rejection_reason = ""
    log_audit(db, "venue.update", user_id=user.id, meta={"venue_id": row.id})
    db.commit()
    return _venue_out(row)


@admin_router.get("/pending", response_model=list[VenueOut])
def pending_venues(
    _: User = Depends(require_roles(Role.admin)),
    db: Session = Depends(get_db),
) -> list[VenueOut]:
    rows = (
        db.execute(select(Venue).where(Venue.status == VenueStatus.pending).order_by(Venue.created_at.asc()))
        .scalars()
        .all()
    )
    return [_venue_out(row) for row in rows]


@admin_router.post("/{venue_id}/approve", response_model=VenueOut)
def approve_venue(
    venue_id: int,
    admin: User = Depends(require_roles(Role.admin)),
    db: Session = Depends(get_db),
) -> VenueOut:
    row = db.get(Venue, venue_id)
    if row is None:
        raise HTTPException(status_code=404, detail="مکان پیدا نشد")
    now = utcnow()
    row.status = VenueStatus.approved
    row.rejection_reason = ""
    row.approved_at = now
    row.updated_at = now
    log_audit(db, "venue.approve", user_id=admin.id, meta={"venue_id": row.id})
    db.commit()
    return _venue_out(row)


@admin_router.post("/{venue_id}/reject", response_model=VenueOut)
def reject_venue(
    venue_id: int,
    body: VenueRejectIn,
    admin: User = Depends(require_roles(Role.admin)),
    db: Session = Depends(get_db),
) -> VenueOut:
    row = db.get(Venue, venue_id)
    if row is None:
        raise HTTPException(status_code=404, detail="مکان پیدا نشد")
    row.status = VenueStatus.rejected
    row.rejection_reason = body.reason.strip()
    row.updated_at = utcnow()
    log_audit(db, "venue.reject", user_id=admin.id, meta={"venue_id": row.id})
    db.commit()
    return _venue_out(row)
