import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/services/jalali.dart';

/// بردارهای تست تولیدشده با کتابخانهٔ jdatetime پایتون (verified: اجرای
/// محلی با `pip install jdatetime` در 2026-08-09).
const testVectors = <(int, int, int, int, int, int)>{
  (2026, 8, 10, 1405, 5, 19),
  (2026, 3, 20, 1404, 12, 29),
  (2026, 3, 21, 1405, 1, 1),
  (2025, 3, 20, 1403, 12, 30),
  (2025, 3, 21, 1404, 1, 1),
  (2024, 3, 19, 1402, 12, 29),
  (2024, 3, 20, 1403, 1, 1),
  (2024, 12, 31, 1403, 10, 11),
  (2024, 1, 1, 1402, 10, 11),
  (2000, 1, 1, 1378, 10, 11),
  (1999, 3, 21, 1378, 1, 1),
  (2021, 3, 21, 1400, 1, 1),
  (2021, 3, 20, 1399, 12, 30),
  (2022, 1, 1, 1400, 10, 11),
  (2022, 12, 31, 1401, 10, 10),
  (2023, 8, 23, 1402, 6, 1),
  (2026, 1, 1, 1404, 10, 11),
  (2026, 12, 31, 1405, 10, 10),
  (2025, 6, 21, 1404, 3, 31),
  (2027, 3, 21, 1406, 1, 1),
};

void main() {
  group('تبدیل میلادی به جلالی', () {
    for (final (gy, gm, gd, jy, jm, jd) in testVectors) {
      test('$gy-$gm-$gd ← جلالی $jy/$jm/$jd', () {
        final j = JalaliDate.fromGregorian(DateTime(gy, gm, gd));
        expect(j.year, jy);
        expect(j.month, jm);
        expect(j.day, jd);
      });
    }
  });

  test('فرمت فارسی و رقم‌های فارسی', () {
    final j = JalaliDate.fromGregorian(DateTime(2026, 8, 10));
    expect(j.formatFa(), '۱۴۰۵/۰۵/۱۹');
    expect(JalaliDate.faDigits('2026'), '۲۰۲۶');
    expect(JalaliDate.faDigits('abc123'), 'abc۱۲۳');
  });

  test('نام روز هفته', () {
    // 2026-08-10 دوشنبه است (میلادی)
    expect(JalaliDate.weekdayFa(DateTime(2026, 8, 10)), 'دوشنبه');
    // 2026-08-08 شنبه
    expect(JalaliDate.weekdayFa(DateTime(2026, 8, 8)), 'شنبه');
    // 2026-08-14 جمعه
    expect(JalaliDate.weekdayFa(DateTime(2026, 8, 14)), 'جمعه');
  });
}
