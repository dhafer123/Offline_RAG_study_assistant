import 'dart:async';

import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/answer_config.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// [AnswerService] whose events the test pushes by hand.
class FakeAnswerService implements AnswerService {
  final questions = <String>[];
  late StreamController<AnswerEvent> _events;
  bool cancelled = false;

  @override
  AnswerConfig get config => const AnswerConfig();

  @override
  Stream<AnswerEvent> answer(String question) {
    questions.add(question);
    cancelled = false;
    final events = _events = StreamController<AnswerEvent>(
      onCancel: () => cancelled = true,
    );
    return events.stream;
  }

  void emit(AnswerEvent event) => _events.add(event);

  void fail(Object error) => _events.addError(error);

  Future<void> close() => _events.close();

  /// [AnswerSources] for [sources], as the real service builds them.
  static AnswerSources sourcesEvent(List<RetrievedChunk> sources) =>
      AnswerSources(
        prompt: AnswerPrompt(
          text: 'prompt',
          sources: sources,
          language: AnswerLanguage.english,
          estimatedTokens: 500,
          truncatedLast: false,
          droppedSources: 0,
        ),
        bestSimilarity: 0.5,
        retrievalTime: const Duration(seconds: 2),
      );

  static AnswerDone doneEvent(String text) => AnswerDone(
    text: text,
    modelLoadTime: Duration.zero,
    generation: const GenerationMetrics(
      timeToFirstToken: Duration(milliseconds: 18400),
      total: Duration(milliseconds: 26600),
      outputTokens: 64,
    ),
  );

  static RetrievedChunk chunk(int id, String doc, int page, String text) =>
      RetrievedChunk(
        chunk: Chunk(id: id, docId: 1, page: page, ordinal: id, text: text),
        documentTitle: doc,
        score: 0.5,
        similarity: 0.5,
      );
}
