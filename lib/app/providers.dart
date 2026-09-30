import 'package:offline_study_assistant/core/ai/gemma_llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// The model the app runs. Changing it replaces (and unloads) the engine.
@Riverpod(keepAlive: true)
class ActiveLlmModel extends _$ActiveLlmModel {
  @override
  LlmModelConfig build() => LlmModelConfig.gemma3Dev;

  void select(LlmModelConfig config) {
    // Same model: keep the loaded engine.
    if (config.modelPath == state.modelPath) return;
    state = config;
  }
}

@Riverpod(keepAlive: true)
LlmEngine llmEngine(Ref ref) {
  final engine = GemmaLlmEngine(ref.watch(activeLlmModelProvider));
  ref.onDispose(engine.unload);
  return engine;
}
