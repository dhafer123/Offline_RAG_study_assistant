import 'dart:async';

import 'package:offline_study_assistant/core/ai/llm_engine.dart';

/// Scriptable [LlmEngine] for tests.
class FakeLlmEngine implements LlmEngine {
  FakeLlmEngine({
    this.tokens = const [],
    this.loadError,
    this.generateError,
    this.usage,
  });

  final List<String> tokens;
  final Exception? loadError;
  final Exception? generateError;

  /// Reported by [lastUsage] after a generation completes.
  final LlmUsage? usage;

  /// When set, [generate] streams from this controller instead of [tokens].
  StreamController<String>? manualStream;

  int loadCalls = 0;
  int unloadCalls = 0;
  final prompts = <String>[];
  bool generationCancelled = false;
  bool _loaded = false;
  LlmUsage? _lastUsage;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {
    loadCalls++;
    if (loadError case final error?) throw error;
    _loaded = true;
  }

  @override
  Stream<String> generate(String prompt) {
    prompts.add(prompt);
    _lastUsage = null;
    if (manualStream case final stream?) {
      stream.onCancel = () => generationCancelled = true;
      return stream.stream;
    }
    return _scripted();
  }

  /// Emits [tokens], then fails with [generateError] if set.
  Stream<String> _scripted() async* {
    for (final token in tokens) {
      yield token;
    }
    if (generateError case final error?) throw error;
    _lastUsage = usage;
  }

  @override
  Future<void> unload() async {
    unloadCalls++;
    _loaded = false;
  }

  @override
  LlmUsage? get lastUsage => _lastUsage;
}
