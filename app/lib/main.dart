import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const BadaneApp());
}

class BadaneApp extends StatelessWidget {
  const BadaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
