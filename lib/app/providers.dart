import 'package:offline_study_assistant/core/ai/gemma_llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
LlmModelConfig llmModelConfig(Ref ref) => LlmModelConfig.gemma3Dev;

@Riverpod(keepAlive: true)
LlmEngine llmEngine(Ref ref) {
  final engine = GemmaLlmEngine(ref.watch(llmModelConfigProvider));
  ref.onDispose(engine.unload);
  return engine;
}
