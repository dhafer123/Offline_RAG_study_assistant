import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/app/branding.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/app/router.dart';
import 'package:offline_study_assistant/app/theme.dart';
import 'package:offline_study_assistant/app/widgets/splash_overlay.dart';
import 'package:offline_study_assistant/core/settings/app_settings.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: Branding.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (ref.watch(themeModeSettingProvider)) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SplashOverlay(child: child!),
      debugShowCheckedModeBanner: false,
    );
  }
}
