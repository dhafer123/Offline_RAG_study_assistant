import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/benchmark/eval_export.dart';
import 'package:offline_study_assistant/features/benchmark/prompt_sweep.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prompt_sweep_controller.g.dart';

enum PromptSweepStatus { idle, running, done, error }

@immutable
class PromptSweepState {
  const PromptSweepState({
    this.status = PromptSweepStatus.idle,
    this.done = 0,
    this.total = 0,
    this.runs = const [],
    this.exportPath,
    this.errorMessage,
  });

  final PromptSweepStatus status;
  final int done;
  final int total;
  final List<SweepRun> runs;
  final String? exportPath;
  final String? errorMessage;

  bool get isRunning => status == PromptSweepStatus.running;

  /// Median time to first token per target, smallest first.
  List<({int target, int? promptTokens, double ttftSeconds})> get medians {
    final byTarget = <int, List<SweepRun>>{};
    for (final r in runs) {
      byTarget.putIfAbsent(r.target, () => []).add(r);
    }
    return [
      for (final MapEntry(key: target, value: rs) in byTarget.entries)
        (
          target: target,
          promptTokens: rs.first.promptTokens,
          ttftSeconds:
              Perf.median(
                rs.map((r) => r.generation.timeToFirstToken.inMicroseconds),
              ) /
              1e6,
        ),
    ];
  }
}

/// Measures time to first token against prompt size on the device, using
/// the indexed chunks as source text.
@riverpod
class PromptSweepController extends _$PromptSweepController {
  bool _cancelled = false;

  @override
  PromptSweepState build() => const PromptSweepState();

  Future<void> run({int repeats = 3}) async {
    if (state.isRunning) return;
    _cancelled = false;
    state = const PromptSweepState(status: PromptSweepStatus.running);
    try {
      final chunks = await _sourceChunks();
      if (chunks.isEmpty) {
        throw StateError('Index at least one document first.');
      }
      final runs = await PromptSweep(ref.read(llmEngineProvider)).run(
        chunks,
        repeats: repeats,
        isCancelled: () => _cancelled || !ref.mounted,
        onRun: (done, total, run) {
          if (!ref.mounted) return;
          state = PromptSweepState(
            status: PromptSweepStatus.running,
            done: done,
            total: total,
            runs: [...state.runs, run],
          );
        },
      );
      final path = await _export(runs);
      if (!ref.mounted) return;
      state = PromptSweepState(
        status: PromptSweepStatus.done,
        done: runs.length,
        total: runs.length,
        runs: runs,
        exportPath: path,
      );
    } on Object catch (e) {
      Perf.log('prompt sweep failed: $e');
      if (!ref.mounted) return;
      state = PromptSweepState(
        status: PromptSweepStatus.error,
        runs: state.runs,
        errorMessage: e is LlmException ? e.message : '$e',
      );
    }
  }

  /// Stops after the current run.
  void cancel() => _cancelled = true;

  /// Every chunk of every ready document, in document order: enough text
  /// for the largest prompt.
  Future<List<RetrievedChunk>> _sourceChunks() async {
    final store = ref.read(documentStoreProvider);
    final chunks = <RetrievedChunk>[];
    for (final doc in await store.listDocuments()) {
      if (doc.status != DocumentStatus.ready) continue;
      for (final chunk in await store.chunksForDocument(doc.id)) {
        chunks.add(
          RetrievedChunk(chunk: chunk, documentTitle: doc.title, score: 0),
        );
      }
    }
    return chunks;
  }

  Future<String> _export(List<SweepRun> runs) {
    final now = DateTime.now();
    // Sizes and timings only: no prompt text, so it's safe to commit.
    return writeReport(
      ref.read(exportDirectoryProvider),
      reportFileName('prompt_sweep', now),
      {
        'created': now.toUtc().toIso8601String(),
        'model': ref.read(activeLlmModelProvider).name,
        'question': sweepQuestion,
        'runs': [for (final r in runs) r.toJson()],
      },
    );
  }
}
