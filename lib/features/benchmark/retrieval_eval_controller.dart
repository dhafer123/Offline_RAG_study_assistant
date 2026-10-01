import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';
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
    this.mode = defaultRetrievalMode,
    this.status = RetrievalEvalStatus.idle,
    this.done = 0,
    this.total = 0,
    this.summary,
    this.results = const [],
    this.exportPath,
    this.errorMessage,
  });

  /// The retrieval method being (or last) evaluated.
  final RetrievalMode mode;
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
/// results as JSON (tasks 2.8 and 3.1).
@riverpod
class RetrievalEvalController extends _$RetrievalEvalController {
  @override
  RetrievalEvalState build() => const RetrievalEvalState();

  /// Picks the method the next run evaluates; clears the last results.
  void selectMode(RetrievalMode mode) {
    if (state.status == RetrievalEvalStatus.running) return;
    state = RetrievalEvalState(mode: mode);
  }

  Future<void> run() async {
    if (state.status == RetrievalEvalStatus.running) return;
    final mode = state.mode;
    state = RetrievalEvalState(
      mode: mode,
      status: RetrievalEvalStatus.running,
    );
    try {
      final questions = parseEvalQuestions(
        await ref.read(evalQuestionsSourceProvider.future),
      );
      if (!ref.mounted) return;
      state = RetrievalEvalState(
        mode: mode,
        status: RetrievalEvalStatus.running,
        total: questions.length,
      );

      // Load the model first so the first question's latency is comparable.
      if (mode != RetrievalMode.keyword) {
        await ref.read(embedderProvider).load();
      }
      final retrieval = ref.read(retrievalServiceProvider);
      final results = await runRetrievalEval(
        questions,
        (question, k) => retrieval.retrieve(question, k: k, mode: mode),
        onProgress: (done, total) {
          if (ref.mounted) {
            state = RetrievalEvalState(
              mode: mode,
              status: RetrievalEvalStatus.running,
              done: done,
              total: total,
            );
          }
        },
      );
      final summary = RetrievalEvalSummary.of(results);
      Perf.log('retrieval eval (${mode.name}): $summary');

      final docs = await ref.read(documentStoreProvider).listDocuments();
      final now = DateTime.now();
      final report = retrievalEvalReport(
        method: mode.name,
        createdAt: now,
        indexedDocuments: [for (final d in docs) d.title],
        results: results,
      );
      final path = await _export(report, mode, now);
      if (!ref.mounted) return;
      state = RetrievalEvalState(
        mode: mode,
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
        mode: mode,
        status: RetrievalEvalStatus.error,
        errorMessage: e is EmbedderException ? e.message : '$e',
      );
    }
  }

  Future<String> _export(
    Map<String, Object?> report,
    RetrievalMode mode,
    DateTime now,
  ) async {
    final dir = Directory(ref.read(exportDirectoryProvider));
    await dir.create(recursive: true);
    final stamp = now
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(RegExp('[-:]'), '')
        .replaceAll('T', '-');
    final file = File('${dir.path}/retrieval_${mode.name}_$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    return file.path;
  }
}
