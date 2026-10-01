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

String _$libraryControllerHash() => r'951d60629b3ea2e5af16a668c7d6ec1272b061c1';

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
