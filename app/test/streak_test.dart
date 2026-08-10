import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/streak.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('بدون جلسه → استریک صفر', () {
    expect(computeStreak([], d(2026, 8, 10)), 0);
  });

  test('فقط امروز → یک', () {
    expect(computeStreak([d(2026, 8, 10)], d(2026, 8, 10)), 1);
  });

  test('دیروز و امروز → دو', () {
    expect(
      computeStreak([d(2026, 8, 9), d(2026, 8, 10)], d(2026, 8, 10)),
      2,
    );
  });

  test('شکاف → فقط روزهای پیاپی آخر', () {
    expect(
      computeStreak(
        [d(2026, 8, 1), d(2026, 8, 2), d(2026, 8, 8), d(2026, 8, 9), d(2026, 8, 10)],
        d(2026, 8, 10),
      ),
      3,
    );
  });

  test('امروز تمرین نشده → شمارش از دیروز', () {
    expect(
      computeStreak([d(2026, 8, 8), d(2026, 8, 9)], d(2026, 8, 10)),
      2,
    );
  });

  test('مرز شبانه‌روز: ۲۳:۵۹ و ۰۰:۰۱', () {
    final sessions = [d(2026, 8, 9), d(2026, 8, 10)];
    // ۱۰ مرداد ساعت ۲۳:۵۹
    expect(
      computeStreak(sessions, DateTime(2026, 8, 10, 23, 59)),
      2,
    );
    // ۱۱ مرداد ساعت ۰۰:۰۱ — هنوز دو روز (دیروز حساب می‌شود)
    expect(
      computeStreak(sessions, DateTime(2026, 8, 11, 0, 1)),
      2,
    );
    // اگر ۱۱ مرداد هم تمرین شده باشد → ۳
    expect(
      computeStreak([...sessions, d(2026, 8, 11)], DateTime(2026, 8, 11, 0, 1)),
      3,
    );
  });
}
