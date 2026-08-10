import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_shell.dart';
import 'core/services/app_services.dart';
import 'core/services/content_repository.dart';
import 'core/services/progress_repository.dart';
import 'core/services/storage.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.createDefault();
  runApp(BadaneApp(services: services));
}

class BadaneApp extends StatelessWidget {
  const BadaneApp({super.key, this.services});

  /// اگر null باشد (مثلاً در تست‌ها)، سرویس‌های حافظه‌ای ساخته می‌شوند.
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    final effective = services ??
        AppServices(
          content: ContentRepository(),
          progress: ProgressRepository(InMemoryStore()),
          clock: Clock(),
        );
    return BadaneScope(
      services: effective,
      child: MaterialApp(
        title: 'بدنه',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppShell(),
      ),
    );
  }
}
