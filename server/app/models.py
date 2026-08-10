"""مدل‌های دیتابیس — کاربران (۵ نقش)، OTP، توکن رفرش، لاگ ممیزی، رکوردهای سینک."""
import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def utcnow() -> datetime:
    """زمان UTC بدون zoneinfo (برای سازگاری با SQLite)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Base(DeclarativeBase):
    pass


class Role(str, enum.Enum):
    customer = "customer"  # مشتری
    seller = "seller"  # فروشنده
    venue = "venue"  # باشگاه/مکان
    coach = "coach"  # مربی
    admin = "admin"  # ادمین


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone: Mapped[str] = mapped_column(String(11), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(64), default="")
    role: Mapped[Role] = mapped_column(
        SAEnum(Role, native_enum=False, length=16), default=Role.customer
    )
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # پروفایل/تنظیمات (برای سینک)
    tone: Mapped[str] = mapped_column(String(20), default="supportive")
    active_program_id: Mapped[str] = mapped_column(String(32), default="starter")
    total_points: Mapped[int] = mapped_column(Integer, default=0)
    profile_updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, nullable=False
    )

    # مهمان P1 → کاربر ثبت‌نام‌شده
    guest_claimed: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone: Mapped[str] = mapped_column(String(11), unique=True, index=True)
    code: Mapped[str] = mapped_column(String(6))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    jti: Mapped[str] = mapped_column(String(64), unique=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    action: Mapped[str] = mapped_column(String(64), index=True)
    meta: Mapped[str] = mapped_column(Text, default="{}")  # JSON بدون دادهٔ شخصی
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)


class ServerWorkout(Base):
    """رکورد تمرین همگام‌شده — یک رکورد برای هر (کاربر، روز)؛ تعارض با «آخرین تغییر برنده»."""

    __tablename__ = "sync_workouts"
    __table_args__ = (UniqueConstraint("user_id", "date", name="uq_workout_per_day"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    date: Mapped[str] = mapped_column(String(10))  # yyyy-MM-dd
    program_id: Mapped[str] = mapped_column(String(32))
    session_id: Mapped[str] = mapped_column(String(32))
    points: Mapped[int] = mapped_column(Integer)
    client_uid: Mapped[str] = mapped_column(String(64), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
