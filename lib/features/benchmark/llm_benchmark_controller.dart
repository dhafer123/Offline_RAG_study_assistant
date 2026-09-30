import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/features/benchmark/llm_benchmark.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_benchmark_controller.g.dart';

enum LlmBenchmarkStatus { idle, running, done, error }

@immutable
class LlmBenchmarkState {
  const LlmBenchmarkState({
    this.status = LlmBenchmarkStatus.idle,
    this.totalRuns = LlmBenchmarkController.defaultRuns,
    this.runs = const [],
    this.result,
    this.errorMessage,
  });

  final LlmBenchmarkStatus status;
  final int totalRuns;
  final List<LlmBenchmarkRun> runs;
  final LlmBenchmarkResult? result;
  final String? errorMessage;

  bool get isRunning => status == LlmBenchmarkStatus.running;
}

/// Runs [LlmBenchmark] from the benchmark screen (task 1.4).
@riverpod
class LlmBenchmarkController extends _$LlmBenchmarkController {
  static const defaultRuns = 10;

  bool _cancelled = false;

  @override
  LlmBenchmarkState build() => const LlmBenchmarkState();

  Future<void> run({int runs = defaultRuns}) async {
    if (state.isRunning) return;
    _cancelled = false;
    state = LlmBenchmarkState(
      status: LlmBenchmarkStatus.running,
      totalRuns: runs,
    );

    final benchmark = LlmBenchmark(ref.read(llmEngineProvider));
    try {
      final result = await benchmark.run(
        runs: runs,
        isCancelled: () => _cancelled || !ref.mounted,
        onRun: (_, run) {
          if (!ref.mounted) return;
          state = LlmBenchmarkState(
            status: LlmBenchmarkStatus.running,
            totalRuns: runs,
            runs: [...state.runs, run],
          );
        },
      );
      if (!ref.mounted) return;
      state = LlmBenchmarkState(
        status: LlmBenchmarkStatus.done,
        totalRuns: runs,
        runs: result.runs,
        result: result,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = LlmBenchmarkState(
        status: _cancelled ? LlmBenchmarkStatus.idle : LlmBenchmarkStatus.error,
        totalRuns: runs,
        runs: state.runs,
        errorMessage: _cancelled
            ? null
            : e is LlmException
            ? e.message
            : '$e',
      );
    }
  }

  /// Stops after the current run finishes.
  void cancel() => _cancelled = true;
}
