# راه‌اندازی CI (تست خودکار + ساخت APK) — راهنمای یک‌باره

> چرا لازم است؟ ربات کدنویسی اجازهٔ ذخیرهٔ فایل‌های workflow در گیت‌هاب را ندارد (verified: HTTP 403 — «Resource not accessible by integration»). این فایل باید **یک‌بار توسط خودت** در گیت‌هاب ساخته شود؛ بعد از آن، همه‌چیز خودکار است و در هر push، CI تست‌ها را اجرا و APK می‌سازد.

## روش: اضافه کردن فایل در گیت‌هاب (۳ دقیقه، بدون نیاز به تخصص)

1. در مرورگر به این آدرس برو:
   `https://github.com/avazpoors-stack/app/tree/arena/019febc8-app/.github/workflows`
   (اگر پوشهٔ `.github/workflows` وجود نداشت، مهم نیست — خود گیت‌هاب می‌سازدش.)
2. روی دکمهٔ **Add file → Create new file** بزن.
3. در کادر نام فایل، دقیقاً این را بنویس:  `ci.yml`
4. محتوای زیر را **کامل** در کادر بزرگ کپی کن:

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  flutter:
    name: Flutter (analyze + test + APK)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: دریافت وابستگی‌ها
        run: flutter pub get
      - name: تحلیل استاتیک
        run: flutter analyze
      - name: تست‌ها
        run: flutter test
      - name: بیلد APK دیباگ
        run: flutter build apk --debug
      - name: گزارش حجم APK
        run: |
          SIZE=$(stat -c%s build/app/outputs/flutter-apk/app-debug.apk)
          echo "APK size: $SIZE bytes ($((SIZE / 1024 / 1024)) MB)"
          test "$SIZE" -lt 104857600 && echo "OK (< 100MB)"
      - name: آپلود APK
        uses: actions/upload-artifact@v4
        with:
          name: badane-debug-apk
          path: app/build/app/outputs/flutter-apk/app-debug.apk

  server:
    name: Backend (pytest)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: server
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: نصب وابستگی‌ها
        run: pip install -r requirements.txt
      - name: تست‌ها
        run: pytest -q
```

5. روی **Commit changes** بزن (برنچ `arena/019febc8-app` را انتخاب کن — برنچ فعلی کاری).
6. تمام! از این به بعد در هر push:
   - تب **Actions** ریپو را باز کن → دو کار (Flutter و Backend) اجرا می‌شوند.
   - وقتی سبز شد ✅، فایل APK از **Artifacts** قابل دانلود است: `badane-debug-apk`

> نسخهٔ همین فایل در ریپوی محلی هست: `.github/workflows/ci.yml` — اگر خواستی اول آن را ببینی.
