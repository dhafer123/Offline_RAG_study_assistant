import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// Prompt sizes to measure, in real Gemma tokens: just below and just above
/// each prefill size the model file was exported with (32 … 1024, 2560).
const defaultSweepTargets = [
  200, 240, 300, 480, 560, 950, 1100, 1500, 2000, 2450, //
];

/// The estimate is ~1.1× the real count (docs/METRICS.md), so a target of
/// n real tokens is asked for with a budget of 1.1 n estimated tokens.
const _estimatePerRealToken = 1.1;

/// Asks for a short answer, so a run is mostly prefill.
const sweepQuestion = 'In one sentence, what is source [1] about?';

@immutable
class SweepRun {
  const SweepRun({
    required this.target,
    required this.estimatedTokens,
    required this.generation,
  });

  /// The real prompt size aimed for.
  final int target;
  final int estimatedTokens;
  final GenerationMetrics generation;

  /// Real prompt size reported by the runtime (includes the chat template).
  int? get promptTokens => generation.promptTokens;

  Map<String, Object?> toJson() => {
    'target': target,
    'estimated_tokens': estimatedTokens,
    'prompt_tokens': promptTokens,
    'ttft_ms': generation.timeToFirstToken.inMilliseconds,
    'total_ms': generation.total.inMilliseconds,
    'output_tokens': generation.outputTokens,
    'tokens_per_second': generation.tokensPerSecond,
  };
}

/// Builds a RAG prompt of about [target] real tokens from [chunks] with the
/// app's own prompt builder.
AnswerPrompt sweepPrompt(List<RetrievedChunk> chunks, int target) =>
    buildAnswerPrompt(
      sweepQuestion,
      chunks,
      budget: (target * _estimatePerRealToken).round(),
    );

/// Measures time to first token against prompt size (prefill cost).
///
/// The model stays loaded: one warm-up generation first, then `repeats`
/// runs per target, smallest first.
class PromptSweep {
  PromptSweep(this._engine, {StopwatchFactory stopwatch = Stopwatch.new})
    : _stopwatch = stopwatch;

  final LlmEngine _engine;
  final StopwatchFactory _stopwatch;

  /// Throws [LlmException] if loading or a generation fails, and
  /// [ArgumentError] if [chunks] is empty.
  Future<List<SweepRun>> run(
    List<RetrievedChunk> chunks, {
    List<int> targets = defaultSweepTargets,
    int repeats = 3,
    void Function(int done, int total, SweepRun run)? onRun,
    bool Function()? isCancelled,
  }) async {
    final prompts = <(int, AnswerPrompt)>[];
    for (final t in targets) {
      try {
        prompts.add((t, sweepPrompt(chunks, t)));
      } on PromptTooLongException {
        // Too small for the instructions plus a useful piece of a source.
        Perf.log('prompt sweep: skipping target $t (too small)');
      }
    }
    if (prompts.isEmpty) throw ArgumentError('No target fits a source');
    await _engine.load();
    await _generate(prompts.first.$2.text); // Warm-up, not recorded.

    final runs = <SweepRun>[];
    final total = prompts.length * repeats;
    for (final (target, prompt) in prompts) {
      for (var i = 0; i < repeats; i++) {
        if (isCancelled?.call() ?? false) return runs;
        final run = SweepRun(
          target: target,
          estimatedTokens: prompt.estimatedTokens,
          generation: await _generate(prompt.text),
        );
        runs.add(run);
        Perf.log(
          'prompt sweep target=$target est=${prompt.estimatedTokens} '
          '${run.generation}',
        );
        onRun?.call(runs.length, total, run);
      }
    }
    return runs;
  }

  Future<GenerationMetrics> _generate(String prompt) async {
    final timer = GenerationTimer(stopwatch: _stopwatch)..start();
    await for (final _ in _engine.generate(prompt)) {
      timer.onChunk();
    }
    final usage = _engine.lastUsage;
    return timer.finish(
      outputTokens: usage?.outputTokens,
      promptTokens: usage?.promptTokens,
    );
  }
}
