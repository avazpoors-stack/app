"""لاگ ممیزی — رخدادهای مهم (ورود، ثبت‌نام، سینک) بدون دادهٔ شخصی."""
import json

from sqlalchemy.orm import Session

from .models import AuditLog, utcnow


def log_audit(
    db: Session,
    action: str,
    user_id: int | None = None,
    meta: dict | None = None,
) -> None:
    db.add(
        AuditLog(
            user_id=user_id,
            action=action,
            meta=json.dumps(meta or {}, ensure_ascii=False, default=str),
            created_at=utcnow(),
        )
    )
