import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/citation_parser.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// Answers one question, as `AnswerService.answer` does.
typedef EvalAnswerer = Stream<AnswerEvent> Function(String question);

/// What the app did with one eval question (task 4.1). The automatic checks
/// here help the hand grading of task 4.2; they don't replace it.
@immutable
class AnswerEvalResult {
  const AnswerEvalResult({
    required this.question,
    required this.refusedByGate,
    required this.retrievalTime,
    this.bestSimilarity,
    this.sources = const [],
    this.answer = '',
    this.modelLoadTime,
    this.generation,
    this.error,
  });

  final EvalQuestion question;

  /// The similarity gate answered "not found" without calling the LLM.
  final bool refusedByGate;
  final double? bestSimilarity;
  final Duration retrievalTime;

  /// The sources the prompt held; `[n]` is `sources[n - 1]`.
  final List<RetrievedChunk> sources;

  /// The model's raw answer, or the gate's message when refused.
  final String answer;
  final Duration? modelLoadTime;
  final GenerationMetrics? generation;

  /// Why answering failed, if it did.
  final String? error;

  ParsedAnswer get parsed => parseCitations(answer, sources);

  /// The model answered with the "not found" reply.
  bool get modelSaidNotFound => !refusedByGate && isNotFoundReply(answer);

  /// Refused by the gate or by the model.
  bool get declined => refusedByGate || modelSaidNotFound;

  /// A source from the right document and page was in the prompt. Null for
  /// unanswerable questions and gate refusals.
  bool? get sourceHit => !question.answerable || refusedByGate
      ? null
      : sources.any((s) => question.isAnsweredBy(s.documentTitle, s.page));

  /// At least one citation points to the right document and page. Null when
  /// the question is unanswerable or the answer cites nothing.
  bool? get citesRightPage {
    final citations = parsed.citations;
    if (!question.answerable || citations.isEmpty) return null;
    return citations.any(
      (c) => question.isAnsweredBy(c.documentTitle, c.page),
    );
  }

  Map<String, Object?> toJson() => {
    'id': question.id,
    'lang': question.lang,
    'question': question.question,
    'answerable': question.answerable,
    if (question.doc != null) 'doc': question.doc,
    if (question.answerable) 'pages': question.pages,
    if (question.answer != null) 'expected_answer': question.answer,
    'refused_by_gate': refusedByGate,
    'best_similarity': bestSimilarity == null ? null : _round4(bestSimilarity!),
    'sources': [
      for (final (i, s) in sources.indexed)
        {
          'n': i + 1,
          'doc': s.documentTitle,
          'page': s.page,
          'chunk_id': s.chunk.id,
          'similarity': s.similarity == null ? null : _round4(s.similarity!),
        },
    ],
    'source_hit': sourceHit,
    'answer': answer,
    'model_said_not_found': modelSaidNotFound,
    'citations': [
      for (final c in parsed.citations)
        {'n': c.number, 'doc': c.documentTitle, 'page': c.page},
    ],
    'cites_right_page': citesRightPage,
    'retrieval_ms': retrievalTime.inMilliseconds,
    'model_load_ms': modelLoadTime?.inMilliseconds,
    'ttft_ms': generation?.timeToFirstToken.inMilliseconds,
    'total_ms': generation?.total.inMilliseconds,
    'prompt_tokens': generation?.promptTokens,
    'output_tokens': generation?.outputTokens,
    'tokens_per_second': generation?.tokensPerSecond == null
        ? null
        : _round4(generation!.tokensPerSecond!),
    'error': error,
  };
}

/// Counts over a run, for METRICS.md. Grading by hand comes in task 4.2.
@immutable
class AnswerEvalSummary {
  const AnswerEvalSummary(this.results);

  final List<AnswerEvalResult> results;

  Iterable<AnswerEvalResult> get _answerable =>
      results.where((r) => r.question.answerable);
  Iterable<AnswerEvalResult> get _unanswerable =>
      results.where((r) => !r.question.answerable);
  Iterable<AnswerEvalResult> get _generated =>
      results.where((r) => r.generation != null);

  int _count(
    Iterable<AnswerEvalResult> rs,
    bool Function(AnswerEvalResult) f,
  ) => rs.where(f).length;

  double? _median(Iterable<num?> values) {
    final v = values.nonNulls;
    return v.isEmpty ? null : Perf.median(v);
  }

