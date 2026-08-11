import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_shell.dart';
import 'core/services/app_services.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.createDefault();
  await services.loadTheme();
  runApp(BadaneApp(services: services));
}

class BadaneApp extends StatefulWidget {
  const BadaneApp({super.key, this.services});

  /// اگر null باشد (مثلاً در تست‌ها)، سرویس‌های حافظه‌ای ساخته می‌شوند.
  final AppServices? services;

  /// سرویس‌های حافظه‌ای — وقتی سرویسی داده نشود (تست‌ها).
  /// همان مسیر ساختِ `AppServices` (حافظه + API آفلاین) تا دو نسخهٔ موازی نداشته باشیم.
  @visibleForTesting
  static AppServices fallbackServices() {
    try {
      return AppServices.forTesting();
    } catch (e) {
      throw FlutterError(
        'ساخت سرویس‌های جایگزین شکست خورد: $e\n'
        'معمولاً یعنی مقداردهی اولیهٔ یکی از وابستگی‌های موردنیاز خطا داده است.',
      );
    }
  }

  @override
  State<BadaneApp> createState() => _BadaneAppState();
}

class _BadaneAppState extends State<BadaneApp> {
  /// سرویس‌های ساخته‌شده توسط خود ویجت (فقط وقتی از بیرون داده نشده باشد).
  /// یک‌بار ساخته می‌شود تا با هر build دوباره ساخته نشود (نشتی state).
  AppServices? _owned;

  AppServices get _effective =>
      widget.services ?? (_owned ??= BadaneApp.fallbackServices());

  @override
  void didUpdateWidget(covariant BadaneApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // اگر سرویس از بیرون داده شد، نسخهٔ داخلی دیگر لازم نیست.
    if (widget.services != null && _owned != null) {
      _owned!.dispose();
      _owned = null;
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _effective;
    return BadaneScope(
      services: services,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: services.themeMode,
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
}
