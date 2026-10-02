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

/// Absolute path of the SQLite database file. Set in `main()`.

@ProviderFor(databasePath)
final databasePathProvider = DatabasePathProvider._();

/// Absolute path of the SQLite database file. Set in `main()`.

final class DatabasePathProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Absolute path of the SQLite database file. Set in `main()`.
  DatabasePathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databasePathProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databasePathHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return databasePath(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$databasePathHash() => r'1de6cd32a5776631efc7fdca011775575cd96c33';

/// Absolute path of the folder holding the user's PDFs. Set in `main()`.

@ProviderFor(pdfsDirectory)
final pdfsDirectoryProvider = PdfsDirectoryProvider._();

/// Absolute path of the folder holding the user's PDFs. Set in `main()`.

final class PdfsDirectoryProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Absolute path of the folder holding the user's PDFs. Set in `main()`.
  PdfsDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfsDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfsDirectoryHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return pdfsDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$pdfsDirectoryHash() => r'784a5d74feb55501d830997db19545be0a2e9d44';

/// Where benchmark results are written. Set in `main()`: on Android, the
/// app's external files folder, which `adb pull` can read without `run-as`
/// (release builds aren't debuggable).

@ProviderFor(exportDirectory)
final exportDirectoryProvider = ExportDirectoryProvider._();

/// Where benchmark results are written. Set in `main()`: on Android, the
/// app's external files folder, which `adb pull` can read without `run-as`
/// (release builds aren't debuggable).

final class ExportDirectoryProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Where benchmark results are written. Set in `main()`: on Android, the
  /// app's external files folder, which `adb pull` can read without `run-as`
  /// (release builds aren't debuggable).
  ExportDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportDirectoryHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return exportDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$exportDirectoryHash() => r'45554c9ca07cc88061471893487a93e9aa0b7b0d';

/// The SQLite database. Opened lazily on first query.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The SQLite database. Opened lazily on first query.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The SQLite database. Opened lazily on first query.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'265ab7dac9666e52b0f3603fb596a227a7322103';

/// Documents, chunks and the full-text index.

@ProviderFor(documentStore)
final documentStoreProvider = DocumentStoreProvider._();

/// Documents, chunks and the full-text index.

final class DocumentStoreProvider
    extends $FunctionalProvider<DocumentStore, DocumentStore, DocumentStore>
    with $Provider<DocumentStore> {
  /// Documents, chunks and the full-text index.
  DocumentStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentStoreHash();

  @$internal
  @override
  $ProviderElement<DocumentStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DocumentStore create(Ref ref) {
    return documentStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentStore>(value),
    );
  }
}

String _$documentStoreHash() => r'69013fb9ba250c450dd8061bca7800e1687a6fc9';

/// Chunk embeddings, stored in the same database.

@ProviderFor(vectorIndex)
final vectorIndexProvider = VectorIndexProvider._();

/// Chunk embeddings, stored in the same database.

final class VectorIndexProvider
    extends $FunctionalProvider<VectorIndex, VectorIndex, VectorIndex>
    with $Provider<VectorIndex> {
  /// Chunk embeddings, stored in the same database.
  VectorIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vectorIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vectorIndexHash();

  @$internal
  @override
  $ProviderElement<VectorIndex> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VectorIndex create(Ref ref) {
    return vectorIndex(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VectorIndex value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VectorIndex>(value),
    );
  }
}

String _$vectorIndexHash() => r'cfac6cbd347d4c4fc407f262158c5e0a7318495b';

@ProviderFor(embedder)
final embedderProvider = EmbedderProvider._();

final class EmbedderProvider
    extends $FunctionalProvider<Embedder, Embedder, Embedder>
    with $Provider<Embedder> {
  EmbedderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'embedderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$embedderHash();

  @$internal
  @override
  $ProviderElement<Embedder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Embedder create(Ref ref) {
    return embedder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Embedder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Embedder>(value),
    );
  }
}

String _$embedderHash() => r'5a1d7b75217e5fb2a5deb85522cba5124f2fba15';

@ProviderFor(pdfTextExtractor)
final pdfTextExtractorProvider = PdfTextExtractorProvider._();

final class PdfTextExtractorProvider
    extends
        $FunctionalProvider<
          PdfTextExtractor,
          PdfTextExtractor,
          PdfTextExtractor
        >
    with $Provider<PdfTextExtractor> {
  PdfTextExtractorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfTextExtractorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfTextExtractorHash();

  @$internal
  @override
  $ProviderElement<PdfTextExtractor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PdfTextExtractor create(Ref ref) {
    return pdfTextExtractor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PdfTextExtractor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PdfTextExtractor>(value),
    );
  }
}

String _$pdfTextExtractorHash() => r'49f038bdbf331a5957f3ab4c3bbafc7da59135a0';

/// Frame timings while a document indexes (is the UI still smooth?).

@ProviderFor(frameMonitor)
final frameMonitorProvider = FrameMonitorProvider._();

/// Frame timings while a document indexes (is the UI still smooth?).

final class FrameMonitorProvider
    extends $FunctionalProvider<FrameMonitor, FrameMonitor, FrameMonitor>
    with $Provider<FrameMonitor> {
  /// Frame timings while a document indexes (is the UI still smooth?).
  FrameMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'frameMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$frameMonitorHash();

  @$internal
  @override
  $ProviderElement<FrameMonitor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FrameMonitor create(Ref ref) {
    return frameMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FrameMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FrameMonitor>(value),
    );
  }
}

