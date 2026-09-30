// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$activeLlmModelHash() => r'ac19a68c733f5c449b103a79583767becf1e0df8';

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

String _$llmEngineHash() => r'c5346c75d0faef83c4beb1f65b47ad173b1bf44f';
