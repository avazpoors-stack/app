"""پیکربندی بک‌اند «بدنه» — همهٔ مقادیر از محیط (env)؛ هیچ کلیدی در کد نیست.

قانون: فایل‌های `.env` هرگز وارد گیت نمی‌شوند؛ فقط نمونه‌ها (`*.env.example`).
"""
import os
import secrets


class Settings:
    def __init__(self) -> None:
        self.env = os.getenv("APP_ENV", "development")
        self.database_url = os.getenv("DATABASE_URL", "sqlite:///./badane.db")

        # در حالت production بدون JWT_SECRET سرویس بالا نمی‌آید (امنیت: هیچ کلید پیش‌فرضی در کد نیست)
        if self.env == "production" and not os.getenv("JWT_SECRET"):
            raise RuntimeError("JWT_SECRET در حالت production الزامی است (config/backend.env)")
        self.jwt_secret = os.getenv("JWT_SECRET") or secrets.token_hex(32)
        self.jwt_algorithm = "HS256"
        self.access_ttl_sec = int(os.getenv("JWT_ACCESS_TTL_MIN", "15")) * 60
        self.refresh_ttl_days = int(os.getenv("JWT_REFRESH_TTL_DAYS", "7"))

        # OTP (پیامک): بدون کلید کاوه‌نگار → حالت Mock (کد در پاسخ توسعه نمایش داده می‌شود)
        self.otp_ttl_sec = int(os.getenv("OTP_TTL_SEC", "120"))
        self.otp_max_attempts = int(os.getenv("OTP_MAX_ATTEMPTS", "5"))
        self.kavenegar_api_key = os.getenv("KAVENEGAR_API_KEY", "")
        self.otp_mock = not self.kavenegar_api_key

        # محدودیت درخواست (درون‌حافظه)
        self.otp_request_per_min = int(os.getenv("OTP_REQUEST_PER_MIN", "1"))
        self.otp_request_per_hour = int(os.getenv("OTP_REQUEST_PER_HOUR", "5"))
        self.login_attempts_per_15min = int(os.getenv("LOGIN_ATTEMPTS_PER_15MIN", "5"))

        self.cors_origins = [
            o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()
        ]

    @property
    def is_production(self) -> bool:
        """تولید = هر چیزی جز development/test (پیش‌فرضِ محافظه‌کارانه نیست؛ صریح است)."""
        return self.env == "production"