String _$frameMonitorHash() => r'982e9153098adb5c38cc37b0d2f2188255499974';

@ProviderFor(pdfPicker)
final pdfPickerProvider = PdfPickerProvider._();

final class PdfPickerProvider
    extends $FunctionalProvider<PdfPicker, PdfPicker, PdfPicker>
    with $Provider<PdfPicker> {
  PdfPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfPickerHash();

  @$internal
  @override
  $ProviderElement<PdfPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PdfPicker create(Ref ref) {
    return pdfPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PdfPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PdfPicker>(value),
    );
  }
}

String _$pdfPickerHash() => r'cdca0e0ee7b5f19cec8c72a5b087772f06afc562';

/// The app's copies of imported PDFs.

@ProviderFor(pdfFiles)
final pdfFilesProvider = PdfFilesProvider._();

/// The app's copies of imported PDFs.

final class PdfFilesProvider
    extends $FunctionalProvider<PdfFiles, PdfFiles, PdfFiles>
    with $Provider<PdfFiles> {
  /// The app's copies of imported PDFs.
  PdfFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfFilesHash();

  @$internal
  @override
  $ProviderElement<PdfFiles> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PdfFiles create(Ref ref) {
    return pdfFiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PdfFiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PdfFiles>(value),
    );
  }
}

String _$pdfFilesHash() => r'5479cceb965fd4810049f70a0e60c49bf917cb51';

@ProviderFor(ingestionService)
final ingestionServiceProvider = IngestionServiceProvider._();

final class IngestionServiceProvider
    extends
        $FunctionalProvider<
          IngestionService,
          IngestionService,
          IngestionService
        >
    with $Provider<IngestionService> {
  IngestionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ingestionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ingestionServiceHash();

  @$internal
  @override
  $ProviderElement<IngestionService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IngestionService create(Ref ref) {
    return ingestionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IngestionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IngestionService>(value),
    );
  }
}

String _$ingestionServiceHash() => r'71e791a48f6a6fab926cddb5242c7f18fc05f853';

@ProviderFor(retrievalService)
final retrievalServiceProvider = RetrievalServiceProvider._();

final class RetrievalServiceProvider
    extends
        $FunctionalProvider<
          RetrievalService,
          RetrievalService,
          RetrievalService
        >
    with $Provider<RetrievalService> {
  RetrievalServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retrievalServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retrievalServiceHash();

  @$internal
  @override
  $ProviderElement<RetrievalService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RetrievalService create(Ref ref) {
    return retrievalService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetrievalService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetrievalService>(value),
    );
  }
}

String _$retrievalServiceHash() => r'703a3d8823e49f53ae67dda0327021214949df7f';

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

/// Light, dark, or following the phone.

@ProviderFor(ThemeModeSetting)
final themeModeSettingProvider = ThemeModeSettingProvider._();

/// Light, dark, or following the phone.
final class ThemeModeSettingProvider
    extends $NotifierProvider<ThemeModeSetting, AppThemeMode> {
  /// Light, dark, or following the phone.
  ThemeModeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeSettingHash();

  @$internal
  @override
  ThemeModeSetting create() => ThemeModeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeModeSettingHash() => r'99837b6c31983a19bc2a6c64911a07e0135d9f1c';

/// Light, dark, or following the phone.

abstract class _$ThemeModeSetting extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Downloads the app's models (LLM + embedder) as one bundle; checks the
/// files on disk as soon as it's created.

@ProviderFor(modelManager)
final modelManagerProvider = ModelManagerProvider._();

/// Downloads the app's models (LLM + embedder) as one bundle; checks the
/// files on disk as soon as it's created.

final class ModelManagerProvider
    extends $FunctionalProvider<ModelManager, ModelManager, ModelManager>
    with $Provider<ModelManager> {
  /// Downloads the app's models (LLM + embedder) as one bundle; checks the
  /// files on disk as soon as it's created.
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

String _$modelManagerHash() => r'fbbad849ef5694f85c0a1cd74affa13bea7e2556';

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

/// Gate threshold, top k and prompt budget. Tests and the threshold tuning
/// (task 3.7) override it.

@ProviderFor(answerConfig)
final answerConfigProvider = AnswerConfigProvider._();

/// Gate threshold, top k and prompt budget. Tests and the threshold tuning
/// (task 3.7) override it.

final class AnswerConfigProvider
    extends $FunctionalProvider<AnswerConfig, AnswerConfig, AnswerConfig>
    with $Provider<AnswerConfig> {
  /// Gate threshold, top k and prompt budget. Tests and the threshold tuning
  /// (task 3.7) override it.
  AnswerConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'answerConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$answerConfigHash();

  @$internal
  @override
  $ProviderElement<AnswerConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnswerConfig create(Ref ref) {
    return answerConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnswerConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnswerConfig>(value),
    );
  }
}

String _$answerConfigHash() => r'8eda979bb06cff7492878dc9713085a5bcd4ba1d';

@ProviderFor(answerService)
final answerServiceProvider = AnswerServiceProvider._();

final class AnswerServiceProvider
    extends $FunctionalProvider<AnswerService, AnswerService, AnswerService>
    with $Provider<AnswerService> {
  AnswerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'answerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$answerServiceHash();

  @$internal
  @override
  $ProviderElement<AnswerService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnswerService create(Ref ref) {
    return answerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnswerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnswerService>(value),
    );
  }
}

String _$answerServiceHash() => r'f860c7c2f6adceca51dc538d0e14620343cd62b9';
