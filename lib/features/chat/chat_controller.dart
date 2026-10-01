import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/citation_parser.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_controller.g.dart';

/// Where one question is in the answering pipeline.
enum ExchangePhase {
  /// Embedding the question and searching the index.
  searching,

  /// Loading the LLM before the first answer.
  loadingModel,

  /// Prefill, then streaming tokens.
  generating,

  /// The answer is complete.
  done,

  /// The gate refused the question; the LLM wasn't called.
  notFound,

  /// The user pressed stop; [ChatExchange.answer] holds what came so far.
  stopped,

  /// Something failed; see [ChatExchange.errorMessage].
  error,
}

/// One question and its answer.
@immutable
class ChatExchange {
  const ChatExchange({
    required this.question,
    this.phase = ExchangePhase.searching,
    this.answer = '',
    this.sources = const [],
    this.errorMessage,
    this.generation,
  });

  final String question;
  final ExchangePhase phase;

  /// The model's raw answer (with `[n]` markers), or the "not found" message.
  final String answer;

  /// The sources given to the model; `[n]` is `sources[n - 1]`.
  final List<RetrievedChunk> sources;
  final String? errorMessage;

  /// Timings, once the answer is complete.
  final GenerationMetrics? generation;

  bool get isActive =>
      phase == ExchangePhase.searching ||
      phase == ExchangePhase.loadingModel ||
      phase == ExchangePhase.generating;

  /// The answer split into text and citations. While generating, a marker
  /// that isn't closed yet is hidden.
  ParsedAnswer get parsed => parseCitations(
    answer,
    sources,
    streaming: phase == ExchangePhase.generating,
  );

  ChatExchange copyWith({
    ExchangePhase? phase,
    String? answer,
    List<RetrievedChunk>? sources,
    String? errorMessage,
    GenerationMetrics? generation,
  }) => ChatExchange(
    question: question,
    phase: phase ?? this.phase,
    answer: answer ?? this.answer,
    sources: sources ?? this.sources,
    errorMessage: errorMessage ?? this.errorMessage,
    generation: generation ?? this.generation,
  );
}

@immutable
class ChatState {
  const ChatState({this.exchanges = const []});

  /// Oldest first. Questions are independent: no history goes to the model.
  final List<ChatExchange> exchanges;

  bool get isBusy => exchanges.isNotEmpty && exchanges.last.isActive;
}

/// The chat session: asks questions one at a time through [AnswerService].
///
/// Kept alive for the app's lifetime, so going back to the Library doesn't
/// lose the conversation or cancel an answer being written.
@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  StreamSubscription<AnswerEvent>? _answer;

  /// Completes [ask] when the answer ends, fails or is stopped.
  Completer<void>? _finished;

  @override
  ChatState build() {
    ref.onDispose(() => _answer?.cancel());
    return const ChatState();
  }

  /// Starts answering [question]. Ignored while an answer is in progress or
  /// when the question is blank. Completes when the answer is finished,
  /// stopped or failed.
  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.isBusy) return;
    state = ChatState(
      exchanges: [
        ...state.exchanges,
        ChatExchange(question: q),
      ],
    );

    final finished = _finished = Completer<void>();
    _answer = ref
        .read(answerServiceProvider)
        .answer(q)
        .listen(
          _onEvent,
          onError: (Object e) {
            _updateLast(
              (x) => x.copyWith(
                phase: ExchangePhase.error,
                errorMessage: e is AnswerException
                    ? e.message
                    : 'Something went wrong while answering.',
              ),
            );
            Perf.log('chat answer failed: $e');
            if (!finished.isCompleted) finished.complete();
          },
          onDone: () {
            if (!finished.isCompleted) finished.complete();
          },
          cancelOnError: true,
        );
    await finished.future;
    if (identical(_finished, finished)) {
      _answer = null;
      _finished = null;
    }
  }

  /// Stops the answer being generated, keeping what was written so far.
  Future<void> stop() async {
    final answer = _answer;
    if (answer == null || !state.isBusy) return;
    _answer = null;
    _updateLast((x) => x.copyWith(phase: ExchangePhase.stopped));
    await answer.cancel();
    final finished = _finished;
    _finished = null;
    if (finished != null && !finished.isCompleted) finished.complete();
  }

  void _onEvent(AnswerEvent event) {
    _updateLast(
      (x) => switch (event) {
        AnswerNotFound(:final message) => x.copyWith(
          phase: ExchangePhase.notFound,
          answer: message,
        ),
        AnswerSources(:final sources) => x.copyWith(
          phase: ExchangePhase.generating,
          sources: sources,
        ),
        AnswerLoadingModel() => x.copyWith(phase: ExchangePhase.loadingModel),
        AnswerGenerating() => x.copyWith(phase: ExchangePhase.generating),
        AnswerToken(:final text) => x.copyWith(
          phase: ExchangePhase.generating,
          answer: x.answer + text,
        ),
        AnswerDone(:final generation) => x.copyWith(
          phase: ExchangePhase.done,
          generation: generation,
        ),
      },
    );
  }

  void _updateLast(ChatExchange Function(ChatExchange) update) {
    if (!ref.mounted || state.exchanges.isEmpty) return;
    final exchanges = [...state.exchanges];
    exchanges.last = update(exchanges.last);
    state = ChatState(exchanges: exchanges);
  }
}
