"""اعتبارسنجی ورودی/خروجی (pydantic) — همهٔ ورودی‌ها قبل از دیتابیس اعتبارسنجی می‌شوند."""
from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from .models import Role, VenueCategory, VenueStatus

PHONE_PATTERN = r"^09\d{9}$"  # شمارهٔ موبایل ایران

PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128

# رمزهای خیلی رایج — حتی اگر قواعد را رد کنند، پذیرفته نمی‌شوند
_COMMON_PASSWORDS = frozenset(
    {
        "password1",
        "password123",
        "passw0rd",
        "qwerty123",
        "iloveyou1",
        "welcome1",
        "abcd1234",
        "admin123",
        "12345678",
        "123456789",
    }
)

PASSWORD_ERROR = (
    "رمز عبور باید حداقل ۸ کاراکتر باشد و شامل حرف بزرگ انگلیسی و عدد باشد"
)


class PasswordValidator:
    """قواعد قدرت رمز عبور — یک‌جا، تا سرور و تست‌ها یک منبع حقیقت داشته باشند."""

    MIN_LENGTH = PASSWORD_MIN_LENGTH
    MAX_LENGTH = PASSWORD_MAX_LENGTH
    REQUIRE_DIGIT = True
    REQUIRE_UPPERCASE = True
    REQUIRE_LOWERCASE = True
    REQUIRE_SPECIAL = False

    @classmethod
    def problems(cls, password: str) -> list[str]:
        """فهرست ایرادهای رمز — خالی یعنی معتبر."""
        issues: list[str] = []
        if len(password) < cls.MIN_LENGTH:
            issues.append(f"حداقل {cls.MIN_LENGTH} کاراکتر")
        if len(password) > cls.MAX_LENGTH:
            issues.append(f"حداکثر {cls.MAX_LENGTH} کاراکتر")
        if cls.REQUIRE_DIGIT and not any(c.isdigit() for c in password):
            issues.append("حداقل یک عدد")
        if cls.REQUIRE_UPPERCASE and not any(c.isupper() for c in password):
            issues.append("حداقل یک حرف بزرگ")
        if cls.REQUIRE_LOWERCASE and not any(c.islower() for c in password):
            issues.append("حداقل یک حرف کوچک")
        if cls.REQUIRE_SPECIAL and password.isalnum():
            issues.append("حداقل یک نویسهٔ ویژه")
        if password.lower() in _COMMON_PASSWORDS:
            issues.append("این رمز خیلی رایج است")
        return issues

    @classmethod
    def validate(cls, password: str) -> bool:
        return not cls.problems(password)


def _check_password(value: Optional[str]) -> Optional[str]:
    """اعتبارسنجی مشترک رمز — پیام خطای فارسی و شفاف."""
    if value is None:
        return value
    issues = PasswordValidator.problems(value)
    if issues:
        raise ValueError(f"{PASSWORD_ERROR} ({'، '.join(issues)})")
    return value


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
    password: Optional[str] = Field(
        default=None, min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH
    )

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: Optional[str]) -> Optional[str]:
        return _check_password(v)


class PasswordSetIn(BaseModel):
    """تعیین/تغییر رمز عبور — همان قواعد قدرت رمز."""

    password: str = Field(min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        return _check_password(v)  # type: ignore[return-value]


class LoginIn(BaseModel):
    """ورود — عمداً قواعد قدرت رمز اینجا اعمال نمی‌شود.

    اعمال قواعد در ورود، هم سیاست رمز را به مهاجم لو می‌دهد و هم
    کاربران قدیمی با رمز ضعیف را قفل می‌کند؛ ضعف رمز فقط هنگام «تعیین» رد می‌شود.
    """

    phone: str = Field(pattern=PHONE_PATTERN)
    password: str = Field(min_length=1, max_length=PASSWORD_MAX_LENGTH)


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


# ================= P4: مکان‌های ورزشی + نشان =================

class VenueCategoryOut(BaseModel):
    id: VenueCategory
    label: str
    description: str


class VenueTariffIn(BaseModel):
    title: str = Field(min_length=2, max_length=80)
    price_toman: int = Field(ge=0, le=1_000_000_000)
    note: Optional[str] = Field(default=None, max_length=120)


class VenueCreateIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    category: VenueCategory
    city: str = Field(default="", max_length=64)
    address: str = Field(min_length=5, max_length=240)
    phone: str = Field(default="", max_length=24, pattern=r"^[0-9+\- ]*$")
    description: str = Field(default="", max_length=500)
    lat: Optional[float] = Field(default=None, ge=-90, le=90)
    lng: Optional[float] = Field(default=None, ge=-180, le=180)
    tariffs: list[VenueTariffIn] = Field(default_factory=list, max_length=20)


class VenueUpdateIn(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=80)
    category: Optional[VenueCategory] = None
    city: Optional[str] = Field(default=None, max_length=64)
    address: Optional[str] = Field(default=None, min_length=5, max_length=240)
    phone: Optional[str] = Field(default=None, max_length=24, pattern=r"^[0-9+\- ]*$")
    description: Optional[str] = Field(default=None, max_length=500)
    lat: Optional[float] = Field(default=None, ge=-90, le=90)
    lng: Optional[float] = Field(default=None, ge=-180, le=180)
    tariffs: Optional[list[VenueTariffIn]] = Field(default=None, max_length=20)


class VenueRejectIn(BaseModel):
    reason: str = Field(min_length=2, max_length=240)


class VenueOut(BaseModel):
    id: int
    owner_id: int
    name: str
    category: VenueCategory
    city: str
    address: str
    phone: str
    description: str
    lat: Optional[float]
    lng: Optional[float]
    tariffs: list[dict]
    status: VenueStatus
    rejection_reason: str
    created_at: datetime
    updated_at: datetime
    approved_at: Optional[datetime]


# ================= P5: فروشگاه =================
class ProductCreateIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    category: str = Field(min_length=2, max_length=24)
    brand: str = Field(default="", max_length=64)
    price_toman: int = Field(ge=0, le=2_000_000_000)
    stock: int = Field(ge=0, le=1_000_000)

class ProductOut(ProductCreateIn):
    id: str
    seller_id: int
    approved: bool

class OrderItemIn(BaseModel):
    product_id: str = Field(min_length=2, max_length=80)
    quantity: int = Field(ge=1, le=50)
    price_toman: int = Field(ge=0, le=2_000_000_000)

class OrderIn(BaseModel):
    items: list[OrderItemIn] = Field(min_length=1, max_length=50)

class OrderOut(BaseModel):
    order_id: str
    status: str
    total_toman: int
    payment_url: Optional[str]
