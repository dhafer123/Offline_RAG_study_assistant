import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/features/benchmark/llm_debug_controller.dart';

import '../../helpers/fake_llm_engine.dart';

void main() {
  late FakeLlmEngine engine;
  late ProviderContainer container;

  ProviderContainer createContainer(FakeLlmEngine fake) {
    engine = fake;
    final c = ProviderContainer(
      overrides: [llmEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(c.dispose);
    // Keep the auto-dispose controller alive for the whole test.
    c.listen(llmDebugControllerProvider, (_, _) {});
    return c;
  }

  LlmDebugState read() => container.read(llmDebugControllerProvider);
  LlmDebugController notifier() =>
      container.read(llmDebugControllerProvider.notifier);

  test('starts idle', () {
    container = createContainer(FakeLlmEngine());

    expect(read().status, LlmDebugStatus.idle);
    expect(read().output, isEmpty);
  });

  test('loads the model and streams the answer', () async {
    container = createContainer(
      FakeLlmEngine(tokens: ['Hello', ', ', 'world']),
    );

    await notifier().run();

    expect(engine.loadCalls, 1);
    expect(engine.prompts, [LlmDebugController.prompt]);
    expect(read().status, LlmDebugStatus.done);
    expect(read().output, 'Hello, world');
  });

  test('reports a load failure without generating', () async {
    container = createContainer(
      FakeLlmEngine(loadError: const LlmException('Model file not found')),
    );

    await notifier().run();

    expect(read().status, LlmDebugStatus.error);
    expect(read().errorMessage, 'Model file not found');
    expect(engine.prompts, isEmpty);
  });

  test('reports a generation failure and keeps partial output', () async {
    container = createContainer(
      FakeLlmEngine(
        tokens: ['partial'],
        generateError: const LlmException('Generation failed'),
      ),
    );

    await notifier().run();

    expect(read().status, LlmDebugStatus.error);
    expect(read().errorMessage, 'Generation failed');
    expect(read().output, 'partial');
  });

  test('stop cancels the stream and keeps the output so far', () async {
    container = createContainer(FakeLlmEngine());
    final stream = engine.manualStream = StreamController<String>();

    final running = notifier().run();
    await pumpEventQueue();
    expect(read().status, LlmDebugStatus.generating);

    stream.add('first');
    await pumpEventQueue();
    await notifier().stop();

    expect(engine.generationCancelled, isTrue);
    expect(read().status, LlmDebugStatus.done);
    expect(read().output, 'first');
    await stream.close();
    await running.timeout(const Duration(seconds: 1), onTimeout: () {});
  });

  test('ignores run while busy', () async {
    container = createContainer(FakeLlmEngine());
    final stream = engine.manualStream = StreamController<String>();

    unawaited(notifier().run());
    await pumpEventQueue();
    await notifier().run();

    expect(engine.loadCalls, 1);
    await stream.close();
  });
}
