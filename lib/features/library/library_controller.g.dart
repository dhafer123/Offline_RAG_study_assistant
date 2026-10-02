// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's documents: import, index one at a time, retry, delete.
///
/// Kept alive so indexing continues when the user leaves the screen.
/// Documents left `pending` or `indexing` (the app was closed or killed
/// mid-way) are queued again on start.

@ProviderFor(LibraryController)
final libraryControllerProvider = LibraryControllerProvider._();

/// The user's documents: import, index one at a time, retry, delete.
///
/// Kept alive so indexing continues when the user leaves the screen.
/// Documents left `pending` or `indexing` (the app was closed or killed
/// mid-way) are queued again on start.
final class LibraryControllerProvider
    extends $NotifierProvider<LibraryController, LibraryState> {
  /// The user's documents: import, index one at a time, retry, delete.
  ///
  /// Kept alive so indexing continues when the user leaves the screen.
  /// Documents left `pending` or `indexing` (the app was closed or killed
  /// mid-way) are queued again on start.
  LibraryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryControllerHash();

  @$internal
  @override
  LibraryController create() => LibraryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryState>(value),
    );
  }
}

String _$libraryControllerHash() => r'ca7906cc239304cd8ec605817d0ab593ec3a36eb';

/// The user's documents: import, index one at a time, retry, delete.
///
/// Kept alive so indexing continues when the user leaves the screen.
/// Documents left `pending` or `indexing` (the app was closed or killed
/// mid-way) are queued again on start.

abstract class _$LibraryController extends $Notifier<LibraryState> {
  LibraryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LibraryState, LibraryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryState, LibraryState>,
              LibraryState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Whether at least one document is indexed and can be searched; null while
/// the library is still loading.

@ProviderFor(hasReadyDocuments)
final hasReadyDocumentsProvider = HasReadyDocumentsProvider._();

/// Whether at least one document is indexed and can be searched; null while
/// the library is still loading.

final class HasReadyDocumentsProvider
    extends $FunctionalProvider<bool?, bool?, bool?>
    with $Provider<bool?> {
  /// Whether at least one document is indexed and can be searched; null while
  /// the library is still loading.
  HasReadyDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasReadyDocumentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasReadyDocumentsHash();

  @$internal
  @override
  $ProviderElement<bool?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool? create(Ref ref) {
    return hasReadyDocuments(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool?>(value),
    );
  }
}

String _$hasReadyDocumentsHash() => r'd15d762286d1ae1031c845ce2b60a0d476dfc6b8';
