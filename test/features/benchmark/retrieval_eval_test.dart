import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_stopwatch.dart';

const _answerable = EvalQuestion(
  id: 'q1',
  lang: 'fr',
  question: 'Quel moteur ?',
  answerable: true,
  doc: 'ps_game__Copy_',
  pages: [27, 28],
);
const _unanswerable = EvalQuestion(
  id: 'u1',
  lang: 'en',
  question: 'Who invented transformers?',
  answerable: false,
);

EvalHit hit(String title, int page, [double similarity = 0.5]) => EvalHit(
  documentTitle: title,
  page: page,
  similarity: similarity,
  chunkId: page,
);

QuestionResult result(
  EvalQuestion q,
  List<EvalHit> hits, [
  int ms = 100,
]) => QuestionResult(
  question: q,
  hits: hits,
  latency: Duration(milliseconds: ms),
);

RetrievedChunk retrieved(String title, int page, double similarity) =>
    RetrievedChunk(
      chunk: Chunk(id: page, docId: 1, page: page, ordinal: 0, text: 't'),
      documentTitle: title,
      similarity: similarity,
    );

void main() {
  group('the committed eval/questions.json', () {
    final source = File('eval/questions.json').readAsStringSync();
    final questions = parseEvalQuestions(source);
    final documents =
        (jsonDecode(source) as Map<String, dynamic>)['documents']
            as Map<String, dynamic>;

    test('has 50 answerable and 10 unanswerable questions', () {
      expect(questions.where((q) => q.answerable), hasLength(50));
      expect(questions.where((q) => !q.answerable), hasLength(10));
    });

    test('has unique ids, known documents and both languages', () {
      expect(questions.map((q) => q.id).toSet(), hasLength(questions.length));
      for (final q in questions.where((q) => q.answerable)) {
        expect(documents.keys, contains(q.doc), reason: q.id);
        expect(q.pages, isNotEmpty, reason: q.id);
      }
      expect(questions.map((q) => q.lang).toSet(), {'en', 'fr'});
    });
  });

  group('parseEvalQuestions', () {
    test('rejects an answerable question without pages', () {
      const json =
          '{"questions": [{"id": "x", "lang": "en", "question": "?", '
          '"answerable": true, "doc": "d"}]}';
      expect(() => parseEvalQuestions(json), throwsFormatException);
    });
  });

  group('docKey', () {
    test('ignores the .pdf extension, accents and case', () {
      expect(docKey('État_de_l_art.pdf'), 'etat_de_l_art');
      expect(docKey('etat_de_l_art'), 'etat_de_l_art');
      expect(docKey(' ps_game__Copy_.PDF '), 'ps_game__copy_');
    });
  });

  group('QuestionResult', () {
    test('ranks the first chunk from the right document and page', () {
      final r = result(_answerable, [
        hit('other.pdf', 27),
        hit('ps_game__Copy_.pdf', 3),
        hit('ps_game__Copy_.pdf', 28),
        hit('ps_game__Copy_.pdf', 27),
      ]);

      expect(r.rank, 3);
      expect(r.foundWithin(3), isTrue);
      expect(r.foundWithin(2), isFalse);
    });

    test('has no rank when nothing matches, or when unanswerable', () {
      expect(result(_answerable, [hit('ps_game__Copy_', 5)]).rank, isNull);
      expect(result(_unanswerable, [hit('ps_game__Copy_', 27)]).rank, isNull);
      expect(result(_answerable, const []).topSimilarity, isNull);
    });

    test('serializes rank, top similarity and hits', () {
      final json = result(_answerable, [
        hit('ps_game__Copy_.pdf', 27, 0.612345),
      ], 2150).toJson();

      expect(json['rank'], 1);
      expect(json['top_similarity'], 0.6123);
      expect(json['latency_ms'], 2150);
      expect((json['hits']! as List).single, {
        'doc': 'ps_game__Copy_.pdf',
        'page': 27,
        'similarity': 0.6123,
        'chunk_id': 27,
      });
    });
  });

  group('RetrievalEvalSummary', () {
    const fr2 = EvalQuestion(
      id: 'q2',
      lang: 'fr',
      question: '?',
      answerable: true,
      doc: 'etat_de_l_art',
      pages: [1],
    );
    const en3 = EvalQuestion(
      id: 'q3',
      lang: 'en',
      question: '?',
      answerable: true,
      doc: 'etat_de_l_art',
      pages: [2],
    );

    test('computes recall@k, MRR and groups over answerable questions', () {
      final summary = RetrievalEvalSummary.of([
        result(_answerable, [hit('ps_game__Copy_', 27)], 150), // rank 1
        result(fr2, [
          hit('x', 1),
          hit('x', 1),
          hit('etat_de_l_art.pdf', 1),
        ], 200), // rank 3
        result(en3, [hit('etat_de_l_art', 9)], 300), // miss
        result(_unanswerable, [hit('x', 1)], 400), // not counted
      ]);

      expect(summary.answerable, 3);
      expect(summary.found, 2);
      expect(summary.recall, closeTo(2 / 3, 1e-9));
      expect(summary.mrr, closeTo((1 + 1 / 3 + 0) / 3, 1e-9));
      expect(summary.byLang, {
        'en': (found: 0, total: 1),
        'fr': (found: 2, total: 2),
      });
      expect(summary.byDoc['etat_de_l_art'], (found: 1, total: 2));
      expect(summary.medianLatency, const Duration(milliseconds: 250));
    });

    test('a rank beyond k is a miss', () {
      final summary = RetrievalEvalSummary.of([
        result(_answerable, [
          for (var i = 0; i < 5; i++) hit('x', 1),
          hit('ps_game__Copy_', 27),
        ]),
      ]);

      expect(summary.found, 0);
      expect(summary.mrr, closeTo(1 / 6, 1e-9));
    });
  });

  test('runRetrievalEval asks every question and times it', () async {
    final asked = <(String, int)>[];
    final progress = <int>[];
    late FakeStopwatch clock;

    final results = await runRetrievalEval(
      [_answerable, _unanswerable],
      (question, k) async {
        asked.add((question, k));
        clock.advance(const Duration(seconds: 2));
        return [retrieved('ps_game__Copy_.pdf', 27, 0.7)];
      },
      onProgress: (done, _) => progress.add(done),
      stopwatch: () => clock = FakeStopwatch(),
    );

    expect(asked, [('Quel moteur ?', 5), ('Who invented transformers?', 5)]);
    expect(progress, [1, 2]);
    expect(results.first.rank, 1);
    expect(results.first.latency, const Duration(seconds: 2));
  });

  test('the report holds the run settings, summary and every result', () {
    final report = retrievalEvalReport(
      method: 'vector',
      createdAt: DateTime.utc(2026, 10, 1, 12),
      indexedDocuments: ['ps_game__Copy_.pdf'],
      results: [
        result(_answerable, [hit('ps_game__Copy_', 27)]),
        result(_unanswerable, const []),
      ],
    );

    expect(report['created'], '2026-10-01T12:00:00.000Z');
    expect(report['method'], 'vector');
    expect(report['k'], 5);
    expect((report['summary']! as Map)['recall_at_k'], 1.0);
    expect(report['results'], hasLength(2));
    // Round-trips through JSON.
    expect(jsonDecode(jsonEncode(report)), isA<Map<String, dynamic>>());
  });
}
