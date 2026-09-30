import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/app/app.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/settings/app_settings.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (supportDir, settings) = await (
    getApplicationSupportDirectory(),
    SharedPrefsAppSettings.load(),
  ).wait;

  runApp(
    ProviderScope(
      overrides: [
        // On Android: /data/user/0/<package>/files/models.
        modelsDirectoryProvider.overrideWithValue('${supportDir.path}/models'),
        appSettingsProvider.overrideWithValue(settings),
      ],
      child: const App(),
    ),
  );
}
