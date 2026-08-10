import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/scoring.dart';

const testRanks = [
  Rank(name: 'نوپا', emoji: '⚪', minPoints: 0),
  Rank(name: 'جنگجو', emoji: '🟠', minPoints: 500),
  Rank(name: 'گلادیاتور', emoji: '⚔️', minPoints: 2000),
  Rank(name: 'اسطوره', emoji: '🏆', minPoints: 5000),
];

void main() {
  test('امتیاز جلسهٔ اول: ست‌ها + حرکات + تمرین + اولین', () {
    final b = scoreBreakdown(
      setsLogged: 6,
      exercisesCompleted: 2,
      isFirst: true,
      newStreak: 1,
    );
    expect(b['sets'], 30); // 6 × 5
    expect(b['exercises'], 20); // 2 × 10
    expect(b['workout'], 30);
    expect(b['first'], 50);
    expect(b['streak'], 0);
    expect(b.values.fold(0, (a, x) => a + x), 130);
  });

  test('جایزهٔ استریک ۳ و ۷ روز', () {
    expect(streakBonus(3), 20);
    expect(streakBonus(7), 70);
    expect(streakBonus(1), 0);
    expect(streakBonus(4), 0);
  });

  test('رنک‌بندی مرزها', () {
    expect(rankFor(0, testRanks).name, 'نوپا');
    expect(rankFor(499, testRanks).name, 'نوپا');
    expect(rankFor(500, testRanks).name, 'جنگجو');
    expect(rankFor(1999, testRanks).name, 'جنگجو');
    expect(rankFor(2000, testRanks).name, 'گلادیاتور');
    expect(rankFor(4999, testRanks).name, 'گلادیاتور');
    expect(rankFor(5000, testRanks).name, 'اسطوره');
    expect(rankFor(99999, testRanks).name, 'اسطوره');
  });
}
