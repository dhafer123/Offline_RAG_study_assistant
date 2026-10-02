import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/app/router.dart';
import 'package:offline_study_assistant/app/theme.dart';
import 'package:offline_study_assistant/core/settings/app_settings.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Study Assistant',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (ref.watch(themeModeSettingProvider)) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
