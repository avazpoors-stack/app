"""پشتیبان‌گیری روزانهٔ دیتابیس (امنیت P2).

SQLite: کپی فایل به پوشهٔ backups/ (نگه‌داری N نسخهٔ آخر).
PostgreSQL: اجرای pg_dump و نگه‌داری خروجی.

اجرا (مثلاً کرون‌جاب روزانه):
    .venv/bin/python scripts/backup.py

متغیرها: DATABASE_URL (همان env سرور)، BACKUP_DIR (پیش‌فرض ./backups)، BACKUP_KEEP (پیش‌فرض ۱۴)
"""
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def main() -> int:
    database_url = os.getenv("DATABASE_URL", "sqlite:///./badane.db")
    backup_dir = Path(os.getenv("BACKUP_DIR", "./backups"))
    keep = int(os.getenv("BACKUP_KEEP", "14"))
    backup_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")

    if database_url.startswith("sqlite"):
        db_file = database_url.replace("sqlite:///", "")
        if not Path(db_file).exists():
            print("دیتابیس وجود ندارد؛ چیزی برای پشتیبان‌گیری نیست.", file=sys.stderr)
            return 1
        target = backup_dir / f"badane-{stamp}.db"
        shutil.copy2(db_file, target)
        print(f"پشتیبان SQLite: {target}")
    elif database_url.startswith("postgres"):
        target = backup_dir / f"badane-{stamp}.sql"
        with open(target, "wb") as out:
            subprocess.run(["pg_dump", database_url], stdout=out, check=True)
        print(f"پشتیبان PostgreSQL: {target}")
    else:
        print("فرمت DATABASE_URL شناخته‌شده نیست.", file=sys.stderr)
        return 1

    # پاک‌کردن نسخه‌های قدیمی‌تر از حد مجاز
    files = sorted(backup_dir.glob("badane-*"))
    for old in files[:-keep] if len(files) > keep else []:
        old.unlink()
        print(f"حذف نسخهٔ قدیمی: {old}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
