import 'package:flutter/foundation.dart';

enum LlmModelFamily { gemma3, qwen3 }

enum LlmBackend { cpu, gpu }

@immutable
class LlmModelConfig {
  const LlmModelConfig({
    required this.modelPath,
    this.family = LlmModelFamily.gemma3,
    this.backend = LlmBackend.cpu,
    this.maxTokens = 4096,
    this.temperature = 0.2,
    this.topK = 40,
    this.randomSeed = 1,
  });

  /// Absolute path to a `.litertlm` model file on the device.
  final String modelPath;
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

  /// Gemma 3 1B int4, pushed to [devModelDir] during development.
  static const gemma3Dev = LlmModelConfig(
    modelPath: '$devModelDir/$gemma3FileName',
  );
}
