import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/features/benchmark/llm_benchmark_controller.dart';

import '../../helpers/fake_llm_engine.dart';

void main() {
  ProviderContainer createContainer(FakeLlmEngine engine) {
    final c = ProviderContainer(
      overrides: [llmEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(c.dispose);
    // Keep the auto-dispose controller alive for the whole test.
    c.listen(llmBenchmarkControllerProvider, (_, _) {});
    return c;
  }

  test('runs the benchmark and exposes the result', () async {
    final engine = FakeLlmEngine(tokens: ['a', 'b']);
    final container = createContainer(engine);

    await container.read(llmBenchmarkControllerProvider.notifier).run(runs: 3);

    final state = container.read(llmBenchmarkControllerProvider);
    expect(state.status, LlmBenchmarkStatus.done);
    expect(state.runs, hasLength(3));
    expect(state.result?.runs, hasLength(3));
    expect(engine.loadCalls, 3);
  });

  test('reports a load failure', () async {
    final container = createContainer(
      FakeLlmEngine(loadError: const LlmException('Model file not found')),
    );

    await container.read(llmBenchmarkControllerProvider.notifier).run();

    final state = container.read(llmBenchmarkControllerProvider);
    expect(state.status, LlmBenchmarkStatus.error);
    expect(state.errorMessage, 'Model file not found');
    expect(state.result, isNull);
  });
}
