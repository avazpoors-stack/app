import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/app_services.dart';
import 'package:badane/main.dart';

void main() {
  testWidgets('فروشگاه دسته‌ها و محصولات Mock را نشان می‌دهد', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices.forTesting();
    await tester.pumpWidget(BadaneApp(services: services));
    await tester.pumpAndSettle();

    // برو به تب فروشگاه (سوم)
    await tester.tap(find.text('فروشگاه'));
    await tester.pumpAndSettle();

    expect(find.text('فروشگاه ورزشی'), findsOneWidget);
    expect(find.text('لباس ورزشی'), findsWidgets);
    expect(find.text('تجهیزات بدنسازی'), findsWidgets);
    expect(find.text('تی‌شرت تمرینی بدنه'), findsOneWidget);
  });

  testWidgets('افزودن به سبد و نمایش سبد', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices.forTesting();
    await tester.pumpWidget(BadaneApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فروشگاه'));
    await tester.pumpAndSettle();

    // اولین محصول افزودن
    final addButtons = find.text('افزودن');
    expect(addButtons, findsWidgets);
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('به سبد اضافه شد'), findsOneWidget);
  });
}
