/// Turns text into vectors for semantic search.
///
/// Implementations wrap a specific runtime (see `GemmaEmbedder`); the rest of
/// the app only depends on this interface. Queries and documents are embedded
/// differently because retrieval models are trained with a different prefix
/// for each side.
abstract interface class Embedder {
  /// Length of every vector this embedder returns.
  int get dimension;

  bool get isLoaded;

  /// Loads the model. Safe to call when already loaded.
  ///
  /// Throws [EmbedderException] if the model files are missing or fail to load.
  Future<void> load();

  /// Embeds a search query (the user's question).
  Future<List<double>> embedQuery(String text);

  /// Embeds chunks to index, in order. [onProgress] is called after each one
  /// with the number done and the total.
  Future<List<List<double>>> embedDocuments(
    List<String> texts, {
    void Function(int done, int total)? onProgress,
  });

  /// Frees the model's memory. Safe to call when not loaded.
  Future<void> unload();
}

class EmbedderException implements Exception {
  const EmbedderException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'EmbedderException: $message'
      : 'EmbedderException: $message ($cause)';
}
