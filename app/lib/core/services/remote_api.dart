import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// خطای API — شمارهٔ وضعیت HTTP و پیام فارسی.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isNetwork => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

class OtpRequestResult {
  const OtpRequestResult({required this.mock, this.code});

  final bool mock;
  final String? code; // فقط در حالت توسعه
}

/// قرارداد اینترفیس ۲.۵: رابط راه‌دور (Remote) — UI هرگز مستقیم به شبکه دست نمی‌زند.
/// پیاده‌سازی‌ها: HttpRemoteApi (سرور واقعی) و OfflineRemoteApi (بدون اینترنت/کلید).
abstract class RemoteApi {
  bool get enabled;

  Future<OtpRequestResult> requestOtp(String phone);
  Future<UserAccount> verifyOtp({
    required String phone,
    required String code,
    String? name,
    AccountRole? role,
  });
  Future<UserAccount> login({required String phone, required String password});
  Future<SyncState> push({
    required String accessToken,
    required List<SyncEntry> entries,
    SyncProfile? profile,
  });
  Future<SyncState> pull({required String accessToken, String? since});
  Future<SyncState> claim({
    required String accessToken,
    required List<SyncEntry> entries,
    required int totalPoints,
    required String tone,
    required String activeProgramId,
  });
  Future<List<SearchResult>> search({
    required String query,
    SearchCategory? category,
    int limit = 20,
  });
  Future<List<Venue>> listVenues({
    VenueCategory? category,
    String? query,
    int limit = 50,
  });
  Future<Venue> createVenue({
    required String accessToken,
    required VenueDraft draft,
  });
  Future<List<Product>> listProducts({
    String? category,
    String? brand,
    String? query,
    int? minPrice,
    int? maxPrice,
    int limit = 50,
  });
  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
  });
  Future<OrderResult> createOrder({
    required String accessToken,
    required List<OrderItemDraft> items,
    required String idempotencyKey,
  });
  Future<void> logout(String refreshToken);
}

/// پیاده‌سازی HTTP با dart:io (بدون وابستگی خارجی — اصل «کد سبک»).
class HttpRemoteApi implements RemoteApi {
  HttpRemoteApi({required this.baseUrl});

  /// مثل `http://10.0.2.2:8000/api/v1` — از `--dart-define=BADANE_API_URL=...`
  final String baseUrl;

