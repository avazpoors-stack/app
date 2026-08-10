"""اعتبارسنجی ورودی/خروجی (pydantic) — همهٔ ورودی‌ها قبل از دیتابیس اعتبارسنجی می‌شوند."""
from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from .models import Role

PHONE_PATTERN = r"^09\d{9}$"  # شمارهٔ موبایل ایران


class OtpRequestIn(BaseModel):
    phone: str = Field(pattern=PHONE_PATTERN)


class OtpRequestOut(BaseModel):
    ok: bool
    mock: bool
    code: Optional[str] = None  # فقط در حالت توسعه
    expires_in: int
    detail: str


class OtpVerifyIn(BaseModel):
    phone: str = Field(pattern=PHONE_PATTERN)
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")
    name: Optional[str] = Field(default=None, max_length=64)
    role: Optional[Role] = None
    password: Optional[str] = Field(default=None, min_length=8, max_length=128)


class LoginIn(BaseModel):
    phone: str = Field(pattern=PHONE_PATTERN)
    password: str = Field(min_length=8, max_length=128)


class RefreshIn(BaseModel):
    refresh_token: str = Field(min_length=20)


class LogoutIn(BaseModel):
    refresh_token: str = Field(min_length=20)


class TokensOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class ProfileUpdateIn(BaseModel):
    name: Optional[str] = Field(default=None, max_length=64)
    tone: Optional[str] = Field(default=None, pattern=r"^(direct|supportive|playful)$")
    active_program_id: Optional[str] = Field(default=None, max_length=32)


class UserOut(BaseModel):
    id: int
    phone: str
    name: str
    role: Role
    tone: str
    active_program_id: str
    total_points: int
    created_at: datetime

    model_config = {"from_attributes": True}


class WorkoutEntryIn(BaseModel):
    """یک رکورد تمرین برای سینک."""

    date: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    program_id: str = Field(max_length=32)
    session_id: str = Field(max_length=32)
    points: int = Field(ge=0, le=100000)
    client_uid: str = Field(default="", max_length=64)
    updated_at: datetime

    @field_validator("points")
    @classmethod
    def points_reasonable(cls, v: int) -> int:
        return v


class ProfileSyncIn(BaseModel):
    total_points: int = Field(ge=0, le=100_000_000)
    tone: str = Field(pattern=r"^(direct|supportive|playful)$")
    active_program_id: str = Field(max_length=32)
    updated_at: datetime


class SyncPushIn(BaseModel):
    entries: list[WorkoutEntryIn] = Field(default_factory=list, max_length=1000)
    profile: Optional[ProfileSyncIn] = None


class SyncClaimIn(BaseModel):
    entries: list[WorkoutEntryIn] = Field(default_factory=list, max_length=1000)
    total_points: int = Field(ge=0, le=100_000_000)
    tone: str = Field(pattern=r"^(direct|supportive|playful)$")
    active_program_id: str = Field(max_length=32)


class SyncEntryOut(BaseModel):
    date: str
    program_id: str
    session_id: str
    points: int
    client_uid: str
    updated_at: datetime


class SyncStateOut(BaseModel):
    entries: list[SyncEntryOut]
    profile: dict
    total_points: int
    server_time: datetime


class AuditOut(BaseModel):
    id: int
    user_id: Optional[int]
    action: str
    meta: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ================= P3: جستجوی سراسری =================

class SearchCategory(str, Enum):
    exercise = "exercise"
    program = "program"
    product = "product"
    venue = "venue"
    coach = "coach"


class SearchResultOut(BaseModel):
    id: str = Field(max_length=80)
    title: str = Field(max_length=120)
    subtitle: str = Field(max_length=240)
    category: SearchCategory
    source: str = Field(default="server", max_length=24)
    coming_soon: bool = False


class SearchOut(BaseModel):
    results: list[SearchResultOut]
    total: int
    server_time: datetime
