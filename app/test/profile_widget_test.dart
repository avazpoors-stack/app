import 'package:badane/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BadaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('پروفایل'));
    await tester.pumpAndSettle();
  }

  testWidgets('تب پروفایل در حالت مهمان: کارت ورود و تنظیمات دیده می‌شود', (tester) async {
    await openProfile(tester);

    expect(find.text('مهمان'), findsOneWidget);
    expect(find.text('ورود / ثبت‌نام'), findsOneWidget);
    expect(find.text('لحن مربی'), findsOneWidget);
    expect(find.text('تم'), findsOneWidget);
    expect(find.text('همراه با سیستم'), findsOneWidget);
  });

  testWidgets('باز کردن برگهٔ ورود/ثبت‌نام', (tester) async {
    await openProfile(tester);

    await tester.tap(find.text('ورود / ثبت‌نام'));
    await tester.pumpAndSettle();

    expect(find.text('دریافت کد تأیید'), findsOneWidget);
    expect(find.text('شماره موبایل'), findsOneWidget);
  });
}
