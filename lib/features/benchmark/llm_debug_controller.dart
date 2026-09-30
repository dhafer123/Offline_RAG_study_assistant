import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'llm_debug_controller.g.dart';

enum LlmDebugStatus { idle, loading, generating, done, error }

@immutable
class LlmDebugState {
  const LlmDebugState({
    this.status = LlmDebugStatus.idle,
    this.output = '',
    this.errorMessage,
  });

  final LlmDebugStatus status;
  final String output;
  final String? errorMessage;

  bool get isBusy =>
      status == LlmDebugStatus.loading || status == LlmDebugStatus.generating;

  LlmDebugState copyWith({
    LlmDebugStatus? status,
    String? output,
    String? errorMessage,
  }) {
    return LlmDebugState(
      status: status ?? this.status,
      output: output ?? this.output,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Loads the model and streams an answer to a fixed prompt (task 1.3).
@riverpod
class LlmDebugController extends _$LlmDebugController {
  static const prompt =
      'Explain in three sentences what retrieval-augmented generation is.';

  StreamSubscription<String>? _tokens;

  @override
  LlmDebugState build() {
    ref.onDispose(() => _tokens?.cancel());
    return const LlmDebugState();
  }

  /// Completes when the answer has finished streaming, failed, or was stopped.
  Future<void> run() async {
    if (state.isBusy) return;
    final engine = ref.read(llmEngineProvider);

    state = const LlmDebugState(status: LlmDebugStatus.loading);
    try {
      await engine.load();
    } on Object catch (e) {
      if (ref.mounted) state = _failed(e);
      return;
    }
    if (!ref.mounted) return;

    state = state.copyWith(status: LlmDebugStatus.generating);
    final finished = Completer<void>();
    _tokens = engine
        .generate(prompt)
        .listen(
          (token) => state = state.copyWith(output: state.output + token),
          onError: (Object e) {
            state = _failed(e);
            finished.complete();
          },
          onDone: () {
            state = state.copyWith(status: LlmDebugStatus.done);
            finished.complete();
          },
          cancelOnError: true,
        );
    await finished.future;
    _tokens = null;
  }

  Future<void> stop() async {
    final tokens = _tokens;
    if (tokens == null) return;
    _tokens = null;
    await tokens.cancel();
    state = state.copyWith(status: LlmDebugStatus.done);
  }

  LlmDebugState _failed(Object error) {
    return state.copyWith(
      status: LlmDebugStatus.error,
      errorMessage: error is LlmException ? error.message : '$error',
    );
  }
}
