import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_shell.dart';
import 'core/services/account_repository.dart';
import 'core/services/app_services.dart';
import 'core/services/auth_service.dart';
import 'core/services/content_repository.dart';
import 'core/services/progress_repository.dart';
import 'core/services/remote_api.dart';
import 'core/services/search_service.dart';
import 'core/services/storage.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.createDefault();
  await services.loadTheme();
  runApp(BadaneApp(services: services));
}

class BadaneApp extends StatelessWidget {
  const BadaneApp({super.key, this.services});

  /// اگر null باشد (مثلاً در تست‌ها)، سرویس‌های حافظه‌ای ساخته می‌شوند.
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    final effective = services ??
        _fallbackServices();
    return BadaneScope(
      services: effective,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: effective.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'بدنه',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppShell(),
        ),
      ),
    );
  }

  /// سرویس‌های حافظه‌ای — وقتی سرویسی داده نشود (تست‌ها).
  static AppServices _fallbackServices() {
    final store = InMemoryStore();
    final progress = ProgressRepository(store);
    final account = AccountRepository(store);
    const api = OfflineRemoteApi();
    final content = ContentRepository();
    return AppServices(
      content: content,
      progress: progress,
      account: account,
      auth: AuthService(repository: account, api: api),
      sync: SyncService(
        repository: account,
        api: api,
        progress: progress,
        clock: Clock(),
      ),
      search: SearchService(content: content, store: store, api: api),
      clock: Clock(),
    );
  }
}
