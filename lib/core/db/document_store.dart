import 'package:flutter/foundation.dart';

/// Where a document is in the indexing pipeline.
enum DocumentStatus {
  /// Imported, not indexed yet.
  pending,

  /// Extraction, chunking or embedding is running.
  indexing,

  /// All chunks are stored and searchable.
  ready,

  /// Indexing stopped with an error.
  failed,
}

@immutable
class Document {
  const Document({
    required this.id,
    required this.title,
    required this.path,
    required this.pageCount,
    required this.status,
    this.indexedAt,
  });

  final int id;
  final String title;

  /// Absolute path of the PDF on the device.
  final String path;
  final int pageCount;
  final DocumentStatus status;

  /// When the document last reached [DocumentStatus.ready] (UTC).
  final DateTime? indexedAt;
}

/// A chunk to insert; the store assigns its id.
@immutable
class NewChunk {
  const NewChunk({
    required this.page,
    required this.ordinal,
    required this.text,
  });

  /// 1-based page the chunk comes from. A chunk never spans two pages.
  final int page;

  /// 0-based position of the chunk within its document.
  final int ordinal;
  final String text;
}

@immutable
class Chunk {
  const Chunk({
    required this.id,
    required this.docId,
    required this.page,
    required this.ordinal,
    required this.text,
  });

  final int id;
  final int docId;
  final int page;
  final int ordinal;
  final String text;
}

/// A full-text match. Higher [score] means a better match.
@immutable
class KeywordHit {
  const KeywordHit({required this.chunkId, required this.score});

  final int chunkId;

  /// BM25 relevance, negated so that higher is better.
  final double score;
}

class DocumentNotFoundException implements Exception {
  const DocumentNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'DocumentNotFoundException: no document with id $id';
}

/// Stores documents, their chunks and the full-text index over chunk text.
///
/// Implemented by `AppDatabase` (drift + SQLite FTS5); the rest of the app
/// only depends on this interface.
abstract interface class DocumentStore {
  /// Returns the new document's id.
  Future<int> insertDocument({
    required String title,
    required String path,
    int pageCount = 0,
    DocumentStatus status = DocumentStatus.pending,
  });

  Future<Document?> getDocument(int id);

  /// All documents, newest first.
  Future<List<Document>> listDocuments();

  /// Updates the given fields. Moving to [DocumentStatus.ready] also sets
  /// `indexedAt` to now.
  ///
  /// Throws [DocumentNotFoundException] if [id] doesn't exist.
  Future<void> updateDocument(int id, {DocumentStatus? status, int? pageCount});

  /// Deletes the document and all its chunks. No-op if [id] doesn't exist.
  Future<void> deleteDocument(int id);

  /// Inserts [chunks] for [docId] in one transaction and returns their ids, in
  /// the same order.
  ///
  /// Throws [DocumentNotFoundException] if [docId] doesn't exist.
  Future<List<int>> insertChunks(int docId, List<NewChunk> chunks);

  /// Deletes the chunks of [docId] (before re-indexing it).
  Future<void> deleteChunks(int docId);

  /// The chunks of [docId], ordered by ordinal.
  Future<List<Chunk>> chunksForDocument(int docId);

  /// The chunks with these ids, in the order of [ids]. Unknown ids are skipped.
  Future<List<Chunk>> chunksByIds(List<int> ids);

  /// Full-text (BM25) search over chunk text, best match first.
  ///
  /// [query] is free text, e.g. the user's question; it is never parsed as
  /// FTS5 syntax. Returns an empty list when it contains no searchable word.
  Future<List<KeywordHit>> searchKeyword(String query, {int limit = 20});

  Future<void> close();
}
