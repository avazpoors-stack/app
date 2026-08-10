import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/account_repository.dart';
import 'package:badane/core/services/progress_repository.dart';
import 'package:badane/core/services/storage.dart';
import 'package:badane/core/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _ranks = [Rank(name: 'نوپا', emoji: '🌱', minPoints: 0)];

void main() {
  final now = DateTime(2026, 8, 10, 15, 0);

  test('تمرین در حالت مهمان → در صف محلی می‌ماند و ارسال نمی‌شود', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi(offline: true);
    final progress = ProgressRepository(store);
    final sync = SyncService(
      repository: AccountRepository(store),
      api: api,
      progress: progress,
      clock: Clock(fixed: now),
    );

    await sync.recordWorkout(programId: 'starter', sessionId: 's1', points: 45);
    expect(await sync.pendingCount(), 1);
    expect(api.pushes, isEmpty);
  });

  test('با حساب و آنلاین → صف ارسال و خالی می‌شود', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi();
    final accountRepo = AccountRepository(store);
    final progress = ProgressRepository(store);
    final sync = SyncService(
      repository: accountRepo,
      api: api,
      progress: progress,
      clock: Clock(fixed: now),
    );

    // اول آفلاین: یک رکورد در صف
    api.offline = true;
    await sync.recordWorkout(programId: 'starter', sessionId: 's1', points: 45);
    expect(await sync.pendingCount(), 1);

    // بعد آنلاین + حساب: رکورد جدید → push می‌شود
    await accountRepo.saveAccount(const UserAccount(
      phone: '09120000001',
      name: 'علی',
      role: AccountRole.customer,
      accessToken: 'a',
      refreshToken: 'r',
    ));
    api.offline = false;
    await sync.recordWorkout(programId: 'starter', sessionId: 's2', points: 30);

    expect(api.pushes, hasLength(1));
    expect(api.pushes.single.entries, hasLength(2));
    expect(await sync.pendingCount(), 0);
  });

  test('یک رکورد برای هر روز (آخرین تغییر برنده در صف)', () async {
    final store = InMemoryStore();
    final sync = SyncService(
      repository: AccountRepository(store),
      api: FakeRemoteApi(offline: true),
      progress: ProgressRepository(store),
      clock: Clock(fixed: now),
    );

    await sync.recordWorkout(programId: 'starter', sessionId: 's1', points: 10);
    await sync.recordWorkout(programId: 'starter', sessionId: 's1', points: 30);

    final queue = await AccountRepository(store).loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.points, 30);
  });

  test('claimGuest: دادهٔ مهمان (تمرین + امتیاز) به حساب منتقل می‌شود', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi();
    final accountRepo = AccountRepository(store);
    final progress = ProgressRepository(store);

    // ثبت یک تمرین به‌عنوان مهمان (P1)
    await progress.completeWorkout(
      programId: 'starter',
      sessionId: 's1',
      setsLogged: 10,
      exercisesCompleted: 5,
      ranks: _ranks,
      now: now,
    );
    final guestPoints = (await progress.load()).totalPoints;
    expect(guestPoints, greaterThan(0));

    // ورود → انتقال دادهٔ مهمان
    await accountRepo.saveAccount(const UserAccount(
      phone: '09120000002',
      name: 'مریم',
      role: AccountRole.customer,
      accessToken: 'a',
      refreshToken: 'r',
    ));
    final sync = SyncService(
      repository: accountRepo,
      api: api,
      progress: progress,
      clock: Clock(fixed: now),
    );
    await sync.claimGuest();

    expect(api.lastClaim, isNotNull);
    expect(api.lastClaim!.totalPoints, guestPoints);
    expect(api.lastClaim!.entries, hasLength(1));
    expect(await sync.pendingCount(), 0);
  });

  test('syncNow: وضعیت سرور به پیشرفت محلی اعمال می‌شود', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi();
    final accountRepo = AccountRepository(store);
    final progress = ProgressRepository(store);
    await accountRepo.saveAccount(const UserAccount(
      phone: '09120000003',
      name: 'رضا',
      role: AccountRole.customer,
      accessToken: 'a',
      refreshToken: 'r',
    ));

    final sync = SyncService(
      repository: accountRepo,
      api: api,
      progress: progress,
      clock: Clock(fixed: now),
    );
    // مثل جریان واقعی اپ: اول تمرین کامل می‌شود، بعد رکورد به صف سینک می‌رود
    final result = await progress.completeWorkout(
      programId: 'grow',
      sessionId: 's1',
      setsLogged: 10,
      exercisesCompleted: 5,
      ranks: _ranks,
      now: now,
    );
    await sync.recordWorkout(
      programId: 'grow',
      sessionId: 's1',
      points: result.earned,
    );

    // تغییر لحن محلی + همگام‌سازی دستی
    await progress.setTone(CoachTone.direct);
    final ok = await sync.syncNow();
    expect(ok, true);

    final p = await progress.load();
    expect(p.workouts, hasLength(1));
    expect(p.workouts.single.points, result.earned);
    expect(p.totalPoints, result.earned);
    expect(p.tone, CoachTone.direct);
    expect(p.activeProgramId, 'starter');
  });

  test('syncNow آفلاین → false بدون خطا', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi(offline: true);
    final sync = SyncService(
      repository: AccountRepository(store),
      api: api,
      progress: ProgressRepository(store),
      clock: Clock(fixed: now),
    );
    expect(await sync.syncNow(), false);
  });
}
