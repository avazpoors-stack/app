import 'dart:math' as math;

/// تبدیل تاریخ میلادی به جلالی — پورت دقیق الگوریتم Borkowski
/// از کتابخانهٔ jalaali-js (MIT)؛ سورس در همین جلسه از گیت‌هاب دریافت شد
/// (verified: github.com/jalaali/jalaali-js → src/index.ts).
/// صحت تبدیل با بردارهای تست تولیدشده توسط کتابخانهٔ jdatetime پایتون
/// در test/jalali_test.dart راستی‌آزمایی می‌شود.

const List<int> _breaks = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097,
  2192, 2262, 2324, 2394, 2456, 3178,
];

int _div(int a, int b) => (a / b).truncate();

int _mod(int a, int b) => a - _div(a, b) * b;

({int leap, int gy, int march}) _jalCal(int jy) {
  final c = _jalCalCore(jy);
  return (leap: _leapFromCycle(c.jump, c.n), gy: c.gy, march: c.march);
}

({int gy, int march, int jump, int n}) _jalCalCore(int jy) {
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks[0];
  var jm = 0;
  var jump = 0;
  for (var i = 1; i < _breaks.length; i += 1) {
    jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ = leapJ + _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
    jp = jm;
  }
  final n = jy - jp;
  leapJ = leapJ + _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
  if (_mod(jump, 33) == 4 && jump - n == 4) leapJ += 1;

  final leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
  final march = 20 + leapJ - leapG;
  return (gy: gy, march: march, jump: jump, n: n);
}

int _leapFromCycle(int jump, int n) {
  var adjusted = n;
  if (jump - n < 6) {
    adjusted = n - jump + _div(jump + 4, 33) * 33;
  }
  var leap = _mod(_mod(adjusted + 1, 33) - 1, 4);
  if (leap == -1) leap = 4;
  return leap;
}

int _g2d(int gy, int gm, int gd) {
  var d = _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) +
      _div(153 * _mod(gm + 9, 12) + 2, 5) +
      gd -
      34840408;
  d = d - _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) + 752;
  return d;
}

(int, int, int) _d2g(int jdn) {
  var j = 4 * jdn + 139361631;
  j = j + _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
  final i = _div(_mod(j, 1461), 4) * 5 + 308;
  final gd = _div(_mod(i, 153), 5) + 1;
  final gm = _mod(_div(i, 153), 12) + 1;
  final gy = _div(j, 1461) - 100100 + _div(8 - gm, 6);
  return (gy, gm, gd);
}

int _j2d(int jy, int jm, int jd) {
  final r = _jalCalCore(jy);
  return _g2d(r.gy, 3, r.march) + (jm - 1) * 31 - _div(jm, 7) * (jm - 7) + jd - 1;
}

(int, int, int) _d2j(int jdn) {
  final gy = _d2g(jdn).$1;
  var jy = math.min(gy - 621, _breaks.last - 1);
  final r = _jalCal(jy);
  final jdn1f = _g2d(r.gy, 3, r.march);
  var k = jdn - jdn1f;
  if (k >= 0) {
    if (k <= 185) {
      return (jy, 1 + _div(k, 31), _mod(k, 31) + 1);
    }
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r.leap == 1) k += 1;
  }
  return (jy, 7 + _div(k, 30), _mod(k, 30) + 1);
}

/// یک تاریخ جلالی با ابزار نمایش فارسی.
class JalaliDate {
  const JalaliDate._(this.year, this.month, this.day);

  factory JalaliDate.fromGregorian(DateTime g) {
    final (jy, jm, jd) = _d2j(_g2d(g.year, g.month, g.day));
    return JalaliDate._(jy, jm, jd);
  }

  final int year;
  final int month;
  final int day;

  static const List<String> _faDigits = [
    '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
  ];

  /// تبدیل ارقام لاتین به فارسی.
  static String faDigits(String input) {
    final sb = StringBuffer();
    for (final ch in input.split('')) {
      final v = int.tryParse(ch);
      sb.write(v != null && v >= 0 && v <= 9 ? _faDigits[v] : ch);
    }
    return sb.toString();
  }

  /// نام روز هفته به فارسی (هفته از شنبه شروع می‌شود).
  static String weekdayFa(DateTime g) {
    const names = [
      'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه',
    ];
    return names[g.weekday - 1];
  }

  String get faYear => faDigits(year.toString());
  String get faMonth => faDigits(month.toString());
  String get faDay => faDigits(day.toString());

  /// مثال: ۱۴۰۵/۰۵/۱۹
  String formatFa() => '$faYear/$faMonth/$faDay';
}
