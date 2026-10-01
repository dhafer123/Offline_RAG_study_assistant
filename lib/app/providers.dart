import 'dart:async';

import 'package:offline_study_assistant/core/ai/file_model_manager.dart';
import 'package:offline_study_assistant/core/ai/gemma_llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';
import 'package:offline_study_assistant/core/ai/model_downloader.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/core/ai/model_spec.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/net/network_monitor.dart';
import 'package:offline_study_assistant/core/settings/app_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// Absolute path of the folder holding model files. Set in `main()`.
@Riverpod(keepAlive: true)
String modelsDirectory(Ref ref) =>
    throw UnimplementedError('Override modelsDirectoryProvider in main()');

/// Absolute path of the SQLite database file. Set in `main()`.
@Riverpod(keepAlive: true)
String databasePath(Ref ref) =>
    throw UnimplementedError('Override databasePathProvider in main()');

/// Documents, chunks and the full-text index. Opened lazily on first query.
@Riverpod(keepAlive: true)
DocumentStore documentStore(Ref ref) {
  final db = AppDatabase.open(ref.watch(databasePathProvider));
  ref.onDispose(db.close);
  return db;
}

/// Loaded in `main()` so reads are synchronous.
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) =>
    throw UnimplementedError('Override appSettingsProvider in main()');

@Riverpod(keepAlive: true)
NetworkMonitor networkMonitor(Ref ref) => ConnectivityNetworkMonitor();

@Riverpod(keepAlive: true)
class WifiOnlyDownloads extends _$WifiOnlyDownloads {
  @override
  bool build() => ref.watch(appSettingsProvider).wifiOnlyDownloads;

  Future<void> set({required bool value}) async {
    state = value;
    await ref.read(appSettingsProvider).setWifiOnlyDownloads(value: value);
  }
}

/// Downloads the app's model; checks the file on disk as soon as it's created.
@Riverpod(keepAlive: true)
ModelManager modelManager(Ref ref) {
  final manager = FileModelManager(
    spec: ModelSpec.gemma3,
    directory: ref.watch(modelsDirectoryProvider),
    downloader: HttpModelDownloader(),
    network: ref.watch(networkMonitorProvider),
    wifiOnly: () => ref.read(wifiOnlyDownloadsProvider),
  );
  ref.onDispose(manager.dispose);
  unawaited(manager.refresh());
  return manager;
}

/// The model's current [ModelState], rebuilt on every change.
@Riverpod(keepAlive: true)
class CurrentModelState extends _$CurrentModelState {
  @override
  ModelState build() {
    final manager = ref.watch(modelManagerProvider);
    final changes = manager.states.listen((s) => state = s);
    ref.onDispose(changes.cancel);
    return manager.state;
  }
}

/// The model the app runs. Changing it replaces (and unloads) the engine.
@Riverpod(keepAlive: true)
class ActiveLlmModel extends _$ActiveLlmModel {
  @override
  LlmModelConfig build() => LlmModelConfig.gemma3;

  void select(LlmModelConfig config) {
    // Same model: keep the loaded engine.
    if (config.fileName == state.fileName) return;
    state = config;
  }
}

@Riverpod(keepAlive: true)
LlmEngine llmEngine(Ref ref) {
  final config = ref.watch(activeLlmModelProvider);
  final engine = GemmaLlmEngine(
    config,
    modelPath: '${ref.watch(modelsDirectoryProvider)}/${config.fileName}',
  );
  ref.onDispose(engine.unload);
  return engine;
}
