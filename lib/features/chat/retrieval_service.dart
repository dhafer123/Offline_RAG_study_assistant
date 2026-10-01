import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';

/// A chunk found for a question, with what a citation needs.
@immutable
class RetrievedChunk {
  const RetrievedChunk({
    required this.chunk,
    required this.documentTitle,
    required this.similarity,
  });

  final Chunk chunk;
  final String documentTitle;

  /// Cosine similarity to the question (see `VectorHit.similarity`).
  final double similarity;

  int get page => chunk.page;
}

/// Finds the chunks most relevant to a question.
///
/// Vector search only for now; keyword search and RRF fusion come with
/// task 3.1.
class RetrievalService {
  RetrievalService({
    required Embedder embedder,
    required VectorIndex index,
    required DocumentStore store,
  }) : _embedder = embedder,
       _index = index,
       _store = store;

  final Embedder _embedder;
  final VectorIndex _index;
  final DocumentStore _store;

  /// The [k] best chunks for [question], best first.
  Future<List<RetrievedChunk>> retrieve(String question, {int k = 5}) async {
    if (question.trim().isEmpty) return const [];
    await _embedder.load();
    final query = await _embedder.embedQuery(question);
    final hits = await _index.search(query, k: k);
    final chunks = {
      for (final c in await _store.chunksByIds([
        for (final h in hits) h.chunkId,
      ]))
        c.id: c,
    };
    final titles = <int, String>{};
    final results = <RetrievedChunk>[];
    for (final hit in hits) {
      // Skipped if the chunk was deleted since the search.
      final chunk = chunks[hit.chunkId];
      if (chunk == null) continue;
      final title = titles[chunk.docId] ??=
          (await _store.getDocument(chunk.docId))?.title ?? 'Unknown document';
      results.add(
        RetrievedChunk(
          chunk: chunk,
          documentTitle: title,
          similarity: hit.similarity,
        ),
      );
    }
    return results;
  }
}
