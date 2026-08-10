import '../models/models.dart';

/// اقتصاد داخلی — فرمول امتیازدهی مسترپلن بخش ۴.۱
/// (verified: docs/BADANE_MASTERPLAN.md)
const int scorePerSet = 5;
const int scorePerExercise = 10;
const int scorePerWorkout = 30;
const int scoreFirstWorkout = 50;
const int scoreStreak3 = 20;
const int scoreStreak7 = 70;

/// امتیاز جایزهٔ استریک: رسیدن به ۳ یا ۷ روز.
int streakBonus(int streak) {
  if (streak == 3) return scoreStreak3;
  if (streak == 7) return scoreStreak7;
  return 0;
}

/// تفکیک امتیازهای یک جلسه — مجموع مقادیر، امتیاز کل جلسه است.
Map<String, int> scoreBreakdown({
  required int setsLogged,
  required int exercisesCompleted,
  required bool isFirst,
  required int newStreak,
}) {
  return {
    'sets': setsLogged * scorePerSet,
    'exercises': exercisesCompleted * scorePerExercise,
    'workout': scorePerWorkout,
    'first': isFirst ? scoreFirstWorkout : 0,
    'streak': streakBonus(newStreak),
  };
}

/// رنک بر اساس امتیاز کل — رنک‌بندی مسترپلن بخش ۴.۲.
Rank rankFor(int points, List<Rank> ranks) {
  var current = ranks.first;
  for (final r in ranks) {
    if (points >= r.minPoints) current = r;
  }
  return current;
}
