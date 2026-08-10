"""امنیت: هش رمز (argon2)، توکن JWT کوتاه‌عمر + رفرش چرخشی، وابستگی‌های RBAC."""
import hashlib
import secrets
from datetime import datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import Settings
from .db import get_db
from .models import Role, User

_hasher = PasswordHasher()
_bearer = HTTPBearer(auto_error=False)
_settings = Settings()


# ---------- رمز عبور ----------
def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


# ---------- JWT ----------
def _now() -> datetime:
    return datetime.utcnow()


def create_access_token(user: User, settings: Settings | None = None) -> str:
    s = settings or _settings
    payload = {
        "sub": str(user.id),
        "role": user.role.value,
        "type": "access",
        "iat": _now(),
        "exp": _now() + timedelta(seconds=s.access_ttl_sec),
    }
    return jwt.encode(payload, s.jwt_secret, algorithm=s.jwt_algorithm)


def create_refresh_token(user_id: int, settings: Settings | None = None) -> tuple[str, str]:
    """بازگشت: (توکن رفرش، jti). jti برای ابطال در دیتابیس نگه داشته می‌شود."""
    s = settings or _settings
    jti = secrets.token_hex(32)
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "jti": jti,
        "iat": _now(),
        "exp": _now() + timedelta(days=s.refresh_ttl_days),
    }
    return jwt.encode(payload, s.jwt_secret, algorithm=s.jwt_algorithm), jti


def decode_token(token: str, expected_type: str = "access", settings: Settings | None = None) -> dict:
    s = settings or _settings
    try:
        payload = jwt.decode(token, s.jwt_secret, algorithms=[s.jwt_algorithm])
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="نشست نامعتبر یا منقضی شده است؛ دوباره وارد شو",
        ) from exc
    if payload.get("type") != expected_type:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="نوع توکن درست نیست")
    return payload


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


# ---------- وابستگی‌های FastAPI (RBAC) ----------
def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if creds is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن ارسال نشده")
    payload = decode_token(creds.credentials, expected_type="access")
    user = db.get(User, int(payload["sub"]))
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="کاربر یافت نشد")
    return user


def require_roles(*roles: Role):
    """محدودیت نقش — مثل: require_roles(Role.admin)"""

    def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی مجاز نیست")
        return user

    return dependency
