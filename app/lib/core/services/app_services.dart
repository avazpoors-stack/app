import 'package:flutter/material.dart';

import '../models/models.dart';
import 'account_repository.dart';
import 'auth_service.dart';
import 'content_repository.dart';
import 'progress_repository.dart';
import 'remote_api.dart';
import 'storage.dart';
import 'sync_service.dart';

/// سرویس‌های برنامه — یکجا و تزریق‌پذیر (تست‌پذیری + جایگزینی Local/Remote).
class AppServices {
  AppServices({
    required this.content,
    required this.progress,
    required this.clock,
    required this.account,
    required this.auth,
    required this.sync,
  });

  final ContentRepository content;
  final ProgressRepository progress;
  final Clock clock;
  final AccountRepository account;
  final AuthService auth;
  final SyncService sync;

  /// تم برنامه — از پروفایل/پایین‌ترین صفحه قابل تغییر (دارک/لایت/سیستم).
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// بارگذاری اولیهٔ محتوا و پیشرفت — همهٔ صفحه‌ها از این استفاده می‌کنند.
  Future<UserProgress> ensureLoaded() async {
    await content.load();
    return progress.load();
  }

  /// تعداد رکوردهای در انتظار همگام‌سازی.
  Future<int> pendingSyncCount() => sync.pendingCount();

  static Future<AppServices> createDefault() async {
    final dir = await StorageChannel.getFilesDir();
    final store = dir != null ? FileStore(dir) : InMemoryStore();
    return _build(store, const String.fromEnvironment('BADANE_API_URL'));
  }

  static AppServices forTesting({
    Map<String, String>? contentOverrides,
    KeyValueStore? store,
    DateTime? now,
    RemoteApi? api,
  }) {
    return _build(
      store ?? InMemoryStore(),
      null,
      contentOverrides: contentOverrides,
      now: now,
      api: api,
    );
  }

  static AppServices _build(
    KeyValueStore store,
    String? baseUrl, {
    Map<String, String>? contentOverrides,
    DateTime? now,
    RemoteApi? api,
  }) {
    final progress = ProgressRepository(store);
    final account = AccountRepository(store);
    final remote = api ??
        (baseUrl != null && baseUrl.isNotEmpty
            ? HttpRemoteApi(baseUrl: baseUrl)
            : const OfflineRemoteApi());
    final services = AppServices(
      content: ContentRepository(overrides: contentOverrides),
      progress: progress,
      account: account,
      auth: AuthService(repository: account, api: remote),
      sync: SyncService(
        repository: account,
        api: remote,
        progress: progress,
        clock: Clock(fixed: now),
      ),
      clock: Clock(fixed: now),
    );
    return services;
  }

  /// بارگذاری تنظیم تم از حافظه (بعد از createDefault).
  Future<void> loadTheme() async {
    themeMode.value = switch (await account.loadThemeName()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    await account.saveThemeName(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }
}

/// دسترسی به سرویس‌ها از هر جای درخت ویجت.
class BadaneScope extends InheritedWidget {
  const BadaneScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BadaneScope>();
    assert(scope != null, 'BadaneScope not found in widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(BadaneScope oldWidget) =>
      services != oldWidget.services;
}
