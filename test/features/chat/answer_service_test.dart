import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/chat/answer_config.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_llm_engine.dart';

/// Returns fixed chunks, so the gate sees exact similarities.
class _FakeRetrieval implements RetrievalService {
  _FakeRetrieval(this.results, {this.error});

  final List<RetrievedChunk> results;
  final Exception? error;
  final calls = <(String, int)>[];

  @override
  Future<List<RetrievedChunk>> retrieve(
    String question, {
    int k = 5,
    RetrievalMode mode = defaultRetrievalMode,
  }) async {
    calls.add((question, k));
    if (error case final e?) throw e;
    return results.take(k).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RetrievedChunk chunk(int id, double? similarity, {String text = 'text'}) =>
    RetrievedChunk(
      chunk: Chunk(id: id, docId: 1, page: id, ordinal: id, text: text),
      documentTitle: 'game.pdf',
      score: similarity ?? 0.01,
      similarity: similarity,
    );

void main() {
  late FakeLlmEngine llm;

  setUp(() => llm = FakeLlmEngine(tokens: ['Godot ', '4 [1].']));

  AnswerService service(
    List<RetrievedChunk> results, {
    double threshold = 0.3,
    int topK = 5,
    Exception? retrievalError,
  }) => AnswerService(
    retrieval: _FakeRetrieval(results, error: retrievalError),
    llm: llm,
    config: AnswerConfig(similarityThreshold: threshold, topK: topK),
  );

  group('the "not found" gate', () {
    test('refuses a question below the threshold without the LLM', () async {
      final events = await service([
        chunk(1, 0.25),
        chunk(2, 0.2),
      ]).answer('Who introduced the transformer architecture?').toList();

      final notFound = events.single as AnswerNotFound;
      expect(notFound.message, 'Not found in your documents.');
      expect(notFound.language, AnswerLanguage.english);
      expect(notFound.bestSimilarity, 0.25);
      expect(llm.loadCalls, 0);
      expect(llm.prompts, isEmpty);
    });

    test('answers in French for a French question', () async {
      final events = await service([
        chunk(1, 0.1),
      ]).answer('Combien coûte une licence Unity ?').toList();

      final notFound = events.single as AnswerNotFound;
      expect(notFound.message, 'Introuvable dans vos documents.');
      expect(notFound.language, AnswerLanguage.french);
    });

    test('refuses when nothing is indexed', () async {
      final events = await service(const []).answer('What is RAG?').toList();

      expect((events.single as AnswerNotFound).bestSimilarity, isNull);
      expect(llm.prompts, isEmpty);
    });

    test('lets a question at or above the threshold through', () async {
      final atThreshold = await service([
        chunk(1, 0.3),
      ]).answer('What engine?').toList();

      expect(atThreshold.first, isA<AnswerSources>());
      expect(llm.prompts, hasLength(1));
    });

    test('reads the threshold from the config', () async {
      final results = [chunk(1, 0.45)];

      final strict = await service(
        results,
        threshold: 0.5,
      ).answer('What engine?').toList();
      final lenient = await service(
        results,
        threshold: 0.4,
      ).answer('What engine?').toList();

      expect(strict.single, isA<AnswerNotFound>());
      expect(lenient.first, isA<AnswerSources>());
    });

    test('uses the best similarity, skipping chunks without one', () {
      expect(bestSimilarity(const []), isNull);
      expect(bestSimilarity([chunk(1, null)]), isNull);
      expect(
        bestSimilarity([chunk(1, null), chunk(2, 0.4), chunk(3, 0.6)]),
        0.6,
      );
    });
  });

  group('answering', () {
    test('streams sources, then tokens, then the full answer', () async {
      llm = FakeLlmEngine(
        tokens: ['Godot ', '4 [1].'],
        usage: const LlmUsage(promptTokens: 900, outputTokens: 4),
      );
      final events = await service([
        chunk(1, 0.55, text: 'The game is built with Godot 4.'),
        chunk(2, 0.4, text: 'The menu has a start button.'),
      ]).answer('Which engine does the game use?').toList();

      final sources = events.first as AnswerSources;
      expect([for (final s in sources.sources) s.chunk.id], [1, 2]);
      expect(sources.bestSimilarity, 0.55);
      expect(
        [for (final e in events.whereType<AnswerToken>()) e.text],
        ['Godot ', '4 [1].'],
      );
      final done = events.last as AnswerDone;
      expect(done.text, 'Godot 4 [1].');
      expect(done.generation.outputTokens, 4);
      expect(done.generation.promptTokens, 900);
      expect(events, hasLength(4));
    });

    test('sends the built prompt to the LLM after loading it', () async {
      final events = await service([
        chunk(1, 0.55, text: 'The game is built with Godot 4.'),
      ]).answer('Which engine does the game use?').toList();

      final prompt = (events.first as AnswerSources).prompt;
      expect(llm.loadCalls, 1);
      expect(llm.prompts.single, prompt.text);
      expect(prompt.text, contains('[1] game.pdf, page 1\n'));
      expect(prompt.text, contains('The game is built with Godot 4.'));
      expect(prompt.text, endsWith('Which engine does the game use?'));
    });

    test('retrieves the configured number of chunks', () async {
      final retrieval = _FakeRetrieval([
        for (var i = 1; i <= 8; i++) chunk(i, 0.5),
      ]);
      final events = await AnswerService(
        retrieval: retrieval,
        llm: llm,
        config: const AnswerConfig(topK: 3),
      ).answer('Q?').toList();

      expect(retrieval.calls.single, ('Q?', 3));
      expect((events.first as AnswerSources).sources, hasLength(3));
    });

    test('cancelling the subscription stops generation', () async {
      llm = FakeLlmEngine()..manualStream = StreamController<String>();
      final tokens = <String>[];
      final firstToken = Completer<void>();
      final subscription =
          service([
            chunk(1, 0.5),
          ]).answer('What engine?').listen((e) {
            if (e is AnswerToken) {
              tokens.add(e.text);
              if (!firstToken.isCompleted) firstToken.complete();
            }
          });
      await pumpEventQueue();
      llm.manualStream!.add('Godot');
      await firstToken.future;

      await subscription.cancel();

      expect(tokens, ['Godot']);
      expect(llm.generationCancelled, isTrue);
    });
  });

  group('errors', () {
    test('a retrieval failure becomes an AnswerException', () {
      expect(
        service(
          const [],
          retrievalError: const EmbedderException('model missing'),
        ).answer('Q?').toList(),
        throwsA(
          isA<AnswerException>().having(
            (e) => e.message,
            'message',
            'Could not search your documents: model missing',
          ),
        ),
      );
    });

    test('a model that fails to load becomes an AnswerException', () async {
      llm = FakeLlmEngine(loadError: const LlmException('file not found'));
      final events = <AnswerEvent>[];

      await expectLater(
        service([chunk(1, 0.5)]).answer('Q?').forEach(events.add),
        throwsA(
          isA<AnswerException>().having(
            (e) => e.message,
            'message',
            'Could not load the language model: file not found',
          ),
        ),
      );
      // The sources were already shown when loading failed.
      expect(events.single, isA<AnswerSources>());
    });

    test('a generation failure becomes an AnswerException', () {
      llm = FakeLlmEngine(
        tokens: ['Half'],
        generateError: const LlmException('decode failed'),
      );

      expect(
        service([chunk(1, 0.5)]).answer('Q?').toList(),
        throwsA(
          isA<AnswerException>().having(
            (e) => e.message,
            'message',
            'The model failed while answering.',
          ),
        ),
      );
    });

    test('a question too long for the budget becomes an AnswerException', () {
      final events = AnswerService(
        retrieval: _FakeRetrieval([chunk(1, 0.5)]),
        llm: llm,
        config: const AnswerConfig(promptBudget: 50),
      ).answer('Q?').toList();

      expect(
        events,
        throwsA(
          isA<AnswerException>().having(
            (e) => e.message,
            'message',
            'This question is too long.',
          ),
        ),
      );
    });
  });
}
