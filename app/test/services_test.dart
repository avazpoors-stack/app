import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/app_services.dart';
import 'package:badane/main.dart';

void main() {
  group('AppServices', () {
    test('forTesting یک نمونهٔ کامل و معتبر می‌سازد', () {
      final services = AppServices.forTesting();
      addTearDown(services.dispose);

      expect(services.content, isNotNull);
      expect(services.progress, isNotNull);
      expect(services.account, isNotNull);
      expect(services.auth, isNotNull);
      expect(services.sync, isNotNull);
      expect(services.search, isNotNull);
      expect(services.venues, isNotNull);
      expect(services.shop, isNotNull);
      expect(services.clock, isNotNull);
    });

    test('تم پیش‌فرض روی system است', () {
      final services = AppServices.forTesting();
      addTearDown(services.dispose);

      expect(services.themeMode.value, ThemeMode.system);
    });

    test('setTheme مقدار را عوض و ذخیره می‌کند و loadTheme برمی‌گرداند', () async {
      final services = AppServices.forTesting();
      addTearDown(services.dispose);

      await services.setTheme(ThemeMode.dark);
      expect(services.themeMode.value, ThemeMode.dark);

      // بازخوانی از حافظه → همان مقدار
      services.themeMode.value = ThemeMode.system;
      await services.loadTheme();
      expect(services.themeMode.value, ThemeMode.dark);
    });

    test('dispose منابع را آزاد می‌کند (themeMode دیگر قابل استفاده نیست)', () {
      final services = AppServices.forTesting();
      services.dispose();

      expect(() => services.themeMode.value = ThemeMode.light, throwsA(anything));
    });
  });

  group('AppServices.ensureLoaded', () {
    testWidgets('محتوای آفلاین و پیشرفت را بارگذاری می‌کند', (tester) async {
      final services = AppServices.forTesting(now: DateTime(2026, 8, 10));
      addTearDown(services.dispose);

      final progress = await services.ensureLoaded();

      expect(progress, isNotNull);
      expect(services.content.programs, isNotEmpty);
      expect(services.content.exercises, isNotEmpty);
      expect(services.content.ranks, isNotEmpty);
    });

    testWidgets('بدون حساب و آفلاین، صف سینک خالی است', (tester) async {
      final services = AppServices.forTesting(now: DateTime(2026, 8, 10));
      addTearDown(services.dispose);

      expect(await services.pendingSyncCount(), 0);
    });
  });

  group('BadaneScope', () {
    testWidgets('maybeOf وقتی scope نیست null برمی‌گرداند', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Test'))),
      );

      final result = BadaneScope.maybeOf(tester.element(find.text('Test')));
      expect(result, isNull);
    });

    testWidgets('of وقتی scope نیست خطای واضح می‌دهد', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Test'))),
      );

      expect(
        () => BadaneScope.of(tester.element(find.text('Test'))),
        throwsFlutterError,
      );
    });

    testWidgets('of و maybeOf همان سرویس‌های تزریق‌شده را می‌دهند',
        (tester) async {
      final services = AppServices.forTesting();
      addTearDown(services.dispose);

      await tester.pumpWidget(
        BadaneScope(
          services: services,
          child: const MaterialApp(home: Scaffold(body: Text('Test'))),
        ),
      );

      final element = tester.element(find.text('Test'));
      expect(BadaneScope.of(element), same(services));
      expect(BadaneScope.maybeOf(element), same(services));
    });
  });

  group('BadaneApp fallback', () {
    test('fallbackServices نمونهٔ حافظه‌ای معتبر می‌سازد', () {
      final services = BadaneApp.fallbackServices();
      addTearDown(services.dispose);

      expect(services.account, isNotNull);
      expect(services.themeMode.value, ThemeMode.system);
    });

    testWidgets('بدون سرویس ورودی، با هر rebuild سرویس تازه ساخته نمی‌شود',
        (tester) async {
      await tester.pumpWidget(const BadaneApp());
      await tester.pumpAndSettle();

      final first = BadaneScope.of(tester.element(find.byType(Scaffold).first));

      // rebuild اجباری
      await tester.pumpWidget(const BadaneApp());
      await tester.pumpAndSettle();

      final second = BadaneScope.of(tester.element(find.byType(Scaffold).first));
      expect(second, same(first));
    });
  });
}
