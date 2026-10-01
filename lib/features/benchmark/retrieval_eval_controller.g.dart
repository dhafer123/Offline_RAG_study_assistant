// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retrieval_eval_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the bundled `eval/questions.json`. Tests override it.

@ProviderFor(evalQuestionsSource)
final evalQuestionsSourceProvider = EvalQuestionsSourceProvider._();

/// Loads the bundled `eval/questions.json`. Tests override it.

final class EvalQuestionsSourceProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Loads the bundled `eval/questions.json`. Tests override it.
  EvalQuestionsSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'evalQuestionsSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$evalQuestionsSourceHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return evalQuestionsSource(ref);
  }
}

String _$evalQuestionsSourceHash() =>
    r'a4fb421212699c6eb4c597eaee5254d783f69409';

/// Runs every question of the eval set through retrieval and exports the
/// results as JSON (task 2.8).

@ProviderFor(RetrievalEvalController)
final retrievalEvalControllerProvider = RetrievalEvalControllerProvider._();

/// Runs every question of the eval set through retrieval and exports the
/// results as JSON (task 2.8).
final class RetrievalEvalControllerProvider
    extends $NotifierProvider<RetrievalEvalController, RetrievalEvalState> {
  /// Runs every question of the eval set through retrieval and exports the
  /// results as JSON (task 2.8).
  RetrievalEvalControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retrievalEvalControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retrievalEvalControllerHash();

  @$internal
  @override
  RetrievalEvalController create() => RetrievalEvalController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetrievalEvalState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetrievalEvalState>(value),
    );
  }
}

String _$retrievalEvalControllerHash() =>
    r'1918c4927396d7d3b234ade21d023a5ef5ca7351';

/// Runs every question of the eval set through retrieval and exports the
/// results as JSON (task 2.8).

abstract class _$RetrievalEvalController extends $Notifier<RetrievalEvalState> {
  RetrievalEvalState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RetrievalEvalState, RetrievalEvalState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RetrievalEvalState, RetrievalEvalState>,
              RetrievalEvalState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
