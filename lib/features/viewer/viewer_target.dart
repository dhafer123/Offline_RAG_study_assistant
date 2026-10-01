import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_target.g.dart';

/// What the viewer opens: a document's file at a page, and the text to
/// highlight there.
@immutable
class ViewerTarget {
  const ViewerTarget({
    required this.title,
    required this.path,
    required this.page,
    this.highlight,
  });

  final String title;
  final String path;
  final int page;

  /// The cited chunk's text, when a chunk was given.
  final String? highlight;
}

/// The document is gone (deleted since the answer) or its file is missing.
class ViewerTargetException implements Exception {
  const ViewerTargetException(this.message);

  final String message;

  @override
  String toString() => 'ViewerTargetException: $message';
}

/// Resolves [docId] (and optionally [chunkId]) to the file and text to show.
///
/// Throws [ViewerTargetException] when the document or its file is gone.
/// Not retried: a deleted document or file won't come back on its own.
@Riverpod(retry: _noRetry)
Future<ViewerTarget> viewerTarget(
  Ref ref, {
  required int docId,
  required int page,
  int? chunkId,
}) async {
  final store = ref.watch(documentStoreProvider);
  final doc = await store.getDocument(docId);
  if (doc == null) {
    throw const ViewerTargetException(
      'This document was removed from your library.',
    );
  }
  if (!File(doc.path).existsSync()) {
    throw ViewerTargetException('The file of "${doc.title}" is missing.');
  }
  final chunks = chunkId == null
      ? const <Chunk>[]
      : await store.chunksByIds([chunkId]);
  return ViewerTarget(
    title: doc.title,
    path: doc.path,
    page: page.clamp(1, doc.pageCount < 1 ? page : doc.pageCount),
    highlight: chunks.isEmpty ? null : chunks.single.text,
  );
}

Duration? _noRetry(int retryCount, Object error) => null;
