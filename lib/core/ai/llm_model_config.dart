import 'package:flutter/foundation.dart';

enum LlmModelFamily { gemma3, qwen3 }

enum LlmBackend { cpu, gpu }

@immutable
class LlmModelConfig {
  const LlmModelConfig({
    required this.modelPath,
    required this.name,
    this.family = LlmModelFamily.gemma3,
    this.backend = LlmBackend.cpu,
    this.maxTokens = 4096,
    this.temperature = 0.2,
    this.topK = 40,
    this.randomSeed = 1,
  });

  /// Absolute path to a `.litertlm` model file on the device.
  final String modelPath;

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

  /// The app's internal files dir (always readable by the app). Filled with
  /// `adb shell run-as` during development; temporary until the ModelManager
  /// (task 1.6) downloads the model itself.
  static const devModelDir =
      '/data/user/0/com.dhafer.offline_study_assistant/files/models';

  static const qwen3FileName = 'Qwen3-0.6B.litertlm';

  /// Gemma 3 1B int4, pushed to [devModelDir] during development.
  static const gemma3Dev = LlmModelConfig(
    modelPath: '$devModelDir/$gemma3FileName',
    name: 'Gemma 3 1B',
  );

  /// Qwen3 0.6B, dynamic INT8 weights: the fallback candidate (task 1.5).
  static const qwen3Dev = LlmModelConfig(
    modelPath: '$devModelDir/$qwen3FileName',
    name: 'Qwen3 0.6B int8',
    family: LlmModelFamily.qwen3,
  );

  static const List<LlmModelConfig> devModels = [
    gemma3Dev,
    qwen3Dev,
  ];
}
