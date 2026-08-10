import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'content_repository.dart';
import 'progress_repository.dart';
import 'storage.dart';

/// سرویس‌های برنامه — یکجا و تزریق‌پذیر (تست‌پذیری + جایگزینی Local/Remote).
class AppServices {
  AppServices({
    required this.content,
    required this.progress,
    required this.clock,
  });

  final ContentRepository content;
  final ProgressRepository progress;
  final Clock clock;

  /// بارگذاری اولیهٔ محتوا و پیشرفت — همهٔ صفحه‌ها از این استفاده می‌کنند.
  Future<UserProgress> ensureLoaded() async {
    await content.load();
    return progress.load();
  }

  static Future<AppServices> createDefault() async {
    final dir = await StorageChannel.getFilesDir();
    final store = dir != null ? FileStore(dir) : InMemoryStore();
    return AppServices(
      content: ContentRepository(),
      progress: ProgressRepository(store),
      clock: Clock(),
    );
  }

  static AppServices forTesting({
    Map<String, String>? contentOverrides,
    KeyValueStore? store,
    DateTime? now,
  }) {
    return AppServices(
      content: ContentRepository(overrides: contentOverrides),
      progress: ProgressRepository(store ?? InMemoryStore()),
      clock: Clock(fixed: now),
    );
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
