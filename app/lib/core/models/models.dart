import 'dart:convert';

/// مدل‌های دامنهٔ «بدنه» — همهٔ ماژول‌ها از همین تعریف‌ها استفاده می‌کنند
/// (قرارداد اینترفیس نقشهٔ راه ۲.۵: مدل‌های مشترک در core).

enum EnergyLevel { high, normal, low }

extension EnergyLevelX on EnergyLevel {
  String get labelFa => switch (this) {
        EnergyLevel.high => 'زیاد 🔥',
        EnergyLevel.normal => 'معمولی 🙂',
        EnergyLevel.low => 'کم 😴',
      };

  String get descFa => switch (this) {
        EnergyLevel.high => 'پرانرژی؛ برنامهٔ کامل امروز',
        EnergyLevel.normal => 'حالت معمولی؛ برنامهٔ امروز',
        EnergyLevel.low => 'روز خسته‌ای؛ تمرین کوتاه ۱۰ دقیقه‌ای',
      };

  static EnergyLevel fromName(String? name) => switch (name) {
        'high' => EnergyLevel.high,
        'low' => EnergyLevel.low,
        _ => EnergyLevel.normal,
      };
}

enum CoachTone { direct, supportive, playful }

extension CoachToneX on CoachTone {
  String get labelFa => switch (this) {
        CoachTone.direct => 'مستقیم',
        CoachTone.supportive => 'حمایتگر',
        CoachTone.playful => 'شوخ',
      };

  String get descFa => switch (this) {
        CoachTone.direct => 'جدی و کوتاه',
        CoachTone.supportive => 'همدل و تشویق‌کننده',
        CoachTone.playful => 'بازیگوش با کمی طعنه',
      };

  static CoachTone fromName(String? name) => switch (name) {
        'direct' => CoachTone.direct,
        'playful' => CoachTone.playful,
        _ => CoachTone.supportive,
      };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.nameFa,
    required this.muscle,
    required this.equipment,
    required this.tipFa,
    this.corrective = false,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        nameFa: json['nameFa'] as String,
        muscle: json['muscle'] as String? ?? '',
        equipment: json['equipment'] as String? ?? '',
        tipFa: json['tipFa'] as String? ?? '',
        corrective: json['corrective'] as bool? ?? false,
      );

  final String id;
  final String nameFa;
  final String muscle;
  final String equipment;
  final String tipFa;
  final bool corrective;
}

class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.restSec,
  });

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exerciseId'] as String,
        sets: json['sets'] as int,
        reps: json['reps'] as int,
        restSec: json['restSec'] as int? ?? 60,
      );

  final String exerciseId;
  final int sets;
  final int reps;
  final int restSec;
}

class ProgramSession {
  const ProgramSession({
    required this.id,
    required this.name,
    required this.exercises,
  });

  factory ProgramSession.fromJson(Map<String, dynamic> json) =>
      ProgramSession(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List<dynamic>)
            .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final List<SessionExercise> exercises;
}

class WorkoutProgram {
  const WorkoutProgram({
    required this.id,
    required this.name,
    required this.level,
    required this.location,
    required this.daysPerWeek,
    required this.focus,
    required this.sessions,
  });

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) => WorkoutProgram(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as String,
        location: json['location'] as String,
        daysPerWeek: json['daysPerWeek'] as int,
        focus: json['focus'] as String,
        sessions: (json['sessions'] as List<dynamic>)
            .map((s) => ProgramSession.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final String level;
  final String location;
  final int daysPerWeek;
  final String focus;
  final List<ProgramSession> sessions;
}

class Rank {
  const Rank({required this.name, required this.emoji, required this.minPoints});

  factory Rank.fromJson(Map<String, dynamic> json) => Rank(
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        minPoints: json['minPoints'] as int,
      );

  final String name;
  final String emoji;
  final int minPoints;
}

class WorkoutEntry {
  const WorkoutEntry({
    required this.date,
    required this.programId,
    required this.sessionId,
    required this.points,
  });

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) => WorkoutEntry(
        date: json['date'] as String,
        programId: json['programId'] as String,
        sessionId: json['sessionId'] as String,
        points: json['points'] as int,
      );

  final String date; // yyyy-MM-dd
  final String programId;
  final String sessionId;
  final int points;

  Map<String, dynamic> toJson() => {
        'date': date,
        'programId': programId,
        'sessionId': sessionId,
        'points': points,
      };
}

class UserProgress {
  UserProgress({
    this.totalPoints = 0,
    List<WorkoutEntry>? workouts,
    this.energyLevel,
    this.energyDate,
    this.activeProgramId = 'starter',
    this.tone = CoachTone.supportive,
  }) : workouts = workouts ?? [];

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
        totalPoints: json['totalPoints'] as int? ?? 0,
        workouts: (json['workouts'] as List<dynamic>? ?? [])
            .map((w) => WorkoutEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
        energyLevel: EnergyLevelX.fromName(json['energyLevel'] as String?),
        energyDate: json['energyDate'] as String?,
        activeProgramId: json['activeProgramId'] as String? ?? 'starter',
        tone: CoachToneX.fromName(json['tone'] as String?),
      );

  int totalPoints;
  final List<WorkoutEntry> workouts;
  EnergyLevel? energyLevel;
  String? energyDate; // روزی که انرژی انتخاب شده (yyyy-MM-dd)
  String activeProgramId;
  CoachTone tone;

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'energyLevel': energyLevel?.name,
        'energyDate': energyDate,
        'activeProgramId': activeProgramId,
        'tone': tone.name,
      };

  String toJsonString() => jsonEncode(toJson());
}

class WorkoutResult {
  const WorkoutResult({
    required this.breakdown,
    required this.earned,
    required this.totalPoints,
    required this.streak,
    required this.rank,
    required this.isFirst,
  });

  final Map<String, int> breakdown; // sets / exercises / workout / first / streak
  final int earned;
  final int totalPoints;
  final int streak;
  final Rank rank;
  final bool isFirst;
}
