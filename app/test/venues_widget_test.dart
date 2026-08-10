import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/app_services.dart';
import 'package:badane/features/venues/venues_screen.dart';

void main() {
  testWidgets('صفحه مکان‌ها دسته‌ها، نقشه Mock و ثبت مکان را نشان می‌دهد', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices.forTesting();
    await tester.pumpWidget(
      BadaneScope(
        services: services,
        child: const MaterialApp(home: VenuesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مکان‌های ورزشی'), findsOneWidget);
    expect(find.text('نقشه نشان در حالت Mock'), findsOneWidget);
    expect(find.text('استخر'), findsWidgets);
    expect(find.text('ثبت مکان'), findsOneWidget);

    await tester.tap(find.text('ثبت مکان'));
    await tester.pumpAndSettle();

    expect(find.text('ثبت مکان ورزشی'), findsOneWidget);
    expect(find.text('نام مکان'), findsOneWidget);
  });
}
