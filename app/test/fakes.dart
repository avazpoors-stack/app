import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/remote_api.dart';

/// پیاده‌سازی جعلی API برای تست — بدون شبکه (قرارداد اینترفیس ۲.۵).
class FakeRemoteApi implements RemoteApi {
  FakeRemoteApi({
    this.offline = false,
    List<SearchResult>? searchResults,
    List<Venue>? venues,
  })  : searchResults = searchResults ?? const [],
        venues = venues ?? const [];

  bool offline;
  bool loggedOut = false;
  final List<SearchResult> searchResults;
  final List<Venue> venues;
  final List<VenueDraft> createdVenues = [];
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
  Future<List<SearchResult>> search({
    required String query,
    SearchCategory? category,
    int limit = 20,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return searchResults
        .where((r) => category == null || r.category == category)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<Venue>> listVenues({
    VenueCategory? category,
    String? query,
    int limit = 50,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return venues
        .where((v) => category == null || v.category == category)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<Venue> createVenue({
    required String accessToken,
    required VenueDraft draft,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    createdVenues.add(draft);
    return Venue.fromDraft(draft, id: 'remote-${createdVenues.length}');
  }

  @override
  Future<List<Product>> listProducts({
    String? category,
    String? brand,
    String? query,
    int? minPrice,
    int? maxPrice,
    int limit = 50,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return const [];
  }

  @override
  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return Product.fromDraft(draft, id: 'remote-prod', sellerId: 1);
  }

  @override
  Future<OrderResult> createOrder({
    required String accessToken,
    required List<OrderItemDraft> items,
    required String idempotencyKey,
  }) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    return OrderResult(
      orderId: 'mock-$idempotencyKey',
      status: 'payment_pending',
      totalToman: items.fold(0, (s, i) => s + i.priceToman * i.quantity),
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    if (offline) throw const ApiException(0, 'آفلاین');
    loggedOut = true;
  }
}
