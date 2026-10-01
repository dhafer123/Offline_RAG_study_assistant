// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_target.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves [docId] (and optionally [chunkId]) to the file and text to show.
///
/// Throws [ViewerTargetException] when the document or its file is gone.
/// Not retried: a deleted document or file won't come back on its own.

@ProviderFor(viewerTarget)
final viewerTargetProvider = ViewerTargetFamily._();

/// Resolves [docId] (and optionally [chunkId]) to the file and text to show.
///
/// Throws [ViewerTargetException] when the document or its file is gone.
/// Not retried: a deleted document or file won't come back on its own.

final class ViewerTargetProvider
    extends
        $FunctionalProvider<
          AsyncValue<ViewerTarget>,
          ViewerTarget,
          FutureOr<ViewerTarget>
        >
    with $FutureModifier<ViewerTarget>, $FutureProvider<ViewerTarget> {
  /// Resolves [docId] (and optionally [chunkId]) to the file and text to show.
  ///
  /// Throws [ViewerTargetException] when the document or its file is gone.
  /// Not retried: a deleted document or file won't come back on its own.
  ViewerTargetProvider._({
    required ViewerTargetFamily super.from,
    required ({int docId, int page, int? chunkId}) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'viewerTargetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewerTargetHash();

  @override
  String toString() {
    return r'viewerTargetProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ViewerTarget> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ViewerTarget> create(Ref ref) {
    final argument = this.argument as ({int docId, int page, int? chunkId});
    return viewerTarget(
      ref,
      docId: argument.docId,
      page: argument.page,
      chunkId: argument.chunkId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ViewerTargetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewerTargetHash() => r'd532965e5745bf226eeb8384797db57bcf3902d0';

/// Resolves [docId] (and optionally [chunkId]) to the file and text to show.
///
/// Throws [ViewerTargetException] when the document or its file is gone.
/// Not retried: a deleted document or file won't come back on its own.

final class ViewerTargetFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ViewerTarget>,
          ({int docId, int page, int? chunkId})
        > {
  ViewerTargetFamily._()
    : super(
        retry: _noRetry,
        name: r'viewerTargetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves [docId] (and optionally [chunkId]) to the file and text to show.
  ///
  /// Throws [ViewerTargetException] when the document or its file is gone.
  /// Not retried: a deleted document or file won't come back on its own.

  ViewerTargetProvider call({
    required int docId,
    required int page,
    int? chunkId,
  }) => ViewerTargetProvider._(
    argument: (docId: docId, page: page, chunkId: chunkId),
    from: this,
  );

  @override
  String toString() => r'viewerTargetProvider';
}
