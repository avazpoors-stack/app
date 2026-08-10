# راه‌اندازی CI (تست خودکار + ساخت APK) — راهنمای یک‌باره

## الان مشکل تست‌ها چه بود؟

Workflow قبلی گیت‌هاب از قالب خام Dart آمده بود و در ریشهٔ ریپو دستور `dart pub get` می‌زد؛ در حالی که پروژهٔ Flutter داخل پوشهٔ `app/` است و بک‌اند داخل `server/`. به همین دلیل تست‌های GitHub Actions قبل از رسیدن به تست‌های واقعی fail می‌شدند.

فایل workflow درست‌شده در همین ریپو این است:

` .github/workflows/dart.yml `

این فایل دو کار انجام می‌دهد:

1. **Backend:** نصب وابستگی‌های Python و اجرای `pytest -q` در پوشهٔ `server/`
2. **Flutter:** اجرای `flutter pub get`، `flutter analyze`، `flutter test` و ساخت APK دیباگ در پوشهٔ `app/`

## اگر تغییر workflow از سمت ربات در GitHub ذخیره نشد

گاهی GitHub به ربات اجازهٔ تغییر فایل‌های داخل `.github/workflows/` را نمی‌دهد. اگر push/CI با خطای دسترسی مواجه شد، خودت فقط یک‌بار این کار را انجام بده:

1. در مرورگر برو به:
   `https://github.com/avazpoors-stack/app/blob/arena/019fec12-app/.github/workflows/dart.yml`
2. روی **Edit** بزن.
3. محتوای فایل را با متن زیر جایگزین کن.
4. روی **Commit changes** بزن و برنچ `arena/019fec12-app` را انتخاب کن.

```yaml
name: Badane CI

on:
  push:
    branches:
      - main
      - "arena/**"
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  backend:
    name: Backend (pytest)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: server
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip
          cache-dependency-path: server/requirements.txt

      - name: Install backend dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run backend tests
        run: pytest -q

  flutter:
    name: Flutter (analyze + test + debug APK)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Show Flutter version
        run: flutter --version

      - name: Install Flutter dependencies
        run: flutter pub get

      - name: Analyze Flutter app
        run: flutter analyze

      - name: Run Flutter tests
        run: flutter test

      - name: Build debug APK
        run: flutter build apk --debug

      - name: Report APK size
        run: |
          APK="build/app/outputs/flutter-apk/app-debug.apk"
          SIZE=$(stat -c%s "$APK")
          echo "APK size: $SIZE bytes ($((SIZE / 1024 / 1024)) MB)"
          test "$SIZE" -lt 104857600

      - name: Upload debug APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: badane-debug-apk
          path: app/build/app/outputs/flutter-apk/app-debug.apk
```

## نتیجهٔ مورد انتظار

بعد از اجرای موفق CI:

- بخش **Backend (pytest)** باید سبز شود.
- بخش **Flutter (analyze + test + debug APK)** باید سبز شود.
- از قسمت **Artifacts** می‌توانی فایل `badane-debug-apk` را دانلود کنی.
