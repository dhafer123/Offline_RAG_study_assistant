// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_sweep_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Measures time to first token against prompt size on the device, using
/// the indexed chunks as source text.

@ProviderFor(PromptSweepController)
final promptSweepControllerProvider = PromptSweepControllerProvider._();

/// Measures time to first token against prompt size on the device, using
/// the indexed chunks as source text.
final class PromptSweepControllerProvider
    extends $NotifierProvider<PromptSweepController, PromptSweepState> {
  /// Measures time to first token against prompt size on the device, using
  /// the indexed chunks as source text.
  PromptSweepControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promptSweepControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promptSweepControllerHash();

  @$internal
  @override
  PromptSweepController create() => PromptSweepController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PromptSweepState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PromptSweepState>(value),
    );
  }
}

String _$promptSweepControllerHash() =>
    r'cfbbe7b6ab2b8dcc1155df89cda6901c6270426c';

/// Measures time to first token against prompt size on the device, using
/// the indexed chunks as source text.

abstract class _$PromptSweepController extends $Notifier<PromptSweepState> {
  PromptSweepState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PromptSweepState, PromptSweepState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PromptSweepState, PromptSweepState>,
              PromptSweepState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
