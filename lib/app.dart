import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n.dart';
import 'core/theme/app_theme.dart';
import 'data/models/settings.dart';
import 'state/app_controller.dart';
import 'state/scope.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell/home_shell.dart';
import 'ui/splash/splash_screen.dart';

class SharrowApp extends StatefulWidget {
  const SharrowApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<SharrowApp> createState() => _SharrowAppState();
}

class _SharrowAppState extends State<SharrowApp> {
  static const _minSplash = Duration(milliseconds: 1400);
  bool _splashDone = false;
  Timer? _timer;

  AppController get app => widget.controller;

  @override
  void initState() {
    super.initState();
    final quick = app.args.autostart || app.args.minimized;
    _timer = Timer(quick ? Duration.zero : _minSplash, () => setState(() => _splashDone = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ThemeMode _mode(String v) => switch (v) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        // 'dark' and 'black' share ThemeMode.dark; 'black' swaps the dark palette.
        _ => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    return AppScope(
      app: app,
      child: ListenableBuilder(
        listenable: Listenable.merge([app, app.settings]),
        builder: (context, _) {
          final ready = app.ready;
          final accent = Color(ready ? app.settings.get(K.accent) : K.accent.def);
          final mode = ready ? app.settings.get(K.themeMode) : K.themeMode.def;
          final scale = ready ? app.settings.get(K.textScale) : 1.0;
          final font = AppTheme.fonts[ready ? app.settings.get(K.font) : K.font.def] ?? 'Inter';
          final Widget home;
          if (!ready || !_splashDone) {
            home = const SplashScreen(key: ValueKey('splash'));
          } else if (app.needsOnboarding) {
            home = const OnboardingScreen(key: ValueKey('onboarding'));
          } else {
            home = HomeShell(key: ValueKey('home/${L10n.lang}'));
          }
          return MaterialApp(
            title: 'Sharrow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.light, accent, font: font),
            darkTheme: AppTheme.build(Brightness.dark, accent, amoled: mode == 'black', font: font),
            themeMode: _mode(mode),
            themeAnimationDuration: const Duration(milliseconds: 220),
            locale: Locale(L10n.lang),
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: Material(color: Theme.of(context).scaffoldBackgroundColor, child: child!),
            ),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: home,
            ),
          );
        },
      ),
    );
  }
}
