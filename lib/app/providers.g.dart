// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Absolute path of the folder holding model files. Set in `main()`.

@ProviderFor(modelsDirectory)
final modelsDirectoryProvider = ModelsDirectoryProvider._();

/// Absolute path of the folder holding model files. Set in `main()`.

final class ModelsDirectoryProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Absolute path of the folder holding model files. Set in `main()`.
  ModelsDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelsDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelsDirectoryHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return modelsDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$modelsDirectoryHash() => r'4aeea588a570bcdd81a14037c2f38dfe45056483';

/// Loaded in `main()` so reads are synchronous.

@ProviderFor(appSettings)
final appSettingsProvider = AppSettingsProvider._();

/// Loaded in `main()` so reads are synchronous.

final class AppSettingsProvider
    extends $FunctionalProvider<AppSettings, AppSettings, AppSettings>
    with $Provider<AppSettings> {
  /// Loaded in `main()` so reads are synchronous.
  AppSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  $ProviderElement<AppSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettings create(Ref ref) {
    return appSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$appSettingsHash() => r'a6d9a422629b06c1e307b210f8079d5616fde884';

@ProviderFor(networkMonitor)
final networkMonitorProvider = NetworkMonitorProvider._();

final class NetworkMonitorProvider
    extends $FunctionalProvider<NetworkMonitor, NetworkMonitor, NetworkMonitor>
    with $Provider<NetworkMonitor> {
  NetworkMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkMonitorHash();

  @$internal
  @override
  $ProviderElement<NetworkMonitor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkMonitor create(Ref ref) {
    return networkMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkMonitor>(value),
    );
  }
}

String _$networkMonitorHash() => r'47c64daf83493f5cd050aebcf45501f974e719ac';

@ProviderFor(WifiOnlyDownloads)
final wifiOnlyDownloadsProvider = WifiOnlyDownloadsProvider._();

final class WifiOnlyDownloadsProvider
    extends $NotifierProvider<WifiOnlyDownloads, bool> {
  WifiOnlyDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wifiOnlyDownloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wifiOnlyDownloadsHash();

  @$internal
  @override
  WifiOnlyDownloads create() => WifiOnlyDownloads();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$wifiOnlyDownloadsHash() => r'1bba1ec77e34ba14bfb337e02738bf5a8eca63c9';

abstract class _$WifiOnlyDownloads extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Downloads the app's model; checks the file on disk as soon as it's created.

@ProviderFor(modelManager)
final modelManagerProvider = ModelManagerProvider._();

/// Downloads the app's model; checks the file on disk as soon as it's created.

final class ModelManagerProvider
    extends $FunctionalProvider<ModelManager, ModelManager, ModelManager>
    with $Provider<ModelManager> {
  /// Downloads the app's model; checks the file on disk as soon as it's created.
  ModelManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelManagerHash();

  @$internal
  @override
  $ProviderElement<ModelManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelManager create(Ref ref) {
    return modelManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelManager>(value),
    );
  }
}

String _$modelManagerHash() => r'da3e9ead79564ace94cd81fdc5fe47c9e7f7c472';

/// The model's current [ModelState], rebuilt on every change.

@ProviderFor(CurrentModelState)
final currentModelStateProvider = CurrentModelStateProvider._();

/// The model's current [ModelState], rebuilt on every change.
final class CurrentModelStateProvider
    extends $NotifierProvider<CurrentModelState, ModelState> {
  /// The model's current [ModelState], rebuilt on every change.
  CurrentModelStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentModelStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentModelStateHash();

  @$internal
  @override
  CurrentModelState create() => CurrentModelState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelState>(value),
    );
  }
}

String _$currentModelStateHash() => r'7713ef9f3fc7576efb88d43c7462b5df58e9e11f';

/// The model's current [ModelState], rebuilt on every change.

abstract class _$CurrentModelState extends $Notifier<ModelState> {
  ModelState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ModelState, ModelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ModelState, ModelState>,
              ModelState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The model the app runs. Changing it replaces (and unloads) the engine.

@ProviderFor(ActiveLlmModel)
final activeLlmModelProvider = ActiveLlmModelProvider._();

/// The model the app runs. Changing it replaces (and unloads) the engine.
final class ActiveLlmModelProvider
    extends $NotifierProvider<ActiveLlmModel, LlmModelConfig> {
  /// The model the app runs. Changing it replaces (and unloads) the engine.
  ActiveLlmModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeLlmModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeLlmModelHash();

  @$internal
  @override
  ActiveLlmModel create() => ActiveLlmModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmModelConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmModelConfig>(value),
    );
  }
}

String _$activeLlmModelHash() => r'ecd027de9653f950e54481d436480c709c41949d';

/// The model the app runs. Changing it replaces (and unloads) the engine.

abstract class _$ActiveLlmModel extends $Notifier<LlmModelConfig> {
  LlmModelConfig build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LlmModelConfig, LlmModelConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LlmModelConfig, LlmModelConfig>,
              LlmModelConfig,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(llmEngine)
final llmEngineProvider = LlmEngineProvider._();

final class LlmEngineProvider
    extends $FunctionalProvider<LlmEngine, LlmEngine, LlmEngine>
    with $Provider<LlmEngine> {
  LlmEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmEngineHash();

  @$internal
  @override
  $ProviderElement<LlmEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LlmEngine create(Ref ref) {
    return llmEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmEngine>(value),
    );
  }
}

String _$llmEngineHash() => r'ea69d6f3d87f94d5892814a2d997e67a5c84daef';
