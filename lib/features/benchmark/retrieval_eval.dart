import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// How many retrieved chunks count: Recall@5, as in the RAG pipeline (top 5
/// sources in the prompt).
const defaultEvalK = 5;

/// One question of `eval/questions.json`.
@immutable
class EvalQuestion {
  const EvalQuestion({
    required this.id,
    required this.lang,
    required this.question,
    required this.answerable,
    this.doc,
    this.pages = const [],
    this.answer,
  });

  factory EvalQuestion.fromJson(Map<String, dynamic> json) {
    final answerable = json['answerable'] as bool;
    final pages = (json['pages'] as List<dynamic>? ?? const []).cast<int>();
    if (answerable && (json['doc'] == null || pages.isEmpty)) {
      throw FormatException('${json['id']}: answerable needs doc and pages');
    }
    return EvalQuestion(
      id: json['id'] as String,
      lang: json['lang'] as String,
      question: json['question'] as String,
      answerable: answerable,
      doc: json['doc'] as String?,
      pages: pages,
      answer: json['answer'] as String?,
    );
  }

  final String id;
  final String lang;
  final String question;
  final bool answerable;

  /// Document key (see [docKey]); null for unanswerable questions.
  final String? doc;

  /// 1-based pages whose text answers the question.
  final List<int> pages;
  final String? answer;
}

/// Parses `eval/questions.json`.
List<EvalQuestion> parseEvalQuestions(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  return [
    for (final q in json['questions'] as List<dynamic>)
      EvalQuestion.fromJson(q as Map<String, dynamic>),
  ];
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
};

/// The key a document title is matched on: no ".pdf", no accents,
/// lower-case. "État_de_l_art.pdf" and "etat_de_l_art" both give
/// "etat_de_l_art".
String docKey(String title) {
  var key = title.trim().toLowerCase();
  if (key.endsWith('.pdf')) key = key.substring(0, key.length - 4);
  return key.split('').map((c) => _accents[c] ?? c).join();
}

/// A chunk retrieved for a question.
@immutable
class EvalHit {
  const EvalHit({
    required this.documentTitle,
    required this.page,
    required this.similarity,
    required this.chunkId,
  });

  factory EvalHit.from(RetrievedChunk chunk) => EvalHit(
    documentTitle: chunk.documentTitle,
    page: chunk.page,
    similarity: chunk.similarity,
    chunkId: chunk.chunk.id,
  );

  final String documentTitle;
  final int page;
  final double similarity;
  final int chunkId;

  Map<String, Object?> toJson() => {
    'doc': documentTitle,
    'page': page,
    'similarity': _round4(similarity),
    'chunk_id': chunkId,
  };
}

@immutable
class QuestionResult {
  const QuestionResult({
    required this.question,
    required this.hits,
    required this.latency,
  });

  final EvalQuestion question;

  /// Retrieved chunks, best first.
  final List<EvalHit> hits;

  /// Embedding the question plus the search.
  final Duration latency;

  /// 1-based rank of the first chunk from the right document and page, or
  /// null if none was retrieved (always null when unanswerable).
  int? get rank {
    if (!question.answerable) return null;
    for (var i = 0; i < hits.length; i++) {
      final hit = hits[i];
      if (docKey(hit.documentTitle) == question.doc!.toLowerCase() &&
          question.pages.contains(hit.page)) {
        return i + 1;
      }
    }
    return null;
  }

  /// Whether a correct chunk is within the first [k].
  bool foundWithin(int k) => (rank ?? k + 1) <= k;

  double? get topSimilarity => hits.isEmpty ? null : hits.first.similarity;

  Map<String, Object?> toJson() => {
    'id': question.id,
    'lang': question.lang,
    'question': question.question,
    'answerable': question.answerable,
    if (question.doc != null) 'doc': question.doc,
    if (question.answerable) 'pages': question.pages,
    'rank': rank,
    'top_similarity': topSimilarity == null ? null : _round4(topSimilarity!),
    'latency_ms': latency.inMilliseconds,
    'hits': [for (final h in hits) h.toJson()],
  };
}

/// Recall@k: share of answerable questions with a correct chunk in the top
/// k, overall and per language and document.
@immutable
class RetrievalEvalSummary {
  const RetrievalEvalSummary({
    required this.k,
    required this.answerable,
    required this.found,
    required this.mrr,
    required this.byLang,
    required this.byDoc,
    required this.medianLatency,
  });

