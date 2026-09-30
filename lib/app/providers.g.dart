// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(llmModelConfig)
final llmModelConfigProvider = LlmModelConfigProvider._();

final class LlmModelConfigProvider
    extends $FunctionalProvider<LlmModelConfig, LlmModelConfig, LlmModelConfig>
    with $Provider<LlmModelConfig> {
  LlmModelConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmModelConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmModelConfigHash();

  @$internal
  @override
  $ProviderElement<LlmModelConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LlmModelConfig create(Ref ref) {
    return llmModelConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmModelConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmModelConfig>(value),
    );
  }
}

String _$llmModelConfigHash() => r'2f38b3debbe150afdf8c249446c4fdfdd12ff0b0';

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

String _$llmEngineHash() => r'3ae55d81ffdcce7e15b978fd7f9c19e89dd66bce';
