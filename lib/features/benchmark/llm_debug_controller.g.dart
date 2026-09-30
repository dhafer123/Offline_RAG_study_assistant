// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_debug_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the model and streams an answer to a fixed prompt (task 1.3).

@ProviderFor(LlmDebugController)
final llmDebugControllerProvider = LlmDebugControllerProvider._();

/// Loads the model and streams an answer to a fixed prompt (task 1.3).
final class LlmDebugControllerProvider
    extends $NotifierProvider<LlmDebugController, LlmDebugState> {
  /// Loads the model and streams an answer to a fixed prompt (task 1.3).
  LlmDebugControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmDebugControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmDebugControllerHash();

  @$internal
  @override
  LlmDebugController create() => LlmDebugController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmDebugState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmDebugState>(value),
    );
  }
}

String _$llmDebugControllerHash() =>
    r'e3ededb2633f9c55eac4546d218d02cf55bfafef';

/// Loads the model and streams an answer to a fixed prompt (task 1.3).

abstract class _$LlmDebugController extends $Notifier<LlmDebugState> {
  LlmDebugState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LlmDebugState, LlmDebugState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LlmDebugState, LlmDebugState>,
              LlmDebugState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
