import 'package:flutter/foundation.dart';

enum LlmModelFamily { gemma3, qwen3 }

enum LlmBackend { cpu, gpu }

@immutable
class LlmModelConfig {
  const LlmModelConfig({
    required this.fileName,
    required this.name,
    this.family = LlmModelFamily.gemma3,
    this.backend = LlmBackend.cpu,
    this.maxTokens = 4096,
    this.temperature = 0.2,
    this.topK = 40,
    this.randomSeed = 1,
  });

  /// Name of the `.litertlm` file in the app's models directory.
  final String fileName;

  /// Short human-readable name, e.g. for the benchmark screen.
  final String name;
  final LlmModelFamily family;
  final LlmBackend backend;

  /// Context size (prompt + answer), in tokens.
  final int maxTokens;
  final double temperature;
  final int topK;
  final int randomSeed;

  static const gemma3FileName =
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  /// Gemma 3 1B int4: the app's model, downloaded by the ModelManager.
  static const gemma3 = LlmModelConfig(
    fileName: gemma3FileName,
    name: 'Gemma 3 1B',
  );

  /// Qwen3 0.6B, dynamic INT8 weights: the fallback compared in task 1.5.
  /// Not downloaded by the app; push it by hand to benchmark it.
  static const qwen3 = LlmModelConfig(
    fileName: 'Qwen3-0.6B.litertlm',
    name: 'Qwen3 0.6B int8',
    family: LlmModelFamily.qwen3,
  );

  static const List<LlmModelConfig> benchmarkModels = [gemma3, qwen3];
}
