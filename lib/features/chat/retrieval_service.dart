import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';
import 'package:offline_study_assistant/features/chat/rrf.dart';

/// Which searches [RetrievalService.retrieve] runs.
enum RetrievalMode {
  /// Embedding similarity only.
  vector,

  /// FTS5 (BM25) only; doesn't load the embedder.
  keyword,

  /// Vector and keyword results merged with RRF. The app's default.
  hybrid,
}

/// A chunk found for a question, with what a citation needs.
@immutable
class RetrievedChunk {
  const RetrievedChunk({
    required this.chunk,
    required this.documentTitle,
    required this.score,
    this.similarity,
  });

  final Chunk chunk;
  final String documentTitle;

  /// Ranking score, higher is better: the RRF score in hybrid mode, else the
  /// cosine similarity (vector) or negated BM25 (keyword).
  final double score;

  /// Cosine similarity to the question (see `VectorHit.similarity`), or null
  /// if the chunk wasn't among the vector candidates (keyword-only match).
  final double? similarity;

  int get page => chunk.page;
}

/// Finds the chunks most relevant to a question.
///
/// Hybrid by default: the top [candidates] of the vector search and of the
/// FTS5 search are merged with Reciprocal Rank Fusion, then cut to `k`.
class RetrievalService {
  RetrievalService({
    required Embedder embedder,
    required VectorIndex index,
    required DocumentStore store,
    this.candidates = 20,
    this.rrfK = defaultRrfK,
  }) : _embedder = embedder,
       _index = index,
       _store = store;

  final Embedder _embedder;
  final VectorIndex _index;
  final DocumentStore _store;

  /// How many hits each search contributes before fusion.
  final int candidates;
  final int rrfK;

  /// The [k] best chunks for [question], best first.
  Future<List<RetrievedChunk>> retrieve(
    String question, {
    int k = 5,
    RetrievalMode mode = RetrievalMode.hybrid,
  }) async {
    if (question.trim().isEmpty) return const [];

    final vectorHits = mode == RetrievalMode.keyword
        ? const <VectorHit>[]
        : await _searchVector(
            question,
            mode == RetrievalMode.vector ? k : null,
          );
    final keywordHits = mode == RetrievalMode.vector
        ? const <KeywordHit>[]
        : await _store.searchKeyword(
            question,
            limit: mode == RetrievalMode.keyword ? k : candidates,
          );

    final similarities = {
      for (final h in vectorHits) h.chunkId: h.similarity,
    };
    final ranked = switch (mode) {
      RetrievalMode.vector => [
        for (final h in vectorHits) (id: h.chunkId, score: h.similarity),
      ],
      RetrievalMode.keyword => [
        for (final h in keywordHits) (id: h.chunkId, score: h.score),
      ],
      RetrievalMode.hybrid => [
        for (final f in reciprocalRankFusion(
          [
            [for (final h in vectorHits) h.chunkId],
            [for (final h in keywordHits) h.chunkId],
          ],
          k: rrfK,
          limit: k,
        ))
          (id: f.item, score: f.score),
      ],
    };
    return _resolve(ranked, similarities);
  }

  /// Vector hits for [question]: [k] of them, or [candidates] when null.
  Future<List<VectorHit>> _searchVector(String question, int? k) async {
    await _embedder.load();
    final query = await _embedder.embedQuery(question);
    return _index.search(query, k: k ?? candidates);
  }

  Future<List<RetrievedChunk>> _resolve(
    List<({int id, double score})> ranked,
    Map<int, double> similarities,
  ) async {
    final chunks = {
      for (final c in await _store.chunksByIds([for (final r in ranked) r.id]))
        c.id: c,
    };
    final titles = <int, String>{};
    final results = <RetrievedChunk>[];
    for (final r in ranked) {
      // Skipped if the chunk was deleted since the search.
      final chunk = chunks[r.id];
      if (chunk == null) continue;
      final title = titles[chunk.docId] ??=
          (await _store.getDocument(chunk.docId))?.title ?? 'Unknown document';
      results.add(
        RetrievedChunk(
          chunk: chunk,
          documentTitle: title,
          score: r.score,
          similarity: similarities[r.id],
        ),
      );
    }
    return results;
  }
}
