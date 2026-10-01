import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/features/benchmark/answer_eval.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_answer_service.dart';

const _godot = EvalQuestion(
  id: 'q15',
  lang: 'en',
  question: 'Why Godot?',
  answerable: true,
  doc: 'ps_game__Copy_',
  pages: [27],
  answer: 'Flexibility.',
);
const _menu = EvalQuestion(
  id: 'q02',
  lang: 'en',
  question: 'What is in the menu?',
  answerable: true,
  doc: 'ps_game__Copy_',
  pages: [5],
);
const _unity = EvalQuestion(
  id: 'u01',
  lang: 'fr',
  question: 'Combien coûte Unity ?',
  answerable: false,
);
const _levels = EvalQuestion(
  id: 'u02',
  lang: 'en',
  question: 'How many levels?',
  answerable: false,
);

final List<RetrievedChunk> _sources = [
  FakeAnswerService.chunk(1, 'ps_game__Copy_.pdf', 27, 'Godot 4 was chosen.'),
  FakeAnswerService.chunk(2, 'ps_game__Copy_.pdf', 26, 'Conclusion.'),
];

Stream<AnswerEvent> _answered(String text) => Stream.fromIterable([
  FakeAnswerService.sourcesEvent(_sources),
  const AnswerGenerating(),
  AnswerToken(text),
  FakeAnswerService.doneEvent(text),
]);

/// Scripted answers per question.
Stream<AnswerEvent> _answer(String question) => switch (question) {
  'Why Godot?' => _answered('It is flexible [1].'),
  'What is in the menu?' => _answered('A start button [2].'),
  'Combien coûte Unity ?' => Stream.value(
    const AnswerNotFound(
      message: 'Introuvable dans vos documents.',
      language: AnswerLanguage.french,
      retrievalTime: Duration(seconds: 2),
      bestSimilarity: 0.27,
    ),
  ),
  'How many levels?' => _answered('Not found in your documents.'),
  _ => Stream.error(const AnswerException('The model failed.')),
};

void main() {
  test('records what happened to each question', () async {
    final results = await runAnswerEval([
      _godot,
      _menu,
      _unity,
      _levels,
    ], _answer);

    final [godot, menu, unity, levels] = results;
    expect(godot.answer, 'It is flexible [1].');
    expect(godot.sourceHit, isTrue);
    expect(godot.citesRightPage, isTrue);
    expect(godot.generation!.outputTokens, 64);

    // Page 5 isn't among the sources, and [2] cites page 26.
    expect(menu.sourceHit, isFalse);
    expect(menu.citesRightPage, isFalse);

    expect(unity.refusedByGate, isTrue);
    expect(unity.bestSimilarity, 0.27);
    expect(unity.declined, isTrue);
    expect(unity.sourceHit, isNull);
    expect(unity.generation, isNull);

    expect(levels.refusedByGate, isFalse);
    expect(levels.modelSaidNotFound, isTrue);
    expect(levels.declined, isTrue);
  });

  test('keeps going after a failure and records it', () async {
    const broken = EvalQuestion(
      id: 'q99',
      lang: 'en',
      question: 'Breaks?',
      answerable: true,
      doc: 'x',
      pages: [1],
    );

    final results = await runAnswerEval([broken, _godot], _answer);

    expect(results.first.error, 'The model failed.');
    expect(results.last.answer, 'It is flexible [1].');
  });

  test('reports progress and stops when cancelled', () async {
    final seen = <int>[];

    final results = await runAnswerEval(
      [_godot, _menu, _unity],
      _answer,
      onResult: (rs) => seen.add(rs.length),
      isCancelled: () => seen.length >= 2,
    );

    expect(seen, [1, 2]);
    expect(results, hasLength(2));
  });

  test('summarizes the run', () async {
    final results = await runAnswerEval([
      _godot,
      _menu,
      _unity,
      _levels,
    ], _answer);

    final summary = AnswerEvalSummary(results).toJson();

    expect(summary['questions'], 4);
    expect(summary['answered_answerable'], 2);
    expect(summary['gate_refused_unanswerable'], 1);
    expect(summary['model_not_found_unanswerable'], 1);
    expect(summary['declined_unanswerable'], 2);
    expect(summary['source_hit'], 1);
    expect(summary['answers_with_citation'], 2);
    expect(summary['cites_right_page'], 1);
    expect(summary['median_ttft_ms'], 18400);
    expect(summary['errors'], 0);
  });

  test('exports sources, citations and timings', () async {
    final [godot] = await runAnswerEval([_godot], _answer);

    final json = godot.toJson();

    expect(json['id'], 'q15');
    expect(json['expected_answer'], 'Flexibility.');
    expect(json['sources'], [
      {
        'n': 1,
        'doc': 'ps_game__Copy_.pdf',
        'page': 27,
        'chunk_id': 1,
        'similarity': 0.5,
      },
      {
        'n': 2,
        'doc': 'ps_game__Copy_.pdf',
        'page': 26,
        'chunk_id': 2,
        'similarity': 0.5,
      },
    ]);
    expect(json['citations'], [
      {'n': 1, 'doc': 'ps_game__Copy_.pdf', 'page': 27},
    ]);
    expect(json['ttft_ms'], 18400);
    expect(json['refused_by_gate'], isFalse);
    expect(json['error'], isNull);
  });
}
