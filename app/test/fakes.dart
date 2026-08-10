import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/remote_api.dart';

/// پیاده‌سازی جعلی API برای تست — بدون شبکه (قرارداد اینترفیس ۲.۵).
class FakeRemoteApi implements RemoteApi {
  FakeRemoteApi({this.offline = false});

  bool offline;
  bool loggedOut = false;
  final List<({List<SyncEntry> entries, SyncProfile? profile})> pushes = [];
  SyncState? lastClaim;

  @override
  bool get enabled => !offline;

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return const OtpRequestResult(mock: true, code: '123456');
  }

  @override
  Future<UserAccount> verifyOtp({
    required String phone,
    required String code,
    String? name,
    AccountRole? role,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    if (code != '123456') throw const ApiException(400, 'کد اشتباه است');
    return UserAccount(
      phone: phone,
      name: name ?? '',
      role: role ?? AccountRole.customer,
      accessToken: 'access-test',
      refreshToken: 'refresh-test',
    );
  }

  @override
  Future<UserAccount> login({
    required String phone,
    required String password,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return UserAccount(
      phone: phone,
      name: '',
      role: AccountRole.customer,
      accessToken: 'access-test',
      refreshToken: 'refresh-test',
    );
  }

  @override
  Future<SyncState> push({
    required String accessToken,
    required List<SyncEntry> entries,
    SyncProfile? profile,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    pushes.add((entries: entries, profile: profile));
    return SyncState(
      entries: entries,
      profile: profile ??
          const SyncProfile(
            totalPoints: 0,
            tone: 'supportive',
            activeProgramId: 'starter',
            updatedAt: '',
          ),
      totalPoints: profile?.totalPoints ?? 0,
      serverTime: '2026-08-10T12:00:00Z',
    );
  }

  @override
  Future<SyncState> pull({required String accessToken, String? since}) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return SyncState(
      entries: const [],
      profile: const SyncProfile(
        totalPoints: 0,
        tone: 'supportive',
        activeProgramId: 'starter',
        updatedAt: '',
      ),
      totalPoints: 0,
      serverTime: '2026-08-10T12:00:00Z',
    );
  }

  @override
  Future<SyncState> claim({
    required String accessToken,
    required List<SyncEntry> entries,
    required int totalPoints,
    required String tone,
    required String activeProgramId,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    lastClaim = SyncState(
      entries: entries,
      profile: SyncProfile(
        totalPoints: totalPoints,
        tone: tone,
        activeProgramId: activeProgramId,
        updatedAt: '2026-08-10T12:00:00Z',
      ),
      totalPoints: totalPoints,
      serverTime: '2026-08-10T12:00:00Z',
    );
    return lastClaim!;
  }

  @override
  Future<void> logout(String refreshToken) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    loggedOut = true;
  }
}
