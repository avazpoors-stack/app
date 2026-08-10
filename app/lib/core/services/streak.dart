/// محاسبهٔ استریک (روزهای پیاپی تمرین) — بر اساس تاریخ‌های جلسات.
/// اگر امروز هنوز تمرین نشده، شمارش از دیروز شروع می‌شود.
int computeStreak(List<DateTime> dates, DateTime today) {
  final set = <DateTime>{};
  for (final d in dates) {
    set.add(DateTime(d.year, d.month, d.day));
  }
  final t = DateTime(today.year, today.month, today.day);
  var cursor = t;
  if (!set.contains(cursor)) {
    cursor = t.subtract(const Duration(days: 1));
  }
  var count = 0;
  while (set.contains(cursor)) {
    count++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}
