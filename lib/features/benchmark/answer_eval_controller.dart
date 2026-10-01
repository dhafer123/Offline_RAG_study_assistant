import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/benchmark/answer_eval.dart';
import 'package:offline_study_assistant/features/benchmark/eval_export.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'answer_eval_controller.g.dart';

enum AnswerEvalStatus { idle, running, done, cancelled, error }

@immutable
class AnswerEvalState {
  const AnswerEvalState({
    this.status = AnswerEvalStatus.idle,
    this.total = 0,
    this.results = const [],
    this.exportPath,
    this.errorMessage,
  });

  final AnswerEvalStatus status;
  final int total;
  final List<AnswerEvalResult> results;

  /// Where the JSON report is written (rewritten after every question).
  final String? exportPath;
  final String? errorMessage;

  bool get isRunning => status == AnswerEvalStatus.running;

  AnswerEvalSummary get summary => AnswerEvalSummary(results);

  AnswerEvalState copyWith({
    AnswerEvalStatus? status,
    List<AnswerEvalResult>? results,
    String? exportPath,
    String? errorMessage,
  }) => AnswerEvalState(
    status: status ?? this.status,
    total: total,
    results: results ?? this.results,
    exportPath: exportPath ?? this.exportPath,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Runs all eval questions through the full answering pipeline and exports
/// answers, citations and timings as JSON (task 4.1).
///
/// Kept alive: a run takes about half an hour, and leaving the screen
/// shouldn't stop it.
@Riverpod(keepAlive: true)
class AnswerEvalController extends _$AnswerEvalController {
  bool _cancelled = false;

  @override
  AnswerEvalState build() => const AnswerEvalState();

  Future<void> run() async {
    if (state.isRunning) return;
    _cancelled = false;
    try {
      final questions = parseEvalQuestions(
        await ref.read(evalQuestionsSourceProvider.future),
      );
      final created = DateTime.now();
      final fileName = reportFileName('answers', created);
      final docs = await ref.read(documentStoreProvider).listDocuments();
      final config = ref.read(answerConfigProvider);
      final service = ref.read(answerServiceProvider);
      state = AnswerEvalState(
        status: AnswerEvalStatus.running,
        total: questions.length,
      );

      Future<String> export(List<AnswerEvalResult> results) => writeReport(
        ref.read(exportDirectoryProvider),
        fileName,
        {
          'created': created.toUtc().toIso8601String(),
          'model': ref.read(activeLlmModelProvider).name,
          'config': {
            'similarity_threshold': config.similarityThreshold,
            'top_k': config.topK,
            'prompt_budget': config.promptBudget,
          },
          'indexed_documents': [for (final d in docs) d.title],
          'complete': results.length == questions.length,
          'summary': AnswerEvalSummary(results).toJson(),
          'results': [for (final r in results) r.toJson()],
        },
      );

      final results = await runAnswerEval(
        questions,
        service.answer,
        isCancelled: () => _cancelled || !ref.mounted,
        onResult: (results) async {
          // Saved after every question, so a killed app loses nothing.
          final path = await export(results);
          if (ref.mounted) {
            state = state.copyWith(results: results, exportPath: path);
          }
        },
      );
      final path = await export(results);
      Perf.log('answer eval: ${AnswerEvalSummary(results)}');
      if (!ref.mounted) return;
      state = state.copyWith(
        status: _cancelled ? AnswerEvalStatus.cancelled : AnswerEvalStatus.done,
        results: results,
        exportPath: path,
      );
    } on Object catch (e) {
      Perf.log('answer eval failed: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AnswerEvalStatus.error,
        errorMessage: '$e',
      );
    }
  }

  /// Stops after the current question.
  void cancel() => _cancelled = true;
}