  Map<String, Object?> toJson() {
    final answerable = _answerable.toList();
    final answered = answerable.where((r) => !r.declined && r.error == null);
    return {
      'questions': results.length,
      'answerable': answerable.length,
      'unanswerable': _unanswerable.length,
      'errors': _count(results, (r) => r.error != null),
      'gate_refused_answerable': _count(answerable, (r) => r.refusedByGate),
      'gate_refused_unanswerable': _count(
        _unanswerable,
        (r) => r.refusedByGate,
      ),
      'model_not_found_answerable': _count(
        answerable,
        (r) => r.modelSaidNotFound,
      ),
      'model_not_found_unanswerable': _count(
        _unanswerable,
        (r) => r.modelSaidNotFound,
      ),
      'declined_unanswerable': _count(_unanswerable, (r) => r.declined),
      'answered_answerable': answered.length,
      'source_hit': _count(answerable, (r) => r.sourceHit ?? false),
      'answers_with_citation': _count(
        answered,
        (r) => r.parsed.citations.isNotEmpty,
      ),
      'cites_right_page': _count(answered, (r) => r.citesRightPage ?? false),
      'median_retrieval_ms': _median(
        results.map((r) => r.retrievalTime.inMilliseconds),
      ),
      'median_ttft_ms': _median(
        _generated.map((r) => r.generation!.timeToFirstToken.inMilliseconds),
      ),
      'median_total_ms': _median(
        _generated.map((r) => r.generation!.total.inMilliseconds),
      ),
      'median_tokens_per_second': _median(
        _generated.map((r) => r.generation!.tokensPerSecond),
      ),
      'median_prompt_tokens': _median(
        _generated.map((r) => r.generation!.promptTokens),
      ),
      'median_output_tokens': _median(
        _generated.map((r) => r.generation!.outputTokens),
      ),
    };
  }

  @override
  String toString() {
    final j = toJson();
    return 'answered=${j['answered_answerable']}/${j['answerable']} '
        'declined_unanswerable=${j['declined_unanswerable']}/'
        '${j['unanswerable']} source_hit=${j['source_hit']} '
        'cites_right_page=${j['cites_right_page']} '
        'ttft=${j['median_ttft_ms']}ms tok/s=${j['median_tokens_per_second']}';
  }
}

/// Answers every question in order and reports each result as it comes.
///
/// Failures are recorded in the result, not thrown, so one bad question
/// doesn't end a 25-minute run. Stops before the next question when
/// [isCancelled] returns true.
Future<List<AnswerEvalResult>> runAnswerEval(
  List<EvalQuestion> questions,
  EvalAnswerer answer, {
  FutureOr<void> Function(List<AnswerEvalResult> results)? onResult,
  bool Function()? isCancelled,
}) async {
  final results = <AnswerEvalResult>[];
  for (final q in questions) {
    if (isCancelled?.call() ?? false) break;
    results.add(await _answerOne(q, answer));
    Perf.log('answer eval ${q.id}: ${_logLine(results.last)}');
    await onResult?.call(List.unmodifiable(results));
  }
  return results;
}

Future<AnswerEvalResult> _answerOne(
  EvalQuestion q,
  EvalAnswerer answer,
) async {
  var refused = false;
  double? best;
  var retrieval = Duration.zero;
  var sources = const <RetrievedChunk>[];
  final text = StringBuffer();
  Duration? load;
  GenerationMetrics? generation;
  String? error;
  try {
    await for (final event in answer(q.question)) {
      switch (event) {
        case AnswerNotFound(:final message, :final bestSimilarity):
          refused = true;
          best = bestSimilarity;
          retrieval = event.retrievalTime;
          text.write(message);
        case AnswerSources(:final bestSimilarity, :final retrievalTime):
          best = bestSimilarity;
          retrieval = retrievalTime;
          sources = event.sources;
        case AnswerToken(text: final token):
          text.write(token);
        case AnswerDone(:final modelLoadTime, generation: final g):
          load = modelLoadTime;
          generation = g;
        case AnswerLoadingModel() || AnswerGenerating():
          break;
      }
    }
  } on AnswerException catch (e) {
    error = e.cause == null ? e.message : '${e.message} (${e.cause})';
  } on Object catch (e) {
    error = '$e';
  }
  return AnswerEvalResult(
    question: q,
    refusedByGate: refused,
    bestSimilarity: best,
    retrievalTime: retrieval,
    sources: sources,
    answer: text.toString(),
    modelLoadTime: load,
    generation: generation,
    error: error,
  );
}

String _logLine(AnswerEvalResult r) {
  if (r.error != null) return 'error ${r.error}';
  if (r.refusedByGate) return 'gate refused (${r.bestSimilarity})';
  final cites = r.parsed.citations.map((c) => c.number).join(',');
  return '${r.modelSaidNotFound ? 'model: not found' : 'answered'} '
      'hit=${r.sourceHit} cites=[$cites] right=${r.citesRightPage} '
      '${r.generation}';
}

double _round4(double x) => double.parse(x.toStringAsFixed(4));
