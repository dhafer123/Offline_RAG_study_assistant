import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';

/// [LlmEngine] backed by flutter_gemma (LiteRT-LM).
class GemmaLlmEngine implements LlmEngine {
  GemmaLlmEngine(this._config);

  final LlmModelConfig _config;
  InferenceModel? _model;
  Future<void>? _loading;

  @override
  bool get isLoaded => _model != null;

  @override
  Future<void> load() {
    if (_model != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    if (!File(_config.modelPath).existsSync()) {
      throw LlmException('Model file not found at ${_config.modelPath}');
    }
    try {
      await FlutterGemma.initialize();
      await FlutterGemma.installModel(
        modelType: switch (_config.family) {
          LlmModelFamily.gemma3 => ModelType.gemmaIt,
          LlmModelFamily.qwen3 => ModelType.qwen3,
        },
        fileType: ModelFileType.litertlm,
      ).fromFile(_config.modelPath).install();
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
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      yield* session.getResponseAsync().handleError(
        (Object e, StackTrace st) => Error.throwWithStackTrace(
          LlmException('Generation failed', cause: e),
          st,
        ),
      );
      finished = true;
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

  @override
  Future<void> unload() async {
    await _loading?.catchError((_) {});
    final model = _model;
    _model = null;
    await model?.close();
  }
}
