import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

RetrievedChunk source(int id, String text, {String doc = 'a.pdf', int? page}) =>
    RetrievedChunk(
      chunk: Chunk(id: id, docId: 1, page: page ?? id, ordinal: id, text: text),
      documentTitle: doc,
      score: 0.5,
      similarity: 0.5,
    );

/// A predictable counter for budget tests: one token per word.
int words(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

String nWords(String prefix, int n) =>
    List.generate(n, (i) => '$prefix$i').join(' ');

void main() {
  group('buildAnswerPrompt', () {
    test('numbers the sources in order with document and page', () {
      final prompt = buildAnswerPrompt('What is RAG?', [
        source(7, 'RAG retrieves passages.', doc: 'rag.pdf', page: 3),
        source(2, 'Embeddings are vectors.', doc: 'ai.pdf', page: 1),
      ]);

      expect(
        prompt.text,
        contains(
          'Sources:\n\n'
          '[1] rag.pdf, page 3\nRAG retrieves passages.\n\n'
          '[2] ai.pdf, page 1\nEmbeddings are vectors.\n\n'
          'Question: What is RAG?',
        ),
      );
      expect(prompt.text, endsWith('Question: What is RAG?'));
      expect([for (final s in prompt.sources) s.chunk.id], [7, 2]);
      expect(prompt.droppedSources, 0);
      expect(prompt.truncatedLast, isFalse);
    });

    test('states every rule', () {
      final text = buildAnswerPrompt('What is RAG?', [source(1, 'x')]).text;

      expect(text, contains('using only the numbered sources'));
      expect(text, contains('Do not add outside knowledge'));
      expect(text, contains('[1] or [2][3]'));
      expect(text, contains('Answer in English'));
      expect(
        text,
        contains(
          'do not contain the answer, reply only: '
          'Not found in your documents.',
        ),
      );
      // Instructions come first, the question last.
      expect(text.indexOf('Rules:'), lessThan(text.indexOf('Sources:')));
      expect(text.indexOf('Sources:'), lessThan(text.indexOf('Question:')));
    });

    test('answers a French question in French', () {
      final prompt = buildAnswerPrompt(
        'Quel moteur de jeu a été utilisé ?',
        [source(1, 'The game uses Godot 4.')],
      );

      expect(prompt.language, AnswerLanguage.french);
      expect(prompt.text, contains('Answer in French, even if the sources'));
      expect(
        prompt.text,
        contains('reply only: Introuvable dans vos documents.'),
      );
      expect(prompt.text, isNot(contains('Answer in English')));
    });

    test('puts each source and the question on one line', () {
      final prompt = buildAnswerPrompt('  What\n is   RAG? ', [
        source(1, 'Line one\nline two.\n\n  Next   paragraph.'),
      ]);

      expect(
        prompt.text,
        contains('[1] a.pdf, page 1\nLine one line two. Next paragraph.\n'),
      );
      expect(prompt.text, endsWith('Question: What is RAG?'));
    });

    test('rewrites reference markers in sources so they are not citations', () {
      final prompt = buildAnswerPrompt('Who is Burke?', [
        source(
          1,
          'Hybrid systems [12] combine methods [3, 4] and [1–2]. '
          'An array a[i] and [note] stay.',
        ),
      ]);

      expect(
        prompt.text,
        contains(
          'Hybrid systems (12) combine methods (3, 4) and (1–2). '
          'An array a[i] and [note] stay.',
        ),
      );
    });

    test('rejects an empty source list', () {
      expect(() => buildAnswerPrompt('Q?', const []), throwsArgumentError);
    });
  });

  group('token budget', () {
    final three = [
      source(1, nWords('a', 100)),
      source(2, nWords('b', 100)),
      source(3, nWords('c', 100)),
    ];
    final full = buildAnswerPrompt(
      'What?',
      three,
      budget: 1 << 20,
      countTokens: words,
    );

    test('keeps every source when they fit', () {
      final prompt = buildAnswerPrompt(
        'What?',
        three,
        budget: full.estimatedTokens,
        countTokens: words,
      );

      expect(prompt.sources, hasLength(3));
      expect(prompt.text, full.text);
      expect(prompt.estimatedTokens, full.estimatedTokens);
    });

    test('cuts the last source at a word boundary to fit', () {
      final budget = full.estimatedTokens - 30;
      final prompt = buildAnswerPrompt(
        'What?',
        three,
        budget: budget,
        countTokens: words,
      );

      expect(prompt.sources, hasLength(3));
      expect(prompt.truncatedLast, isTrue);
      expect(prompt.droppedSources, 0);
      expect(prompt.estimatedTokens, budget);
      expect(prompt.text, contains('${nWords('c', 70)}…\n\nQuestion: What?'));
      expect(prompt.text, contains(nWords('b', 100)));
    });

    test('drops a source when too little of it would fit', () {
      // Room for 40 words of the third source: below the 60-token minimum.
      final prompt = buildAnswerPrompt(
        'What?',
        three,
        budget: full.estimatedTokens - 60,
        countTokens: words,
      );

      expect([for (final s in prompt.sources) s.chunk.id], [1, 2]);
      expect(prompt.droppedSources, 1);
      expect(prompt.truncatedLast, isFalse);
      expect(prompt.text, isNot(contains('c0')));
      expect(prompt.estimatedTokens, lessThanOrEqualTo(full.estimatedTokens));
    });

    test('drops every source after the first one that does not fit', () {
      // The second source can't fit at all; the third, small one would, but
      // it ranks lower so it isn't moved up.
      final prompt = buildAnswerPrompt(
        'What?',
        [
          source(1, nWords('a', 100)),
          source(2, nWords('b', 100)),
          source(3, 'tiny'),
        ],
        budget: full.estimatedTokens - 200 + 10,
        countTokens: words,
      );

      expect([for (final s in prompt.sources) s.chunk.id], [1]);
      expect(prompt.droppedSources, 2);
    });

    test('never exceeds the budget', () {
      for (var budget = 200; budget <= full.estimatedTokens; budget += 7) {
        final prompt = buildAnswerPrompt(
          'What?',
          three,
          budget: budget,
          countTokens: words,
        );
        expect(prompt.estimatedTokens, lessThanOrEqualTo(budget));
        expect(words(prompt.text), prompt.estimatedTokens);
      }
    });

    test('throws when the question leaves no room for a source', () {
      expect(
        () => buildAnswerPrompt(
          nWords('q', 500),
          three,
          budget: 400,
          countTokens: words,
        ),
        throwsA(isA<PromptTooLongException>()),
      );
    });

    test('uses the token estimate by default', () {
      final prompt = buildAnswerPrompt('What?', three);

      expect(prompt.estimatedTokens, estimateTokens(prompt.text));
      expect(prompt.estimatedTokens, lessThanOrEqualTo(defaultPromptBudget));
    });
  });

  test('recognizes the not-found reply in both languages', () {
    expect(isNotFoundReply('Not found in your documents.'), isTrue);
    expect(isNotFoundReply('  not found in your documents '), isTrue);
    expect(isNotFoundReply('Introuvable dans vos documents.'), isTrue);
    expect(isNotFoundReply('Not found in your documents. [1]'), isTrue);
    expect(isNotFoundReply('Godot was chosen [1].'), isFalse);
    expect(
      isNotFoundReply('Not found in your documents, but Godot is used.'),
      isFalse,
    );
  });

  group('estimateTokens', () {
    test('counts a token per word, more for long words', () {
      expect(estimateTokens(''), 0);
      expect(estimateTokens('the cat'), 2);
      // "Introduction" has 12 letters: 1 + 11 ~/ 6 = 2.
      expect(estimateTokens('Introduction'), 2);
      expect(estimateTokens('matières générales'), 4);
    });

    test('counts every digit and punctuation mark', () {
      expect(estimateTokens('2.4.1'), 5);
      // l ' état , 2 0 2 6 !
      expect(estimateTokens("l'état, 2026 !"), 9);
    });
  });
}
