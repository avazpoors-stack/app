import 'dart:convert';

import '../models/models.dart';
import 'scoring.dart';
import 'storage.dart';
import 'streak.dart';

/// مدیریت پیشرفت کاربر: امتیاز، جلسات، انرژی روز، برنامهٔ فعال، لحن.
/// همهٔ تغییرها بلافاصله در حافظهٔ محلی ذخیره می‌شوند (آفلاین-اول).
class ProgressRepository {
  ProgressRepository(this._store);

  final KeyValueStore _store;
  static const String _key = 'badane_progress.json';

  UserProgress? _cache;

  Future<UserProgress> load() async {
    if (_cache != null) return _cache!;
    final raw = await _store.read(_key);
    if (raw == null) {
      _cache = UserProgress();
      return _cache!;
    }
    try {
      _cache = UserProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // دادهٔ خراب → شروع تمیز (هرگز کرش نمی‌کنیم)
      _cache = UserProgress();
    }
    return _cache!;
  }

  Future<void> _persist() async {
    await _store.write(_key, _cache!.toJsonString());
  }

  Future<void> setEnergy(EnergyLevel level, DateTime now) async {
    await load();
    _cache!.energyLevel = level;
    _cache!.energyDate = Clock.dateStr(now);
    await _persist();
  }

  Future<void> setActiveProgram(String programId) async {
    await load();
    _cache!.activeProgramId = programId;
    await _persist();
  }

  Future<void> setTone(CoachTone tone) async {
    await load();
    _cache!.tone = tone;
    await _persist();
  }

  bool energySelectedToday(DateTime now) =>
      _cache?.energyDate == Clock.dateStr(now);

  /// ثبت کامل یک جلسه: محاسبهٔ امتیاز، استریک و رنک + ذخیره.
  Future<WorkoutResult> completeWorkout({
    required String programId,
    required String sessionId,
    required int setsLogged,
    required int exercisesCompleted,
    required List<Rank> ranks,
    required DateTime now,
  }) async {
    await load();
    final isFirst = _cache!.workouts.isEmpty;
    final dateStr = Clock.dateStr(now);
    final alreadyToday = _cache!.workouts.any((w) => w.date == dateStr);

    final datesForStreak = _cache!.workouts.map((w) {
      final parts = w.date.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList();
    if (!alreadyToday) {
      datesForStreak.add(DateTime(now.year, now.month, now.day));
    }
    final newStreak = computeStreak(datesForStreak, now);

    final breakdown = scoreBreakdown(
      setsLogged: setsLogged,
      exercisesCompleted: exercisesCompleted,
      isFirst: isFirst,
      newStreak: newStreak,
    );
    final earned = breakdown.values.fold(0, (a, b) => a + b);

    if (!alreadyToday) {
      _cache!.workouts.add(WorkoutEntry(
        date: dateStr,
        programId: programId,
        sessionId: sessionId,
        points: earned,
      ));
    }
    _cache!.totalPoints += earned;
    await _persist();

    return WorkoutResult(
      breakdown: breakdown,
      earned: earned,
      totalPoints: _cache!.totalPoints,
      streak: newStreak,
      rank: rankFor(_cache!.totalPoints, ranks),
      isFirst: isFirst,
    );
  }
}
