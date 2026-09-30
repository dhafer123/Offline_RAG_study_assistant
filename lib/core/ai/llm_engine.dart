/// On-device text generation.
///
/// Implementations wrap a specific runtime (see `GemmaLlmEngine`); the rest of
/// the app only depends on this interface.
abstract interface class LlmEngine {
  bool get isLoaded;

  /// Loads the model into memory. Safe to call when already loaded.
  ///
  /// Throws [LlmException] if the model file is missing or fails to load.
  Future<void> load();

  /// Streams the answer to [prompt] token by token.
  ///
  /// Each call starts from an empty context. Cancelling the subscription stops
  /// generation. Emits an [LlmException] if the model is not loaded or
  /// generation fails.
  Stream<String> generate(String prompt);

  /// Frees the model's memory. Safe to call when not loaded.
  Future<void> unload();
}

class LlmException implements Exception {
  const LlmException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'LlmException: $message'
      : 'LlmException: $message ($cause)';
}
