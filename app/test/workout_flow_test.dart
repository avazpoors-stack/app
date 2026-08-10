import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/app_services.dart';
import 'package:badane/main.dart';

void main() {
  Future<AppServices> pumpApp(WidgetTester tester, DateTime now) async {
    // صفحهٔ بزرگ تا همهٔ کارت‌های تمرین دیده شوند
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices.forTesting(now: now);
    await tester.pumpWidget(BadaneApp(services: services));
    await tester.pumpAndSettle();
    return services;
  }

  testWidgets('چرخهٔ طلایی کامل با انرژی کم (شروع کوتاه)', (tester) async {
    final now = DateTime(2026, 8, 10, 15, 0);
    final services = await pumpApp(tester, now);

    // ۱) انتخاب انرژی
    expect(find.text('زیاد 🔥'), findsOneWidget);
    expect(find.text('معمولی 🙂'), findsOneWidget);
    expect(find.text('کم 😴'), findsOneWidget);
    await tester.tap(find.text('کم 😴'));
    await tester.pumpAndSettle();

    // ۲) کارت تمرین کوتاه امروز
    expect(find.text('تمرین کوتاه امروز ⚡'), findsOneWidget);
    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();

    // ۳) ثبت ۱۰ ست (۵ حرکت × ۲ ست) + رد کردن استراحت‌ها
    for (var i = 0; i < 10; i++) {
      final btn = find
          .byWidgetPredicate(
              (w) => w is OutlinedButton && w.onPressed != null)
          .first;
      await tester.tap(btn);
      await tester.pump();
      if (find.text('رد شدن').evaluate().isNotEmpty) {
        await tester.tap(find.text('رد شدن'));
        await tester.pump();
      }
    }
    await tester.pump();

    // ۴) پایان تمرین
    expect(find.text('پایان تمرین 🎉'), findsOneWidget);
    await tester.tap(find.text('پایان تمرین 🎉'));
    await tester.pumpAndSettle();

    // ۵) خلاصه: امتیازها + پیام + کارت
    expect(find.text('تمرین کامل شد!'), findsOneWidget);
    expect(find.textContaining('امتیاز'), findsWidgets);
    expect(find.text('بازگشت به خانه'), findsOneWidget);

    // امتیاز محاسبه‌شده: ست‌ها ۵۰ + حرکات ۵۰ + تمرین ۳۰ + اولین ۵۰ = ۱۸۰
    final progress = await services.progress.load();
    expect(progress.totalPoints, 180);
    expect(progress.workouts.length, 1);

    await tester.tap(find.text('بازگشت به خانه'));
    await tester.pumpAndSettle();
    expect(find.text('تمرین امروز انجام شد!'), findsOneWidget);
  });

  testWidgets('کلیک دوباره روی یک ست فقط یک بار ثبت می‌شود (Debounce)',
      (tester) async {
    final now = DateTime(2026, 8, 10, 15, 0);
    await pumpApp(tester, now);

    await tester.tap(find.text('معمولی 🙂'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();

    final firstBtn = find
        .byWidgetPredicate((w) => w is OutlinedButton && w.onPressed != null)
        .first;
    await tester.tap(firstBtn);
    await tester.tap(firstBtn); // دوباره بدون مکث
    await tester.pump();

    // فقط یک آیکون تیک برای ست ثبت‌شده
    expect(find.byIcon(Icons.check), findsOneWidget);
    // استراحت یک‌بار شروع شده (یک دکمهٔ «رد شدن»)
    expect(find.text('رد شدن'), findsOneWidget);

    // خالی‌کردن تایمر استراحت تا تست بدون timer باقی‌مانده تمام شود
    await tester.pump(const Duration(seconds: 61));
  });
}
