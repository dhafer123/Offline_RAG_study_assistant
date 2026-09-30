// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_benchmark_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs [LlmBenchmark] from the benchmark screen (task 1.4).

@ProviderFor(LlmBenchmarkController)
final llmBenchmarkControllerProvider = LlmBenchmarkControllerProvider._();

/// Runs [LlmBenchmark] from the benchmark screen (task 1.4).
final class LlmBenchmarkControllerProvider
    extends $NotifierProvider<LlmBenchmarkController, LlmBenchmarkState> {
  /// Runs [LlmBenchmark] from the benchmark screen (task 1.4).
  LlmBenchmarkControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmBenchmarkControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmBenchmarkControllerHash();

  @$internal
  @override
  LlmBenchmarkController create() => LlmBenchmarkController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmBenchmarkState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmBenchmarkState>(value),
    );
  }
}

String _$llmBenchmarkControllerHash() =>
    r'c276f62db1d57f46bc1584d45ab1f2cfd188dde8';

/// Runs [LlmBenchmark] from the benchmark screen (task 1.4).

abstract class _$LlmBenchmarkController extends $Notifier<LlmBenchmarkState> {
  LlmBenchmarkState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LlmBenchmarkState, LlmBenchmarkState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LlmBenchmarkState, LlmBenchmarkState>,
              LlmBenchmarkState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
