import 'dart:convert';

import '../models/models.dart';
import 'account_repository.dart';
import 'remote_api.dart';
import 'search_service.dart';
import 'storage.dart';

/// سرویس مکان‌های ورزشی (P4) — آفلاین-اول و بدون کلید اجباری.
/// بدون `NESHAN_API_KEY` نقشه به‌صورت placeholder نمایش داده می‌شود.
class VenueService {
  VenueService({
    required KeyValueStore store,
    required RemoteApi api,
    required AccountRepository account,
    this.neshanApiKey = '',
  })  : _store = store,
        _api = api,
        _account = account;

  final KeyValueStore _store;
  final RemoteApi _api;
  final AccountRepository _account;
  final String neshanApiKey;

  static const _localKey = 'badane_local_venues.json';

  bool get neshanConfigured => neshanApiKey.trim().isNotEmpty;

  Future<List<Venue>> list({
    VenueCategory? category,
    String query = '',
    bool includePending = true,
  }) async {
    final normalized = SearchService.normalize(query);
    final merged = <String, Venue>{};

    for (final venue in _mockVenues) {
      if (_matches(venue, category, normalized)) merged['mock:${venue.id}'] = venue;
    }
    for (final venue in await _loadLocal()) {
      if (!includePending && venue.status != VenueStatus.approved) continue;
      if (_matches(venue, category, normalized)) merged['local:${venue.id}'] = venue;
    }

    if (_api.enabled) {
      try {
        final remote = await _api.listVenues(category: category, query: query);
        for (final venue in remote) {
          if (_matches(venue, category, normalized)) merged['remote:${venue.id}'] = venue;
        }
      } on ApiException {
        // مکان‌های محلی و نمونه حتی بدون اینترنت دیده می‌شوند.
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) {
      final status = _statusWeight(a.status).compareTo(_statusWeight(b.status));
      if (status != 0) return status;
      return a.name.compareTo(b.name);
    });
    return result;
  }

  Future<Venue> submit(VenueDraft draft) async {
    final account = await _account.loadAccount();
    if (_api.enabled && account != null) {
      try {
        return await _api.createVenue(
          accessToken: account.accessToken,
          draft: draft,
        );
      } on ApiException {
        // اگر سرور در دسترس نبود، ثبت محلی pending انجام می‌شود تا بعداً کار از بین نرود.
      }
    }
    final local = Venue.fromDraft(
      draft,
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
    );
    final venues = await _loadLocal();
    venues.insert(0, local);
    await _saveLocal(venues);
    return local;
  }

  Future<List<Venue>> _loadLocal() async {
    final raw = await _store.read(_localKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Venue.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(List<Venue> venues) async {
    await _store.write(_localKey, jsonEncode(venues.map((v) => v.toJson()).toList()));
  }

  bool _matches(Venue venue, VenueCategory? category, String normalizedQuery) {
    if (category != null && venue.category != category) return false;
    if (normalizedQuery.length < 2) return true;
    final text = SearchService.normalize(
      '${venue.name} ${venue.category.labelFa} ${venue.city} ${venue.address} ${venue.description}',
    );
    return text.contains(normalizedQuery);
  }

  int _statusWeight(VenueStatus status) => switch (status) {
        VenueStatus.approved => 0,
        VenueStatus.pending => 1,
        VenueStatus.rejected => 2,
      };
}

const _mockVenues = <Venue>[
  Venue(
    id: 'mock_pool_1',
    name: 'استخر نمونه بدنه',
    category: VenueCategory.pool,
    city: 'تهران',
    address: 'محدوده نمونه — نقشه نشان در حالت Mock',
    description: 'نمونه برای نمایش دستهٔ استخر تا زمان اتصال دادهٔ واقعی.',
    lat: 35.7219,
    lng: 51.3347,
    tariffs: [VenueTariff(title: 'سانس آزاد', priceToman: 120000)],
    status: VenueStatus.approved,
    source: 'mock',
  ),
  Venue(
    id: 'mock_gym_1',
    name: 'باشگاه بدنسازی نمونه',
    category: VenueCategory.gym,
    city: 'تهران',
    address: 'محدوده نمونه — نزدیک‌ترین باشگاه‌ها بعداً از سرور می‌آید',
    description: 'نمونه برای نمایش کارت باشگاه، تعرفه و وضعیت تأیید.',
    lat: 35.7001,
    lng: 51.4012,
    tariffs: [VenueTariff(title: 'جلسه آزاد', priceToman: 150000)],
    status: VenueStatus.approved,
    source: 'mock',
  ),
  Venue(
    id: 'mock_corrective_1',
    name: 'مرکز حرکت اصلاحی نمونه',
    category: VenueCategory.corrective,
    city: 'تهران',
    address: 'محدوده نمونه — پیشنهادهای غیرتشخیصی',
    description: 'برای اتصال آینده به AI پاسچر و مربی‌هاب آماده است.',
    tariffs: [VenueTariff(title: 'ارزیابی تمرینی', priceToman: 250000)],
    status: VenueStatus.approved,
    source: 'mock',
  ),
];
