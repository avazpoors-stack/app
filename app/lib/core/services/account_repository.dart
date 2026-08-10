import 'dart:convert';

import '../models/models.dart';
import 'storage.dart';

/// مخزن محلی حساب و سینک — همهٔ داده‌ها در KeyValueStore (فایل در دستگاه،
/// حافظه در تست). هیچ داده‌ای به‌جز اینجا و ProgressRepository ذخیره نمی‌شود.
class AccountRepository {
  AccountRepository(this._store);

  final KeyValueStore _store;

  static const _accountKey = 'badane_account.json';
  static const _queueKey = 'badane_sync_queue.json';
  static const _stateKey = 'badane_sync_state.json';
  static const _uidKey = 'badane_client_uid.json';
  static const _themeKey = 'badane_theme.json';

  // ---------- شناسهٔ دستگاه (برای سینک) ----------
  Future<String> clientUid() async {
    final existing = await _store.read(_uidKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final uid =
        'c${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecond}';
    await _store.write(_uidKey, uid);
    return uid;
  }

  // ---------- حساب ----------
  Future<UserAccount?> loadAccount() async {
    final raw = await _store.read(_accountKey);
    if (raw == null) return null;
    try {
      return UserAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // دادهٔ خراب → مثل مهمان
    }
  }

  Future<void> saveAccount(UserAccount account) async {
    await _store.write(_accountKey, jsonEncode(account.toJson()));
  }

  Future<void> clearAccount() async {
    await _store.remove(_accountKey);
  }

  // ---------- صف سینک (آفلاین-اول) ----------
  Future<List<SyncEntry>> loadQueue() async {
    final raw = await _store.read(_queueKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => SyncEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQueue(List<SyncEntry> queue) async {
    await _store.write(_queueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
  }

  // ---------- آخرین وضعیت سینک ----------
  Future<SyncState?> loadSyncState() async {
    final raw = await _store.read(_stateKey);
    if (raw == null) return null;
    try {
      return SyncState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSyncState(SyncState state) async {
    await _store.write(_stateKey, jsonEncode(state.toJson()));
  }

  // ---------- تم (دارک/لایت/سیستم) ----------
  Future<String> loadThemeName() async {
    final raw = await _store.read(_themeKey);
    if (raw == null || raw.isEmpty) return 'system';
    final valid = {'system', 'light', 'dark'};
    return valid.contains(raw) ? raw : 'system';
  }

  Future<void> saveThemeName(String name) async {
    await _store.write(_themeKey, name);
  }

  /// پاک‌کردن همهٔ دادهٔ حساب و صف (خروج از حساب)
  Future<void> clearAll() async {
    await clearAccount();
    await _store.remove(_queueKey);
    await _store.remove(_stateKey);
  }
}
