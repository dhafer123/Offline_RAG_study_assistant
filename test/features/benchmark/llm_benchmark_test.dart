import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/features/benchmark/llm_benchmark.dart';

import '../../helpers/fake_llm_engine.dart';

void main() {
  test('reloads the model and generates once per run', () async {
    final engine = FakeLlmEngine(tokens: ['a', 'b', 'c']);
    final seen = <int>[];

    final result = await LlmBenchmark(
      engine,
      peakRssBytes: () => 512 * 1024 * 1024,
    ).run(runs: 3, onRun: (i, _) => seen.add(i));

    expect(engine.unloadCalls, 3);
    expect(engine.loadCalls, 3);
    expect(engine.prompts, List.filled(3, LlmBenchmark.prompt));
    expect(seen, [0, 1, 2]);
    expect(result.runs, hasLength(3));
    expect(result.peakRssMb, 512);
  });

  test('keeps the full answer of every run', () async {
    final engine = FakeLlmEngine(tokens: ['Two ', 'stages.']);

    final result = await LlmBenchmark(engine).run(runs: 2);

    expect(result.runs.map((r) => r.answer), ['Two stages.', 'Two stages.']);
  });

  test('counts chunks when the engine reports no usage', () async {
    final engine = FakeLlmEngine(tokens: ['a', 'b', 'c']);

    final result = await LlmBenchmark(engine).run(runs: 1);

    expect(result.runs.single.generation.outputTokens, 3);
    expect(result.promptTokens, isNull);
  });

  test('prefers the token counts reported by the engine', () async {
    final engine = FakeLlmEngine(
      tokens: ['ab', 'cd'],
      usage: const LlmUsage(promptTokens: 120, outputTokens: 4),
    );

    final result = await LlmBenchmark(engine).run(runs: 2);

    expect(result.medianOutputTokens, 4);
    expect(result.promptTokens, 120);
  });

  test('stops early when cancelled', () async {
    final engine = FakeLlmEngine(tokens: ['a']);
    var done = 0;

    final result = await LlmBenchmark(engine).run(
      onRun: (_, _) => done++,
      isCancelled: () => done >= 2,
    );

    expect(result.runs, hasLength(2));
  });

  test('throws when cancelled before the first run', () {
    expect(
      LlmBenchmark(FakeLlmEngine()).run(isCancelled: () => true),
      throwsStateError,
    );
  });

  test('propagates load failures', () {
    final engine = FakeLlmEngine(loadError: const LlmException('missing'));

    expect(LlmBenchmark(engine).run(), throwsA(isA<LlmException>()));
  });
}
