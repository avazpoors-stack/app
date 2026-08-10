"""احراز هویت و حساب‌ها: OTP (Mock در توسعه)، رمز عبور، JWT + رفرش چرخشی، RBAC.

امنیت P2:
- هش رمز با argon2؛ JWT کوتاه‌عمر (۱۵ دقیقه) + رفرش چرخشی (ابطال قبلی در هر تازه‌سازی)
- OTP ۶ رقمی با انقضا (۱۲۰ ثانیه) و حداکثر ۵ تلاش؛ محدودیت ارسال (۱/دقیقه، ۵/ساعت)
- rate-limit ورود (۵/۱۵ دقیقه)؛ اعتبارسنجی pydantic؛ لاگ ممیزی؛ بدون کلید در کد
"""
import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .audit import log_audit
from .config import Settings
from .db import get_db
from .models import AuditLog, OtpCode, RefreshToken, Role, User, utcnow
from .ratelimit import limiter
from .schemas import (
    LoginIn,
    LogoutIn,
    OtpRequestIn,
    OtpRequestOut,
    OtpVerifyIn,
    ProfileUpdateIn,
    RefreshIn,
    TokensOut,
    UserOut,
)
from .security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    hash_password,
    require_roles,
    sha256_hex,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])

settings = Settings()


def _issue_tokens(db: Session, user: User) -> TokensOut:
    refresh, jti = create_refresh_token(user.id)
    db.add(
        RefreshToken(
            user_id=user.id,
            jti=jti,
            token_hash=sha256_hex(refresh),
            expires_at=utcnow() + timedelta(days=settings.refresh_ttl_days),
        )
    )
    return TokensOut(
        access_token=create_access_token(user),
        refresh_token=refresh,
        expires_in=settings.access_ttl_sec,
    )


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("/otp/request", response_model=OtpRequestOut)
def request_otp(body: OtpRequestIn, request: Request, db: Session = Depends(get_db)):
    phone = body.phone
    limiter.check(f"otp-min:{phone}", settings.otp_request_per_min, 60)
    limiter.check(f"otp-hour:{phone}", settings.otp_request_per_hour, 3600)
    limiter.check(f"otp-ip:{_client_ip(request)}", 10, 3600)

    code = f"{secrets.randbelow(10**6):06d}"
    row = db.scalar(select(OtpCode).where(OtpCode.phone == phone))
    if row is None:
        row = OtpCode(phone=phone, code=code)
        db.add(row)
    row.code = code
    row.attempts = 0
    row.expires_at = utcnow() + timedelta(seconds=settings.otp_ttl_sec)
    log_audit(db, "otp.request", meta={"phone": phone})
    db.commit()

    if settings.otp_mock:
        # حالت توسعه: کد در پاسخ داده می‌شود (در production با کلید کاوه‌نگار پیامک واقعی می‌رود)
        return OtpRequestOut(ok=True, mock=True, code=code, expires_in=settings.otp_ttl_sec, detail="کد تأیید: (توسعه)")
    return OtpRequestOut(ok=True, mock=False, expires_in=settings.otp_ttl_sec, detail="کد تأیید پیامک شد")


@router.post("/otp/verify", response_model=TokensOut)
def verify_otp(body: OtpVerifyIn, request: Request, db: Session = Depends(get_db)):
    phone = body.phone
    limiter.check(f"otp-verify:{phone}", settings.login_attempts_per_15min, 900)

    row = db.scalar(select(OtpCode).where(OtpCode.phone == phone))
    if row is None:
        raise HTTPException(status_code=400, detail="ابتدا کد تأیید را درخواست کن")
    if utcnow() > row.expires_at:
        raise HTTPException(status_code=400, detail="کد منقضی شده؛ دوباره درخواست کن")
    if row.attempts >= settings.otp_max_attempts:
        raise HTTPException(status_code=429, detail="تلاش زیاد؛ دوباره کد بگیر")

    if row.code != body.code:
        row.attempts += 1
        db.commit()
        log_audit(db, "otp.fail", meta={"phone": phone, "attempts": row.attempts})
        raise HTTPException(status_code=400, detail="کد اشتباه است")

    user = db.scalar(select(User).where(User.phone == phone))
    is_new = user is None
    if user is None:
        user = User(
            phone=phone,
            name=(body.name or "").strip() or "کاربر بدنه",
            role=body.role or Role.customer,
        )
        if body.password:
            user.password_hash = hash_password(body.password)
        db.add(user)
        db.flush()
    db.delete(row)
    tokens = _issue_tokens(db, user)
    log_audit(db, "otp.verify", user_id=user.id, meta={"new": is_new, "role": user.role.value})
    db.commit()
    return tokens


@router.post("/login", response_model=TokensOut)
def login(body: LoginIn, request: Request, db: Session = Depends(get_db)):
    phone = body.phone
    limiter.check(f"login:{phone}", settings.login_attempts_per_15min, 900)
    limiter.check(f"login-ip:{_client_ip(request)}", 20, 900)

    user = db.scalar(select(User).where(User.phone == phone))
    if user is None or not verify_password(body.password, user.password_hash):
        log_audit(db, "login.fail", meta={"phone": phone})
        raise HTTPException(status_code=401, detail="شماره یا رمز عبور اشتباه است")

    tokens = _issue_tokens(db, user)
    log_audit(db, "login.ok", user_id=user.id)
    db.commit()
    return tokens


@router.post("/refresh", response_model=TokensOut)
def refresh(body: RefreshIn, db: Session = Depends(get_db)):
    payload = decode_token(body.refresh_token, expected_type="refresh")
    jti = payload.get("jti")
    row = db.scalar(select(RefreshToken).where(RefreshToken.jti == jti))
    if row is None or row.revoked or utcnow() > row.expires_at:
        raise HTTPException(status_code=401, detail="نشست منقضی شده؛ دوباره وارد شو")

    user = db.get(User, row.user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="کاربر یافت نشد")

    # چرخش: توکن قبلی ابطال می‌شود و یک جفت تازه صادر می‌شود
    row.revoked = True
    tokens = _issue_tokens(db, user)
    log_audit(db, "refresh", user_id=user.id)
    db.commit()
    return tokens


@router.post("/logout", status_code=204)
def logout(body: LogoutIn, db: Session = Depends(get_db)):
    payload = decode_token(body.refresh_token, expected_type="refresh")
    row = db.scalar(select(RefreshToken).where(RefreshToken.jti == payload.get("jti")))
    if row is not None:
        row.revoked = True
        log_audit(db, "logout", user_id=row.user_id)
        db.commit()
    return None


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.put("/me", response_model=UserOut)
def update_me(body: ProfileUpdateIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if body.name is not None:
        user.name = body.name.strip()
    if body.tone is not None:
        user.tone = body.tone
    if body.active_program_id is not None:
        user.active_program_id = body.active_program_id
    user.profile_updated_at = utcnow()
    log_audit(db, "profile.update", user_id=user.id)
    db.commit()
    return user


@admin_router.get("/audit")
def admin_audit(
    limit: int = 100,
    _: User = Depends(require_roles(Role.admin)),
    db: Session = Depends(get_db),
):
    rows = (
        db.execute(
            select(AuditLog).order_by(AuditLog.created_at.desc()).limit(min(max(limit, 1), 500))
        )
        .scalars()
        .all()
    )
    return [
        {
            "id": r.id,
            "user_id": r.user_id,
            "action": r.action,
            "meta": r.meta,
            "created_at": r.created_at.isoformat(),
        }
        for r in rows
    ]
