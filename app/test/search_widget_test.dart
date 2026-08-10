import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/app_services.dart';
import 'package:badane/main.dart';

import 'search_service_test.dart';

void main() {
  testWidgets('جستجوی سراسری از خانه باز می‌شود و نتیجهٔ آفلاین نشان می‌دهد', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices.forTesting(contentOverrides: searchTestContent);
    await tester.pumpWidget(BadaneApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('جستجوی سراسری'));
    await tester.pumpAndSettle();

    expect(find.text('جستجوی سراسری'), findsOneWidget);
    expect(find.text('پیشنهاد سریع'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'اسکوات');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('پا · بدون وسیله'), findsOneWidget);
    expect(find.text('حرکت'), findsWidgets);
  });
}
