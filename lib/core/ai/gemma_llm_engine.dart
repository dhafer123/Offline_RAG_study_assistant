import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';

/// [LlmEngine] backed by flutter_gemma (LiteRT-LM).
class GemmaLlmEngine implements LlmEngine {
  GemmaLlmEngine(this._config, {required String modelPath})
    : _modelPath = modelPath;

  final LlmModelConfig _config;

  /// Absolute path to the config's `.litertlm` file.
  final String _modelPath;
  InferenceModel? _model;
  Future<void>? _loading;
  LlmUsage? _lastUsage;

  @override
  bool get isLoaded => _model != null;

  @override
  Future<void> load() {
    if (_model != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    if (!File(_modelPath).existsSync()) {
      throw LlmException('Model file not found at $_modelPath');
    }
    try {
      await FlutterGemma.initialize();
      await FlutterGemma.installModel(
        modelType: switch (_config.family) {
          LlmModelFamily.gemma3 => ModelType.gemmaIt,
          LlmModelFamily.qwen3 => ModelType.qwen3,
        },
        fileType: ModelFileType.litertlm,
      ).fromFile(_modelPath).install();
      _model = await FlutterGemma.getActiveModel(
        maxTokens: _config.maxTokens,
        preferredBackend: switch (_config.backend) {
          LlmBackend.cpu => PreferredBackend.cpu,
          LlmBackend.gpu => PreferredBackend.gpu,
        },
      );
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        LlmException('Failed to load the model', cause: e),
        st,
      );
    }
  }

  @override
  Stream<String> generate(String prompt) async* {
    final model = _model;
    if (model == null) throw const LlmException('Model is not loaded');
    _lastUsage = null;

    final InferenceModelSession session;
    try {
      // A fresh session per prompt: RAG questions don't share history.
      session = await model.createSession(
        temperature: _config.temperature,
        topK: _config.topK,
        randomSeed: _config.randomSeed,
      );
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        LlmException('Failed to start generation', cause: e),
        st,
      );
    }

    // `finally` also runs when the listener cancels mid-stream.
    var finished = false;
    try {
      await session.addQueryChunk(
        Message.text(text: _withModelDirectives(prompt), isUser: true),
      );
      yield* session.getResponseAsync().handleError(
        (Object e, StackTrace st) => Error.throwWithStackTrace(
          LlmException('Generation failed', cause: e),
          st,
        ),
      );
      finished = true;
      _lastUsage = _usageOf(session);
    } finally {
      if (!finished) {
        try {
          await session.stopGeneration();
        } on Object {
          // Nothing running to stop.
        }
      }
      await session.close();
    }
  }

  /// Qwen3's chat template "thinks" (`<think>…</think>`) unless the user turn
  /// ends with `/no_think`. flutter_gemma only adds it in `InferenceChat`,
  /// not on the raw session used here.
  String _withModelDirectives(String prompt) => switch (_config.family) {
    LlmModelFamily.gemma3 => prompt,
    LlmModelFamily.qwen3 => '$prompt /no_think',
  };

  @override
  LlmUsage? get lastUsage => _lastUsage;

  /// Real token counts from LiteRT-LM's benchmark info (read before closing).
  static LlmUsage? _usageOf(InferenceModelSession session) {
    try {
      final metrics = session.getSessionMetrics();
      if (metrics.outputTokens <= 0) return null;
      return LlmUsage(
        promptTokens: metrics.inputTokens,
        outputTokens: metrics.outputTokens,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> unload() async {
    await _loading?.catchError((_) {});
    final model = _model;
    _model = null;
    await model?.close();
  }
}
