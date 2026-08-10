import '../models/models.dart';
import 'account_repository.dart';
import 'progress_repository.dart';
import 'remote_api.dart';
import 'storage.dart';

/// سینک آفلاین-اول (P2): صف محلی + ارسال به سرور + دریافت + ادغام «آخرین تغییر برنده».
///
/// قوانین:
/// - هر تمرین کامل یک رکورد به صف (یک رکورد برای هر روز) اضافه می‌کند.
/// - اگر حساب و اینترنت باشد، صف فوراً ارسال می‌شود؛ در غیر این صورت در صف می‌ماند.
/// - در ورود/همگام‌سازی دستی: push صف ← pull وضعیت سرور ← ادغام در پیشرفت محلی.
/// - ادعای مهمان (claim): دادهٔ مهمان یک‌بار به حساب منتقل می‌شود.
class SyncService {
  SyncService({
    required this.repository,
    required this.api,
    required this.progress,
    required this.clock,
  });

  final AccountRepository repository;
  final RemoteApi api;
  final ProgressRepository progress;
  final Clock clock;

  /// تعداد رکوردهای در انتظار در صف محلی.
  Future<int> pendingCount() async => (await repository.loadQueue()).length;

  /// بعد از هر تمرین کامل — همیشه در صف محلی ذخیره می‌شود (آفلاین-اول).
  Future<void> recordWorkout({
    required String programId,
    required String sessionId,
    required int points,
  }) async {
    final entry = SyncEntry(
      date: Clock.dateStr(clock.now()),
      programId: programId,
      sessionId: sessionId,
      points: points,
      clientUid: await repository.clientUid(),
      updatedAt: clock.now().toUtc().toIso8601String(),
    );
    final queue = await repository.loadQueue();
    // یک رکورد برای هر روز؛ رکورد تازه‌تر جایگزین قبلی می‌شود
    queue.removeWhere((e) => e.date == entry.date);
    queue.add(entry);
    await repository.saveQueue(queue);

    final account = await repository.loadAccount();
    if (account != null && api.enabled) {
      await _pushAndApply(account);
    }
  }

  /// همگام‌سازی دستی: push صف ← pull ← ادغام در پیشرفت محلی.
  Future<bool> syncNow() async {
    final account = await repository.loadAccount();
    if (account == null || !api.enabled) return false;
    try {
      await _pushAndApply(account);
      return true;
    } on ApiException {
      return false;
    }
  }

  /// انتقال دادهٔ مهمان (P1) به حساب تازه — بعد از اولین ورود.
  Future<void> claimGuest() async {
    final account = await repository.loadAccount();
    if (account == null || !api.enabled) return;
    final p = await progress.load();
    final entries = await _allLocalEntries();
    final state = await api.claim(
      accessToken: account.accessToken,
      entries: entries,
      totalPoints: p.totalPoints,
      tone: p.tone.name,
      activeProgramId: p.activeProgramId,
    );
    await repository.saveQueue([]);
    await _applyServerState(state);
    await repository.saveSyncState(state);
  }

  // ---------- داخلی ----------

  Future<void> _pushAndApply(UserAccount account) async {
    final queue = await repository.loadQueue();
    final p = await progress.load();
    final profile = SyncProfile(
      totalPoints: p.totalPoints,
      tone: p.tone.name,
      activeProgramId: p.activeProgramId,
      updatedAt: clock.now().toUtc().toIso8601String(),
    );
    final state = await api.push(
      accessToken: account.accessToken,
      entries: queue,
      profile: profile,
    );
    await repository.saveQueue([]); // ارسال موفق → صف خالی
    await _applyServerState(state);
    await repository.saveSyncState(state);
  }

  Future<List<SyncEntry>> _allLocalEntries() async {
    final p = await progress.load();
    final uid = await repository.clientUid();
    return [
      for (final w in p.workouts)
        SyncEntry(
          date: w.date,
          programId: w.programId,
          sessionId: w.sessionId,
          points: w.points,
          clientUid: uid,
          updatedAt: clock.now().toUtc().toIso8601String(),
        ),
    ];
  }

  /// ادغام وضعیت سرور در پیشرفت محلی — سرور پس از push موفق مرجع است؛
  /// رکوردهای محلیِ هنوز ارسال‌نشده حفظ می‌شوند.
  Future<void> _applyServerState(SyncState state) async {
    final p = await progress.load();
    for (final e in state.entries) {
      p.workouts.removeWhere((w) => w.date == e.date);
      p.workouts.add(e.toWorkoutEntry());
    }
    p.workouts.sort((a, b) => a.date.compareTo(b.date));
    if (state.totalPoints > 0 || state.entries.isNotEmpty) {
      p.totalPoints = state.totalPoints;
    }
    p.tone = CoachToneX.fromName(state.profile.tone);
    p.activeProgramId = state.profile.activeProgramId;
    await progress.save();
  }
}
