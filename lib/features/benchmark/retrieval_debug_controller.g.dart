// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retrieval_debug_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Indexes PDFs pushed to the pdfs folder, runs vector searches (task 2.5)
/// and answers questions through `AnswerService` (task 3.3, until the chat
/// screen).

@ProviderFor(RetrievalDebugController)
final retrievalDebugControllerProvider = RetrievalDebugControllerProvider._();

/// Indexes PDFs pushed to the pdfs folder, runs vector searches (task 2.5)
/// and answers questions through `AnswerService` (task 3.3, until the chat
/// screen).
final class RetrievalDebugControllerProvider
    extends $NotifierProvider<RetrievalDebugController, RetrievalDebugState> {
  /// Indexes PDFs pushed to the pdfs folder, runs vector searches (task 2.5)
  /// and answers questions through `AnswerService` (task 3.3, until the chat
  /// screen).
  RetrievalDebugControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retrievalDebugControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retrievalDebugControllerHash();

  @$internal
  @override
  RetrievalDebugController create() => RetrievalDebugController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetrievalDebugState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetrievalDebugState>(value),
    );
  }
}

String _$retrievalDebugControllerHash() =>
    r'72bdea6a8929dfde5c12988ca91fad98b74fe21d';

/// Indexes PDFs pushed to the pdfs folder, runs vector searches (task 2.5)
/// and answers questions through `AnswerService` (task 3.3, until the chat
/// screen).

abstract class _$RetrievalDebugController
    extends $Notifier<RetrievalDebugState> {
  RetrievalDebugState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RetrievalDebugState, RetrievalDebugState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RetrievalDebugState, RetrievalDebugState>,
              RetrievalDebugState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
