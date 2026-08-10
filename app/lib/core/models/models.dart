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

// ================= P2: حساب‌ها و سینک =================

enum AccountRole { customer, seller, venue, coach, admin }

extension AccountRoleX on AccountRole {
  String get labelFa => switch (this) {
        AccountRole.customer => 'مشتری',
        AccountRole.seller => 'فروشنده',
        AccountRole.venue => 'باشگاه/مکان',
        AccountRole.coach => 'مربی',
        AccountRole.admin => 'ادمین',
      };

  String get descFa => switch (this) {
        AccountRole.customer => 'فقط تمرین و ذخیرهٔ پیشرفت',
        AccountRole.seller => 'پنل فروشگاه (فاز P5)',
        AccountRole.venue => 'ثبت باشگاه/مکان (فاز P4)',
        AccountRole.coach => 'مربی‌هاب (فاز P6)',
        AccountRole.admin => 'مدیریت سرویس',
      };

  static AccountRole fromName(String? name) => switch (name) {
        'seller' => AccountRole.seller,
        'venue' => AccountRole.venue,
        'coach' => AccountRole.coach,
        'admin' => AccountRole.admin,
        _ => AccountRole.customer,
      };
}

class UserAccount {
  const UserAccount({
    required this.phone,
    required this.name,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        phone: json['phone'] as String,
        name: json['name'] as String? ?? '',
        role: AccountRoleX.fromName(json['role'] as String?),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final String phone;
  final String name;
  final AccountRole role;
  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'role': role.name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// رکورد تمرین برای سینک — همان WorkoutEntry + شناسهٔ دستگاه + زمان تغییر.
class SyncEntry {
  const SyncEntry({
    required this.date,
    required this.programId,
    required this.sessionId,
    required this.points,
    required this.clientUid,
    required this.updatedAt,
  });

  factory SyncEntry.fromJson(Map<String, dynamic> json) => SyncEntry(
        date: json['date'] as String,
        programId: json['programId'] as String,
        sessionId: json['sessionId'] as String,
        points: json['points'] as int,
        clientUid: json['clientUid'] as String? ?? '',
        updatedAt: json['updatedAt'] as String,
      );

  final String date; // yyyy-MM-dd
  final String programId;
  final String sessionId;
  final int points;
  final String clientUid;
  final String updatedAt; // ISO 8601

  Map<String, dynamic> toJson() => {
        'date': date,
        'programId': programId,
        'sessionId': sessionId,
        'points': points,
        'clientUid': clientUid,
        'updatedAt': updatedAt,
      };

  WorkoutEntry toWorkoutEntry() => WorkoutEntry(
        date: date,
        programId: programId,
        sessionId: sessionId,
        points: points,
      );
}

class SyncProfile {
  const SyncProfile({
    required this.totalPoints,
    required this.tone,
    required this.activeProgramId,
    required this.updatedAt,
  });

  factory SyncProfile.fromJson(Map<String, dynamic> json) => SyncProfile(
        totalPoints: json['totalPoints'] as int? ?? 0,
        tone: json['tone'] as String? ?? 'supportive',
        activeProgramId: json['activeProgramId'] as String? ?? 'starter',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  final int totalPoints;
  final String tone;
  final String activeProgramId;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'tone': tone,
        'activeProgramId': activeProgramId,
        'updatedAt': updatedAt,
      };
}

class SyncState {
  const SyncState({
    required this.entries,
    required this.profile,
    required this.totalPoints,
    required this.serverTime,
  });

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => SyncEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        profile: SyncProfile.fromJson(
            (json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
        totalPoints:
            (json['totalPoints'] as int?) ?? (json['total_points'] as int?) ?? 0,
        serverTime:
            (json['serverTime'] as String?) ?? (json['server_time'] as String?) ?? '',
      );

  final List<SyncEntry> entries;
  final SyncProfile profile;
  final int totalPoints;
  final String serverTime;

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'profile': profile.toJson(),
        'totalPoints': totalPoints,
        'serverTime': serverTime,
      };
}

// ================= P3: جستجوی سراسری =================

enum SearchCategory { exercise, program, product, venue, coach }

extension SearchCategoryX on SearchCategory {
  String get labelFa => switch (this) {
        SearchCategory.exercise => 'حرکت',
        SearchCategory.program => 'برنامه',
        SearchCategory.product => 'محصول',
        SearchCategory.venue => 'مکان',
        SearchCategory.coach => 'مربی',
      };

  String get sectionFa => switch (this) {
        SearchCategory.exercise => 'حرکات تمرینی',
        SearchCategory.program => 'برنامه‌ها',
        SearchCategory.product => 'فروشگاه',
        SearchCategory.venue => 'مکان‌های ورزشی',
        SearchCategory.coach => 'مربی‌هاب',
      };

  static SearchCategory fromName(String? name) => switch (name) {
        'program' => SearchCategory.program,
        'product' => SearchCategory.product,
        'venue' => SearchCategory.venue,
        'coach' => SearchCategory.coach,
        _ => SearchCategory.exercise,
      };
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.source = 'local',
    this.comingSoon = false,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? (json['titleFa'] as String?) ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        category: SearchCategoryX.fromName(json['category'] as String?),
        source: json['source'] as String? ?? 'remote',
        comingSoon:
            (json['comingSoon'] as bool?) ?? (json['coming_soon'] as bool?) ?? false,
      );

  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String source; // local / remote / mock
  final bool comingSoon; // محصول/مکان/مربی تا فازهای بعد فقط پیش‌نمایش‌اند

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'category': category.name,
        'source': source,
        'comingSoon': comingSoon,
      };
}