  @override
  bool get enabled => baseUrl.isNotEmpty;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final data = await _sendRaw(method, path, body, token: token);
    if (data is Map<String, dynamic>) return data;
    if (data is List<dynamic>) return {'items': data};
    return <String, dynamic>{};
  }

  Future<dynamic> _sendRaw(
    String method,
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = method == 'GET'
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (method != 'GET') {
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join();
      final data = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = data is Map<String, dynamic>
            ? data['detail'] as String?
            : null;
        throw ApiException(
          response.statusCode,
          detail ?? 'خطا در ارتباط با سرور',
        );
      }
      return data;
    } on SocketException {
      throw const ApiException(0, 'به اینترنت دسترسی نیست');
    } on HttpException {
      throw const ApiException(0, 'سرور در دسترس نیست');
    } on TimeoutException {
      throw const ApiException(0, 'سرور دیر پاسخ داد؛ دوباره تلاش کن');
    } finally {
      client.close();
    }
  }

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    final data = await _send(
        'POST', '/auth/otp/request', <String, dynamic>{'phone': phone});
    return OtpRequestResult(
      mock: data['mock'] as bool? ?? false,
      code: data['code'] as String?,
    );
  }

  @override
  Future<UserAccount> verifyOtp({
    required String phone,
    required String code,
    String? name,
    AccountRole? role,
  }) async {
    final data = await _send('POST', '/auth/otp/verify', <String, dynamic>{
      'phone': phone,
      'code': code,
      if (name != null && name.isNotEmpty) 'name': name,
      if (role != null) 'role': role.name,
    });
    return _accountFromTokens(phone, name, role, data);
  }

  @override
  Future<UserAccount> login({
    required String phone,
    required String password,
  }) async {
    final data = await _send(
        'POST', '/auth/login', <String, dynamic>{'phone': phone, 'password': password});
    return _accountFromTokens(phone, '', AccountRole.customer, data);
  }

  UserAccount _accountFromTokens(
    String phone,
    String? name,
    AccountRole? role,
    Map<String, dynamic> data,
  ) {
    final account = UserAccount(
      phone: phone,
      name: name ?? '',
      role: role ?? AccountRole.customer,
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return account;
  }

  @override
  Future<SyncState> push({
    required String accessToken,
    required List<SyncEntry> entries,
    SyncProfile? profile,
  }) async {
    final data = await _send('POST', '/sync/push', <String, dynamic>{
      'entries': entries.map((e) => e.toJson()).toList(),
      if (profile != null) 'profile': profile.toJson(),
    }, token: accessToken);
    return SyncState.fromJson(data);
  }

  @override
  Future<SyncState> pull({required String accessToken, String? since}) async {
    final query = since == null ? '' : '?since=${Uri.encodeQueryComponent(since)}';
    final data = await _send('GET', '/sync/pull$query', <String, dynamic>{},
        token: accessToken);
    return SyncState.fromJson(data);
  }

  @override
  Future<SyncState> claim({
    required String accessToken,
    required List<SyncEntry> entries,
    required int totalPoints,
    required String tone,
    required String activeProgramId,
  }) async {
    final data = await _send('POST', '/sync/claim', <String, dynamic>{
      'entries': entries.map((e) => e.toJson()).toList(),
      'total_points': totalPoints,
      'tone': tone,
      'active_program_id': activeProgramId,
    }, token: accessToken);
    return SyncState.fromJson(data);
  }

  @override
  Future<List<SearchResult>> search({
    required String query,
    SearchCategory? category,
    int limit = 20,
  }) async {
    final queryString = Uri(queryParameters: <String, String>{
      'q': query,
      'limit': limit.clamp(1, 50).toString(),
      if (category != null) 'category': category.name,
    }).query;
    final data = await _send('GET', '/search?$queryString', <String, dynamic>{});
    return (data['results'] as List<dynamic>? ?? [])
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<Venue>> listVenues({
    VenueCategory? category,
    String? query,
    int limit = 50,
  }) async {
    final queryString = Uri(queryParameters: <String, String>{
      'limit': limit.clamp(1, 100).toString(),
      if (category != null) 'category': category.apiName,
      if (query != null && query.trim().length >= 2) 'q': query.trim(),
    }).query;
    final data = await _send('GET', '/venues?$queryString', <String, dynamic>{});
    return _listFromJson(data).map(Venue.fromJson).toList(growable: false);
  }

  @override
  Future<Venue> createVenue({
    required String accessToken,
    required VenueDraft draft,
  }) async {
    final data = await _send('POST', '/venues', draft.toJson(), token: accessToken);
    return Venue.fromJson(data);
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
    final queryString = Uri(queryParameters: <String, String>{
      'limit': limit.clamp(1, 100).toString(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (query != null && query.trim().length >= 2) 'q': query.trim(),
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    }).query;
    final data = await _send('GET', '/shop/products?$queryString', <String, dynamic>{});
    // endpoint returns list directly or {items: []}
    final list = data['items'] is List
        ? data['items'] as List<dynamic>
        : (data['results'] is List
            ? data['results'] as List<dynamic>
            : (data is List ? data : []));
    // Actually _send returns Map, so we handle both
    final rawList = data['items'] as List<dynamic>? ??
        data['results'] as List<dynamic>? ??
        (data is List ? data as List<dynamic> : <dynamic>[]);
    // Fallback: if data itself is list wrapper handled earlier
    // For shop, API returns List directly (via _sendRaw logic)
    // Let's try to handle generic
    if (data is Map && data.containsKey('items')) {
      return (data['items'] as List<dynamic>).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    }
    // If _send returned {'items': [...]} we already have
    // If API returns raw list, our _send wraps it as {'items': list}
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
  }) async {
    final data = await _send('POST', '/shop/products', draft.toJson(), token: accessToken);
    return Product.fromJson(data);
  }

  @override
  Future<OrderResult> createOrder({
    required String accessToken,
    required List<OrderItemDraft> items,
    required String idempotencyKey,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final uri = Uri.parse('$baseUrl/shop/orders');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.headers.set('Idempotency-Key', idempotencyKey);
      request.add(utf8.encode(jsonEncode({
        'items': items.map((e) => e.toJson()).toList(),
      })));
      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join();
      final data = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = data is Map<String, dynamic> ? data['detail'] as String? : null;
        throw ApiException(response.statusCode, detail ?? 'خطا در ثبت سفارش');
      }
      return OrderResult.fromJson(data as Map<String, dynamic>);
    } on SocketException {
      throw const ApiException(0, 'به اینترنت دسترسی نیست');
    } finally {
      client.close();
    }
  }

  List<Map<String, dynamic>> _listFromJson(Map<String, dynamic> data) {
    // این متد فقط برای سازگاری با endpointهایی است که ممکن است لیست خام یا wrapper بدهند.
    final raw = data['results'] as List<dynamic>? ?? data['items'] as List<dynamic>?;
    if (raw == null) return const [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _send(
        'POST', '/auth/logout', <String, dynamic>{'refresh_token': refreshToken});
  }
}

/// حالت بدون سرور/کلید — همه‌چیز محلی و آفلاین (اصل Mock بدون کلید).
class OfflineRemoteApi implements RemoteApi {
  const OfflineRemoteApi();

  @override
  bool get enabled => false;

  Never _offline() => throw const ApiException(0, 'اینترنت در دسترس نیست');

  @override
  Future<OtpRequestResult> requestOtp(String phone) async => _offline();

  @override
  Future<UserAccount> verifyOtp({
    required String phone,
    required String code,
    String? name,
    AccountRole? role,
  }) async =>
      _offline();

  @override
  Future<UserAccount> login({
    required String phone,
    required String password,
  }) async =>
      _offline();

  @override
  Future<SyncState> push({
    required String accessToken,
    required List<SyncEntry> entries,
    SyncProfile? profile,
  }) async =>
      _offline();

  @override
  Future<SyncState> pull({required String accessToken, String? since}) async =>
      _offline();

  @override
  Future<SyncState> claim({
    required String accessToken,
    required List<SyncEntry> entries,
    required int totalPoints,
    required String tone,
    required String activeProgramId,
  }) async =>
      _offline();

  @override
  Future<List<SearchResult>> search({
    required String query,
    SearchCategory? category,
    int limit = 20,
  }) async =>
      const [];

  @override
  Future<List<Venue>> listVenues({
    VenueCategory? category,
    String? query,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<Venue> createVenue({
    required String accessToken,
    required VenueDraft draft,
  }) async =>
      _offline();

  @override
  Future<List<Product>> listProducts({
    String? category,
    String? brand,
    String? query,
    int? minPrice,
    int? maxPrice,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
  }) async =>
      _offline();

  @override
  Future<OrderResult> createOrder({
    required String accessToken,
    required List<OrderItemDraft> items,
    required String idempotencyKey,
  }) async =>
      _offline();

  @override
  Future<void> logout(String refreshToken) async {}
}
