import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [modelsDirectoryProvider.overrideWithValue('/models')],
    );
    addTearDown(container.dispose);
  });

  test('defaults to Gemma 3 1B', () {
    expect(container.read(activeLlmModelProvider), LlmModelConfig.gemma3);
  });

  test('selecting another model replaces the engine', () {
    final gemmaEngine = container.read(llmEngineProvider);

    container
        .read(activeLlmModelProvider.notifier)
        .select(LlmModelConfig.qwen3);

    expect(container.read(activeLlmModelProvider), LlmModelConfig.qwen3);
    expect(container.read(llmEngineProvider), isNot(same(gemmaEngine)));
  });

  test('selecting the active model keeps the engine', () {
    final engine = container.read(llmEngineProvider);

    container
        .read(activeLlmModelProvider.notifier)
        .select(LlmModelConfig.gemma3);

    expect(container.read(llmEngineProvider), same(engine));
  });
}
