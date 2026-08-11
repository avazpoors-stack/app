# راه‌اندازی CI و دریافت APK — راهنمای فعلی

## وضعیت واقعی build (2026-08-11)

رفع نسخه‌های ابزار اندروید در commit `e96c47e` انجام شده است:

- Android Gradle Plugin از `8.3.2` به `8.13.0`
- Gradle Wrapper از `8.7` به `8.14`
- Java 17 حفظ شده است

این اصلاح مستقیماً خطای Flutter دربارهٔ حداقل نسخه‌های Gradle `8.14+` و AGP `8.6+` را برطرف می‌کند. اجرای CI شمارهٔ `31511019304` پس از این تغییر، مراحل **analyze**، **test** و **Build debug APK** را با موفقیت رد کرد.

اما همان اجرای CI در گام قدیمی **Report APK size** شکست خورد؛ این گام یک سقف غیرضروری 100MiB برای APK دیباگ دارد. چون artifact بعد از آن گام قرار گرفته، آپلود APK اجرا نشد. این محدودیت اندازه نباید build آزمایشی را fail کند.

## workflow آمادهٔ جایگزینی

منبع درست و به‌روز workflow در این فایل قرار دارد:

[`docs/ci/Badane-CI-Ready.yml`](ci/Badane-CI-Ready.yml)

ویژگی‌های آن:

1. **Java 17 (Temurin)** را صریحاً نصب و cache گرادل را فعال می‌کند.
2. `flutter analyze` و تست Flutter را fail-fast اجرا می‌کند؛ خطای تست پنهان نمی‌شود.
3. یک APK عمومی دیباگ، یعنی `app-debug.apk`، می‌سازد؛ از `--split-per-abi` استفاده نمی‌کند تا فایل قابل نصب واحد داشته باشیم.
4. وجود APK را بررسی می‌کند، اما سقف مصنوعی اندازه ندارد.
5. APK موفق را با نام `badane-debug-apk` برای ۱۴ روز نگه می‌دارد.
6. در هر حالت، `test.log` و `build.log` را با نام `flutter-build-logs` برای ۷ روز آپلود می‌کند.

## اعمال دستی در GitHub (نیاز به یک‌بار انجام)

ربات Arena دسترسی `workflows` برای نوشتن فایل‌های `.github/workflows/**` ندارد؛ به همین دلیل این یک مرحله باید با حسابی که دسترسی ویرایش repository دارد انجام شود.

1. در GitHub، برنچی را باز کنید که می‌خواهید CI روی آن اجرا شود.
2. فایل `.github/workflows/dart.yml` را باز و روی **Edit** کلیک کنید.
3. تمام محتوای آن را با محتوای کامل [`docs/ci/Badane-CI-Ready.yml`](ci/Badane-CI-Ready.yml) جایگزین کنید.
4. تغییر را در همان برنچ commit کنید.
5. در تب **Actions**، اجرای جدید `Badane CI` را باز کنید.
6. پس از سبزشدن job Flutter، در بخش **Artifacts** فایل `badane-debug-apk` را دانلود کنید. Zip شامل `app-debug.apk` است.

> این APK از نوع debug است و برای تست روی گوشی مناسب است، نه انتشار عمومی. برای انتشار نهایی باید build release با کلید امضای release انجام شود.

## اعتبارسنجی‌های انجام‌شده

- پیکربندی Android به‌صورت ایستا بررسی شد: AGP `8.13.0`، Gradle `8.14` و targetهای Java/Kotlin `17`.
- تست‌های backend در این محیط: **63 passed, 1 warning**.
- ساخت Android فقط در GitHub Actions اجرا می‌شود؛ این محیط محلی Flutter، Java و Android SDK ندارد.
