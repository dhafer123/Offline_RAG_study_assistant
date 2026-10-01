import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';
import 'package:offline_study_assistant/features/library/pdf_files.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_controller.g.dart';

@immutable
class LibraryState {
  const LibraryState({
    this.loading = true,
    this.documents = const [],
    this.queued = const [],
    this.runningId,
    this.progress,
    this.errors = const {},
    this.message,
  });

  final bool loading;

  /// Newest first.
  final List<Document> documents;

  /// Documents waiting to be indexed, in order.
  final List<int> queued;

  /// The document being indexed, if any.
  final int? runningId;
  final IngestionProgress? progress;

  /// Why indexing failed, for documents that failed since the app started.
  final Map<int, String> errors;

  /// A one-off message for the user (e.g. an import that failed).
  final String? message;

  bool isBusy(int docId) => docId == runningId || queued.contains(docId);

  LibraryState copyWith({
    bool? loading,
    List<Document>? documents,
    List<int>? queued,
    int? Function()? runningId,
    IngestionProgress? Function()? progress,
    Map<int, String>? errors,
    String? Function()? message,
  }) {
    return LibraryState(
      loading: loading ?? this.loading,
      documents: documents ?? this.documents,
      queued: queued ?? this.queued,
      runningId: runningId != null ? runningId() : this.runningId,
      progress: progress != null ? progress() : this.progress,
      errors: errors ?? this.errors,
      message: message != null ? message() : this.message,
    );
  }
}

/// The user's documents: import, index one at a time, retry, delete.
///
/// Kept alive so indexing continues when the user leaves the screen.
/// Documents left `pending` or `indexing` (the app was closed or killed
/// mid-way) are queued again on start.
@Riverpod(keepAlive: true)
class LibraryController extends _$LibraryController {
  final _queue = Queue<int>();
  bool _running = false;

  @override
  LibraryState build() {
    unawaited(_start());
    return const LibraryState();
  }

  Future<void> _start() async {
    final docs = await _store.listDocuments();
    // Oldest first, as they were imported.
    for (final doc in docs.reversed) {
      if (doc.status == DocumentStatus.pending ||
          doc.status == DocumentStatus.indexing) {
        _queue.add(doc.id);
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      loading: false,
      documents: docs,
      queued: _queue.toList(),
    );
    unawaited(_pump());
  }

  /// Lets the user pick a PDF, copies it into the app and queues it.
  Future<void> importPdf() async {
    final PickedPdf? picked;
    try {
      picked = await ref.read(pdfPickerProvider).pick();
    } on Object catch (e) {
      _say('Could not open the file picker ($e)');
      return;
    }
    if (picked == null) return;

    try {
      final path = await ref
          .read(pdfFilesProvider)
          .importCopy(picked.path, name: picked.name);
      final docId = await ref
          .read(ingestionServiceProvider)
          .addDocument(path, title: PdfFiles.titleFor(picked.name));
      _queue.add(docId);
      await _reload();
      unawaited(_pump());
    } on Object catch (e) {
      _say('Could not import "${picked.name}" ($e)');
    }
  }

  /// Queues a failed document again.
  Future<void> retry(int docId) async {
    if (state.isBusy(docId)) return;
    _queue.add(docId);
    state = state.copyWith(
      queued: _queue.toList(),
      errors: Map.of(state.errors)..remove(docId),
    );
    unawaited(_pump());
  }

  /// Deletes the document, its chunks and vectors, and our copy of the PDF.
  /// A document being indexed can't be deleted until it finishes.
  Future<void> delete(int docId) async {
    if (docId == state.runningId) return;
    _queue.remove(docId);
    final doc = await _store.getDocument(docId);
    await _store.deleteDocument(docId);
    if (doc != null) await ref.read(pdfFilesProvider).delete(doc.path);
    if (!ref.mounted) return;
    state = state.copyWith(errors: Map.of(state.errors)..remove(docId));
    await _reload();
  }

  void clearMessage() => state = state.copyWith(message: () => null);

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && ref.mounted) {
        final docId = _queue.removeFirst();
        state = state.copyWith(
          queued: _queue.toList(),
          runningId: () => docId,
          progress: () => null,
        );
        String? error;
        final frames = ref.read(frameMonitorProvider)..start();
        try {
          await ref
              .read(ingestionServiceProvider)
              .index(
                docId,
                onProgress: (p) {
                  if (ref.mounted) state = state.copyWith(progress: () => p);
                },
              );
        } on Object catch (e) {
          error = describeIngestionError(e);
        } finally {
          Perf.log('frames while indexing document $docId: ${frames.stop()}');
        }
        if (!ref.mounted) return;
        state = state.copyWith(
          runningId: () => null,
          progress: () => null,
          errors: error == null
              ? state.errors
              : (Map.of(state.errors)..[docId] = error),
        );
        await _reload();
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _reload() async {
    final docs = await _store.listDocuments();
    if (!ref.mounted) return;
    state = state.copyWith(documents: docs, queued: _queue.toList());
  }

  void _say(String message) {
    if (ref.mounted) state = state.copyWith(message: () => message);
  }

  DocumentStore get _store => ref.read(documentStoreProvider);
}

/// A message the user can act on for an indexing failure.
String describeIngestionError(Object error) {
  final cause = error is IngestionException ? error.cause : error;
  return switch (cause) {
    PdfExtractionException(error: PdfExtractionError.passwordProtected) =>
      'This PDF is password-protected.',
    PdfExtractionException(error: PdfExtractionError.invalidPdf) =>
      'This file is not a valid PDF.',
    PdfExtractionException(error: PdfExtractionError.fileNotFound) =>
      'The PDF file is missing. Delete it and import it again.',
    EmbedderException() =>
      'The embedding model could not run. Try again; if it keeps failing, '
          'restart the app.',
    null when error is IngestionException => error.message,
    _ => 'Indexing failed (${cause ?? error}).',
  };
}
