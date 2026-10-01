import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';
import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/library/chunker.dart';
import 'package:offline_study_assistant/features/library/text_cleaner.dart';

enum IngestionStage { extracting, chunking, embedding, saving }

@immutable
class IngestionProgress {
  const IngestionProgress(this.stage, {this.done = 0, this.total = 0});

  final IngestionStage stage;

  /// Pages extracted or chunks embedded so far; 0 for stages without steps.
  final int done;
  final int total;
}

@immutable
class IngestionResult {
  const IngestionResult({
    required this.documentId,
    required this.pageCount,
    required this.chunkCount,
    required this.textlessPages,
    required this.extractTime,
    required this.chunkTime,
    required this.embedTime,
    required this.saveTime,
  });

  final int documentId;
  final int pageCount;
  final int chunkCount;

  /// Pages with no text layer (scanned); they can't be searched.
  final List<int> textlessPages;

  final Duration extractTime;

  /// Cleaning and chunking.
  final Duration chunkTime;
  final Duration embedTime;

  /// Storing chunks and vectors.
  final Duration saveTime;

  Duration get total => extractTime + chunkTime + embedTime + saveTime;

  @override
  String toString() =>
      'pages=$pageCount chunks=$chunkCount textless=${textlessPages.length} '
      'extract=${extractTime.inMilliseconds}ms '
      'chunk=${chunkTime.inMilliseconds}ms '
      'embed=${embedTime.inMilliseconds}ms '
      'save=${saveTime.inMilliseconds}ms '
      'total=${total.inMilliseconds}ms';
}

class IngestionException implements Exception {
  const IngestionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'IngestionException: $message'
      : 'IngestionException: $message ($cause)';
}

/// Indexes a PDF: extract → clean → chunk → embed → store.
///
/// The document row is created first with status `indexing`, then set to
/// `ready`, or to `failed` if any step throws.
class IngestionService {
  IngestionService({
    required PdfTextExtractor extractor,
    required DocumentStore store,
    required Embedder embedder,
    required VectorIndex index,
    StopwatchFactory stopwatch = Stopwatch.new,
  }) : _extractor = extractor,
       _store = store,
       _embedder = embedder,
       _index = index,
       _stopwatch = stopwatch;

  final PdfTextExtractor _extractor;
  final DocumentStore _store;
  final Embedder _embedder;
  final VectorIndex _index;
  final StopwatchFactory _stopwatch;

  /// Indexes the PDF at [path] under [title].
  ///
  /// Throws [IngestionException] if the PDF has no text at all, or wraps the
  /// extractor's, embedder's or store's error.
  Future<IngestionResult> ingest(
    String path, {
    required String title,
    void Function(IngestionProgress progress)? onProgress,
  }) async {
    final docId = await _store.insertDocument(
      title: title,
      path: path,
      status: DocumentStatus.indexing,
    );
    try {
      final result = await _ingest(docId, path, onProgress);
      await _store.updateDocument(
        docId,
        status: DocumentStatus.ready,
        pageCount: result.pageCount,
      );
      Perf.log('ingest "$title": $result');
      return result;
    } on Object catch (e, st) {
      await _store.updateDocument(docId, status: DocumentStatus.failed);
      if (e is IngestionException) rethrow;
      Error.throwWithStackTrace(
        IngestionException('Indexing "$title" failed', cause: e),
        st,
      );
    }
  }

  Future<IngestionResult> _ingest(
    int docId,
    String path,
    void Function(IngestionProgress progress)? onProgress,
  ) async {
    onProgress?.call(const IngestionProgress(IngestionStage.extracting));
    final (doc, extractTime) = await Perf.time(
      () => _extractor.extract(
        path,
        onProgress: (done, total) => onProgress?.call(
          IngestionProgress(
            IngestionStage.extracting,
            done: done,
            total: total,
          ),
        ),
      ),
      stopwatch: _stopwatch,
    );
    if (doc.isScanned) {
      throw const IngestionException(
        'This PDF has no text layer (scanned pages need OCR)',
      );
    }

    onProgress?.call(const IngestionProgress(IngestionStage.chunking));
    final (chunks, chunkTime) = await Perf.time(
      () async => chunkPages(cleanPages([for (final p in doc.pages) p.text])),
      stopwatch: _stopwatch,
    );
    if (chunks.isEmpty) {
      throw const IngestionException('No text left after cleaning');
    }

    onProgress?.call(
      IngestionProgress(IngestionStage.embedding, total: chunks.length),
    );
    final (vectors, embedTime) = await Perf.time(() async {
      await _embedder.load();
      return _embedder.embedDocuments(
        [for (final c in chunks) c.text],
        onProgress: (done, total) => onProgress?.call(
          IngestionProgress(IngestionStage.embedding, done: done, total: total),
        ),
      );
    }, stopwatch: _stopwatch);

    onProgress?.call(const IngestionProgress(IngestionStage.saving));
    final (_, saveTime) = await Perf.time(() async {
      final ids = await _store.insertChunks(docId, chunks);
      await _index.add([
        for (var i = 0; i < ids.length; i++)
          ChunkVector(chunkId: ids[i], vector: vectors[i]),
      ]);
    }, stopwatch: _stopwatch);

    return IngestionResult(
      documentId: docId,
      pageCount: doc.pageCount,
      chunkCount: chunks.length,
      textlessPages: doc.textlessPages,
      extractTime: extractTime,
      chunkTime: chunkTime,
      embedTime: embedTime,
      saveTime: saveTime,
    );
  }
}