  factory RetrievalEvalSummary.of(
    List<QuestionResult> results, {
    int k = defaultEvalK,
  }) {
    final answerable = results.where((r) => r.question.answerable).toList();
    ({int found, int total}) count(Iterable<QuestionResult> rs) => (
      found: rs.where((r) => r.foundWithin(k)).length,
      total: rs.length,
    );
    Map<String, ({int found, int total})> groupBy(
      String Function(QuestionResult) key,
    ) {
      final groups = <String, List<QuestionResult>>{};
      for (final r in answerable) {
        groups.putIfAbsent(key(r), () => []).add(r);
      }
      return {
        for (final e
            in (groups.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))))
          e.key: count(e.value),
      };
    }

    return RetrievalEvalSummary(
      k: k,
      answerable: answerable.length,
      found: count(answerable).found,
      mrr: answerable.isEmpty
          ? 0
          : answerable
                    .map((r) => r.rank == null ? 0.0 : 1 / r.rank!)
                    .reduce((a, b) => a + b) /
                answerable.length,
      byLang: groupBy((r) => r.question.lang),
      byDoc: groupBy((r) => r.question.doc!),
      medianLatency: results.isEmpty
          ? Duration.zero
          : Duration(
              milliseconds: Perf.median(
                results.map((r) => r.latency.inMilliseconds),
              ).round(),
            ),
    );
  }

  final int k;
  final int answerable;
  final int found;

  /// Mean reciprocal rank over the retrieved list (0 when not found).
  final double mrr;
  final Map<String, ({int found, int total})> byLang;
  final Map<String, ({int found, int total})> byDoc;
  final Duration medianLatency;

  double get recall => answerable == 0 ? 0 : found / answerable;

  Map<String, Object?> toJson() {
    Map<String, Object?> group(Map<String, ({int found, int total})> g) => {
      for (final MapEntry(:key, :value) in g.entries)
        key: {
          'found': value.found,
          'total': value.total,
          'recall': _round4(value.found / value.total),
        },
    };
    return {
      'k': k,
      'answerable': answerable,
      'found': found,
      'recall_at_k': _round4(recall),
      'mrr': _round4(mrr),
      'median_latency_ms': medianLatency.inMilliseconds,
      'by_lang': group(byLang),
      'by_doc': group(byDoc),
    };
  }

  @override
  String toString() =>
      'recall@$k=${(recall * 100).toStringAsFixed(1)}% ($found/$answerable) '
      'mrr=${mrr.toStringAsFixed(3)} '
      'median=${medianLatency.inMilliseconds}ms';
}

/// Retrieves the top [k] chunks for a question (vector-only today, hybrid in
/// task 3.1).
typedef EvalRetriever =
    Future<List<RetrievedChunk>> Function(String question, int k);

/// Runs [retrieve] on every question, in order.
Future<List<QuestionResult>> runRetrievalEval(
  List<EvalQuestion> questions,
  EvalRetriever retrieve, {
  int k = defaultEvalK,
  void Function(int done, int total)? onProgress,
  StopwatchFactory stopwatch = Stopwatch.new,
}) async {
  final results = <QuestionResult>[];
  for (final q in questions) {
    final (chunks, latency) = await Perf.time(
      () => retrieve(q.question, k),
      stopwatch: stopwatch,
    );
    results.add(
      QuestionResult(
        question: q,
        hits: [for (final c in chunks) EvalHit.from(c)],
        latency: latency,
      ),
    );
    onProgress?.call(results.length, questions.length);
  }
  return results;
}

/// The JSON export of one run (written to `eval/results/`).
Map<String, Object?> retrievalEvalReport({
  required String method,
  required DateTime createdAt,
  required List<String> indexedDocuments,
  required List<QuestionResult> results,
  int k = defaultEvalK,
}) => {
  'created': createdAt.toUtc().toIso8601String(),
  'method': method,
  'k': k,
  'indexed_documents': indexedDocuments,
  'summary': RetrievalEvalSummary.of(results, k: k).toJson(),
  'results': [for (final r in results) r.toJson()],
};

double _round4(double x) => double.parse(x.toStringAsFixed(4));
