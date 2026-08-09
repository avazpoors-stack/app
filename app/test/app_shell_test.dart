import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badane/main.dart';

void main() {
  testWidgets('پوستهٔ اصلی چهار تب ناوبری را نشان می‌دهد', (tester) async {
    await tester.pumpWidget(const BadaneApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('برنامه'), findsOneWidget);
    expect(find.text('پیشرفت'), findsOneWidget);
    expect(find.text('پروفایل'), findsOneWidget);
  });

  testWidgets('با لمس هر تب، صفحهٔ متناظر باز می‌شود', (tester) async {
    await tester.pumpWidget(const BadaneApp());

    await tester.tap(find.text('برنامه'));
    await tester.pumpAndSettle();
    // عنوان صفحهٔ برنامه (در نوار بالا) + برچسب تب
    expect(find.text('برنامه'), findsNWidgets(2));

    await tester.tap(find.text('پروفایل'));
    await tester.pumpAndSettle();
    expect(find.text('پروفایل'), findsNWidgets(2));

    await tester.tap(find.text('خانه'));
    await tester.pumpAndSettle();
    expect(find.text('بدنه'), findsOneWidget);
  });
}
