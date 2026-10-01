// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer_eval_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs all eval questions through the full answering pipeline and exports
/// answers, citations and timings as JSON (task 4.1).
///
/// Kept alive: a run takes about half an hour, and leaving the screen
/// shouldn't stop it.

@ProviderFor(AnswerEvalController)
final answerEvalControllerProvider = AnswerEvalControllerProvider._();

/// Runs all eval questions through the full answering pipeline and exports
/// answers, citations and timings as JSON (task 4.1).
///
/// Kept alive: a run takes about half an hour, and leaving the screen
/// shouldn't stop it.
final class AnswerEvalControllerProvider
    extends $NotifierProvider<AnswerEvalController, AnswerEvalState> {
  /// Runs all eval questions through the full answering pipeline and exports
  /// answers, citations and timings as JSON (task 4.1).
  ///
  /// Kept alive: a run takes about half an hour, and leaving the screen
  /// shouldn't stop it.
  AnswerEvalControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'answerEvalControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$answerEvalControllerHash();

  @$internal
  @override
  AnswerEvalController create() => AnswerEvalController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnswerEvalState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnswerEvalState>(value),
    );
  }
}

String _$answerEvalControllerHash() =>
    r'0bfee518980f34bb5e04b5ca4235f2c9f847c47c';

/// Runs all eval questions through the full answering pipeline and exports
/// answers, citations and timings as JSON (task 4.1).
///
/// Kept alive: a run takes about half an hour, and leaving the screen
/// shouldn't stop it.

abstract class _$AnswerEvalController extends $Notifier<AnswerEvalState> {
  AnswerEvalState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AnswerEvalState, AnswerEvalState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AnswerEvalState, AnswerEvalState>,
              AnswerEvalState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
