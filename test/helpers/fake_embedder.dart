import 'package:offline_study_assistant/core/ai/embedder.dart';

/// Deterministic [Embedder] for tests: a bag-of-words vector where each word
/// adds 1 to the bucket of its hash. Texts sharing words score higher.
class FakeEmbedder implements Embedder {
  FakeEmbedder({this.dimension = 64, this.loadError, this.failOnCall});

  @override
  final int dimension;

  final Exception? loadError;

  /// Throws on the n-th call to [embedDocuments] item (1-based), if set.
  final int? failOnCall;

  int loadCalls = 0;
  int documentCalls = 0;
  final queries = <String>[];
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {
    loadCalls++;
    if (loadError case final error?) throw error;
    _loaded = true;
  }

  @override
  Future<List<double>> embedQuery(String text) async {
    _checkLoaded();
    queries.add(text);
    return vectorFor(text);
  }

  @override
  Future<List<List<double>>> embedDocuments(
    List<String> texts, {
    void Function(int done, int total)? onProgress,
  }) async {
    _checkLoaded();
    final vectors = <List<double>>[];
    for (final text in texts) {
      documentCalls++;
      if (documentCalls == failOnCall) {
        throw const EmbedderException('fake failure');
      }
      vectors.add(vectorFor(text));
      onProgress?.call(vectors.length, texts.length);
    }
    return vectors;
  }

  @override
  Future<void> unload() async => _loaded = false;

  List<double> vectorFor(String text) {
    final v = List<double>.filled(dimension, 0);
    for (final word in RegExp(r'\w+').allMatches(text.toLowerCase())) {
      v[word[0].hashCode % dimension] += 1;
    }
    return v;
  }

  void _checkLoaded() {
    if (!_loaded) throw const EmbedderException('not loaded');
  }
}
