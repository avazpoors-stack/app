# بک‌اند «بدنه» (FastAPI)

بک‌اند پلتفرم ورزشی «بدنه» — فاز P2: حساب‌ها (۵ نقش)، OTP (Mock در توسعه)، سینک آفلاین-اول.

## راه‌اندازی (توسعه)

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --reload
```

سرویس روی `http://127.0.0.1:8000` بالا می‌آید؛ مستندات تعاملی در `/docs`.

## متغیرهای محیط

همه از env خوانده می‌شوند (نمونه: `.env.example`). در حالت `production` مقدار `JWT_SECRET`
الزامی است؛ تا کلید کاوه‌نگار را در `KAVENEGAR_API_KEY` نگذاری، OTP در حالت Mock است
(کد در پاسخ `POST /api/v1/auth/otp/request` نمایش داده می‌شود — فقط برای توسعه).

## API (پیشوند `/api/v1`)

| مسیر | روش | توضیح |
|---|---|---|
| `/auth/otp/request` | POST | درخواست کد تأیید (rate-limit: ۱/دقیقه، ۵/ساعت) |
| `/auth/otp/verify` | POST | تأیید کد → ساخت/ورود حساب + توکن‌ها |
| `/auth/login` | POST | ورود با شماره + رمز (اگر هنگام ثبت‌نام رمز گذاشته باشی) |
| `/auth/refresh` | POST | تازه‌سازی توکن (چرخشی؛ قبلی ابطال می‌شود) |
| `/auth/logout` | POST | خروج و ابطال رفرش |
| `/auth/me` | GET/PUT | پروفایل: نام، لحن، برنامهٔ فعال |
| `/sync/push` | POST | ارسال رکوردهای تمرین + پروفایل (آخرین‌تغییر-برنده) |
| `/sync/pull?since=ISO` | GET | دریافت تغییرات از یک زمان |
| `/sync/claim` | POST | انتقال دادهٔ مهمان به حساب (یک‌بار) |
| `/admin/audit` | GET | لاگ ممیزی (فقط ادمین) |

## نقش‌ها (RBAC)

`customer | seller | venue | coach | admin` — هنگام تأیید OTP (فقط کاربر جدید) انتخاب می‌شود؛
نقش ادمین فقط برای پنل مدیریت (مثل `/admin/audit`) است.

## امنیت (P2)

- هش رمز: argon2 · JWT کوتاه‌عمر (۱۵ دقیقه) + رفرش چرخشی (۷ روز)
- OTP: انقضا (۱۲۰ ثانیه)، حداکثر ۵ تلاش، محدودیت ارسال
- rate-limit درون‌حافظه برای OTP و ورود؛ اعتبارسنجی pydantic در همهٔ ورودی‌ها
- لاگ ممیزی (بدون دادهٔ شخصی) در جدول `audit_log` — فقط ادمین می‌بیند
- هیچ کلیدی در کد؛ فقط env

## تست

```bash
.venv/bin/pytest -q
```

## پشتیبان‌گیری روزانه

```bash
.venv/bin/python scripts/backup.py   # کپی SQLite یا pg_dump + نگه‌داری ۱۴ نسخه
```
