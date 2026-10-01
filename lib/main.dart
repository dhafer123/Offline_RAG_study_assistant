import 'dart:io';

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
  // Android only: /sdcard/Android/data/<package>/files.
  final externalDir = Platform.isAndroid
      ? await getExternalStorageDirectory()
      : null;

  runApp(
    ProviderScope(
      overrides: [
        // On Android: /data/user/0/<package>/files/models.
        modelsDirectoryProvider.overrideWithValue('${supportDir.path}/models'),
        databasePathProvider.overrideWithValue('${supportDir.path}/study.db'),
        pdfsDirectoryProvider.overrideWithValue('${supportDir.path}/pdfs'),
        exportDirectoryProvider.overrideWithValue(
          '${(externalDir ?? supportDir).path}/eval_results',
        ),
        appSettingsProvider.overrideWithValue(settings),
      ],
      child: const App(),
    ),
  );
}
