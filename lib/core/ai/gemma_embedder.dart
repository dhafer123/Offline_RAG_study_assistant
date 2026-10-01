import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';

/// [Embedder] backed by EmbeddingGemma 300M through flutter_gemma (LiteRT).
///
/// flutter_gemma runs the model on its own background isolate, so embedding
/// doesn't block the UI.
class GemmaEmbedder implements Embedder {
  GemmaEmbedder({required String modelsDirectory})
    : _modelPath = '$modelsDirectory/$modelFileName',
      _tokenizerPath = '$modelsDirectory/$tokenizerFileName';

  /// The 512-token build: a 250-word chunk is ~330 tokens in English and ~400
  /// in French, so the 256-token build would cut chunks short. Inputs are
  /// padded or truncated to this length.
  static const modelFileName =
      'embeddinggemma-300M_seq512_mixed-precision.tflite';
  static const tokenizerFileName = 'sentencepiece.model';

  final String _modelPath;
  final String _tokenizerPath;
  EmbeddingModel? _model;
  Future<void>? _loading;

  @override
  int get dimension => 768;

  @override
  bool get isLoaded => _model != null;

  @override
  Future<void> load() {
    if (_model != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    for (final path in [_modelPath, _tokenizerPath]) {
      if (!File(path).existsSync()) {
        throw EmbedderException('Embedding model file not found at $path');
      }
    }
    try {
      await FlutterGemma.initialize();
      final model = await FlutterGemmaPlugin.instance.createEmbeddingModel(
        modelPath: _modelPath,
        tokenizerPath: _tokenizerPath,
        // Same reason as the LLM: the GPU path is OOM-killed on the 4 GB
        // test phone.
        preferredBackend: PreferredBackend.cpu,
      );
      final dim = await model.getDimension();
      if (dim != dimension) {
        await model.close();
        throw EmbedderException('Expected $dimension dimensions, got $dim');
      }
      _model = model;
    } on EmbedderException {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        EmbedderException('Failed to load the embedding model', cause: e),
        st,
      );
    }
  }

  @override
  Future<List<double>> embedQuery(String text) =>
      _run(() => _loaded.generateEmbedding(text));

  @override
  Future<List<List<double>>> embedDocuments(
    List<String> texts, {
    void Function(int done, int total)? onProgress,
  }) => _run(() async {
    final model = _loaded;
    // One call per text (the worker processes them one by one anyway), so
    // progress can be reported.
    final vectors = <List<double>>[];
    for (final text in texts) {
      vectors.add(
        await model.generateEmbedding(
          text,
          taskType: TaskType.retrievalDocument,
        ),
      );
      onProgress?.call(vectors.length, texts.length);
    }
    return vectors;
  });

  @override
  Future<void> unload() async {
    final model = _model;
    _model = null;
    await model?.close();
  }

  EmbeddingModel get _loaded =>
      _model ?? (throw const EmbedderException('Embedder is not loaded'));

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on EmbedderException {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        EmbedderException('Embedding failed', cause: e),
        st,
      );
    }
  }
}
