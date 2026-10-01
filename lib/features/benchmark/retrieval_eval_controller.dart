import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'retrieval_eval_controller.g.dart';

/// Loads the bundled `eval/questions.json`. Tests override it.
@riverpod
Future<String> evalQuestionsSource(Ref ref) =>
    rootBundle.loadString('eval/questions.json');

enum RetrievalEvalStatus { idle, running, done, error }

@immutable
class RetrievalEvalState {
  const RetrievalEvalState({
    this.status = RetrievalEvalStatus.idle,
    this.done = 0,
    this.total = 0,
    this.summary,
    this.results = const [],
    this.exportPath,
    this.errorMessage,
  });

  final RetrievalEvalStatus status;
  final int done;
  final int total;
  final RetrievalEvalSummary? summary;
  final List<QuestionResult> results;

  /// Where the JSON report was written.
  final String? exportPath;
  final String? errorMessage;

  /// Answerable questions whose answer wasn't in the top k.
  List<QuestionResult> get misses => [
    for (final r in results)
      if (r.question.answerable && !r.foundWithin(summary?.k ?? defaultEvalK))
        r,
  ];
}

/// Runs every question of the eval set through retrieval and exports the
/// results as JSON (task 2.8).
@riverpod
class RetrievalEvalController extends _$RetrievalEvalController {
  /// Retrieval method recorded in the report; becomes configurable with
  /// hybrid search (task 3.1).
  static const method = 'vector';

  @override
  RetrievalEvalState build() => const RetrievalEvalState();

  Future<void> run() async {
    if (state.status == RetrievalEvalStatus.running) return;
    state = const RetrievalEvalState(status: RetrievalEvalStatus.running);
    try {
      final questions = parseEvalQuestions(
        await ref.read(evalQuestionsSourceProvider.future),
      );
      if (!ref.mounted) return;
      state = RetrievalEvalState(
        status: RetrievalEvalStatus.running,
        total: questions.length,
      );

      // Load the model first so the first question's latency is comparable.
      await ref.read(embedderProvider).load();
      final retrieval = ref.read(retrievalServiceProvider);
      final results = await runRetrievalEval(
        questions,
        (question, k) => retrieval.retrieve(question, k: k),
        onProgress: (done, total) {
          if (ref.mounted) {
            state = RetrievalEvalState(
              status: RetrievalEvalStatus.running,
              done: done,
              total: total,
            );
          }
        },
      );
      final summary = RetrievalEvalSummary.of(results);
      Perf.log('retrieval eval ($method): $summary');

      final docs = await ref.read(documentStoreProvider).listDocuments();
      final now = DateTime.now();
      final report = retrievalEvalReport(
        method: method,
        createdAt: now,
        indexedDocuments: [for (final d in docs) d.title],
        results: results,
      );
      final path = await _export(report, now);
      if (!ref.mounted) return;
      state = RetrievalEvalState(
        status: RetrievalEvalStatus.done,
        done: results.length,
        total: results.length,
        summary: summary,
        results: results,
        exportPath: path,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = RetrievalEvalState(
        status: RetrievalEvalStatus.error,
        errorMessage: e is EmbedderException ? e.message : '$e',
      );
    }
  }

  Future<String> _export(Map<String, Object?> report, DateTime now) async {
    final dir = Directory(ref.read(exportDirectoryProvider));
    await dir.create(recursive: true);
    final stamp = now
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(RegExp('[-:]'), '')
        .replaceAll('T', '-');
    final file = File('${dir.path}/retrieval_${method}_$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    return file.path;
  }
}
