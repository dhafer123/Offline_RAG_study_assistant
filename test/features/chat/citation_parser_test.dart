import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/chat/citation_parser.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

RetrievedChunk source(int id, String doc, int page) => RetrievedChunk(
  chunk: Chunk(id: id, docId: 1, page: page, ordinal: id, text: 't'),
  documentTitle: doc,
  score: 0.5,
  similarity: 0.5,
);

/// Sources [1]–[3] as the prompt numbered them.
final List<RetrievedChunk> sources = [
  source(10, 'game.pdf', 27),
  source(11, 'game.pdf', 26),
  source(12, 'rag.pdf', 2),
];

Citation cite(int n) => Citation(number: n, source: sources[n - 1]);

/// The answer as text, with each citation segment written as {1,3}.
String render(ParsedAnswer parsed) => parsed.segments
    .map(
      (s) => switch (s) {
        TextSegment(:final text) => text,
        CitationSegment(:final citations) =>
          '{${citations.map((c) => c.number).join(',')}}',
      },
    )
    .join();

void main() {
  test('[1] maps to the first source, with document and page', () {
    final parsed = parseCitations('Godot 4 was chosen [1].', sources);

    expect(parsed.segments, [
      const TextSegment('Godot 4 was chosen '),
      CitationSegment([cite(1)]),
      const TextSegment('.'),
    ]);
    final citation = parsed.citations.single;
    expect(citation.number, 1);
    expect(citation.documentTitle, 'game.pdf');
    expect(citation.page, 27);
    expect(citation.source.chunk.id, 10);
  });

  test('[1][3] becomes one marker with two citations', () {
    final parsed = parseCitations('It is fast [1][3].', sources);

    expect(render(parsed), 'It is fast {1,3}.');
    expect(parsed.citations, [cite(1), cite(3)]);
  });

  test('[1, 2] cites both', () {
    final parsed = parseCitations('Flexible and open [1, 2].', sources);

    expect(render(parsed), 'Flexible and open {1,2}.');
    expect(parsed.citations, [cite(1), cite(2)]);
  });

  test('[7] matches no source and is dropped with its space', () {
    final parsed = parseCitations('Released in 2017 [7].', sources);

    expect(parsed.segments, [const TextSegment('Released in 2017.')]);
    expect(parsed.citations, isEmpty);
  });

  test('an answer without citations is one text segment', () {
    final parsed = parseCitations('Le GameManager gère le jeu.', sources);

    expect(parsed.segments, [const TextSegment('Le GameManager gère le jeu.')]);
    expect(parsed.citations, isEmpty);
    expect(parseCitations('', sources).segments, isEmpty);
  });

  test('keeps the valid numbers of a partly invalid marker', () {
    expect(render(parseCitations('A [1, 7].', sources)), 'A {1}.');
    expect(render(parseCitations('A [0][2].', sources)), 'A {2}.');
    expect(render(parseCitations('A [4].', sources.take(3).toList())), 'A.');
  });

  test('understands ranges, semicolons, "and" and "Source n"', () {
    expect(render(parseCitations('A [1-3].', sources)), 'A {1,2,3}.');
    expect(render(parseCitations('A [1–2].', sources)), 'A {1,2}.');
    expect(render(parseCitations('A [1; 3].', sources)), 'A {1,3}.');
    expect(render(parseCitations('A [1 and 3].', sources)), 'A {1,3}.');
    expect(render(parseCitations('A [Source 2].', sources)), 'A {2}.');
    expect(render(parseCitations('A [sources 1, 3].', sources)), 'A {1,3}.');
  });

  test('a reversed or huge range keeps only its valid ends', () {
    expect(render(parseCitations('A [3-1].', sources)), 'A {3,1}.');
    expect(render(parseCitations('A [1-999].', sources)), 'A {1}.');
  });

  test('merges markers separated only by spaces', () {
    expect(render(parseCitations('A [1] [3].', sources)), 'A {1,3}.');
    expect(render(parseCitations('A [1] [7] [3].', sources)), 'A {1,3}.');
  });

  test('does not repeat a source within a marker', () {
    expect(render(parseCitations('A [1][1, 1].', sources)), 'A {1}.');
  });

  test('lists each cited source once, in order of first citation', () {
    final parsed = parseCitations(
      'First [2]. Second [1][2]. Third [2].',
      sources,
    );

    expect(render(parsed), 'First {2}. Second {1,2}. Third {2}.');
    expect(parsed.citations, [cite(2), cite(1)]);
  });

  test('a marker at the start or alone works', () {
    expect(render(parseCitations('[1] Godot.', sources)), '{1} Godot.');
    expect(render(parseCitations('[3]', sources)), '{3}');
  });

  test('leaves other brackets and parentheses as text', () {
    const text = 'Use a[i] and (12) or [note] [1a].';
    expect(render(parseCitations(text, sources)), text);
  });

  test('without sources every marker is dropped', () {
    final parsed = parseCitations('A [1].', const []);

    expect(render(parsed), 'A.');
    expect(parsed.citations, isEmpty);
  });

  test('plainText removes the markers', () {
    expect(
      parseCitations('Godot [1] was chosen [2, 3].', sources).plainText,
      'Godot  was chosen .',
    );
  });

  test('parses a real answer from Gemma 3 1B on the phone', () {
    // "Why did the team pick Godot 4 to build the game?", 3 sources.
    const answer =
        'Godot was chosen because it offered flexibility, high performance '
        'and an open-source nature compared other engines which facilitated '
        "modularity, code reuse and maintenance [1]. Godot's GDScript "
        'language was also beneficial for rapid development and readability '
        '[1]. This was particularly useful for developing two-dimensional '
        'games [1].';

    final parsed = parseCitations(answer, sources);

    expect(parsed.citations, [cite(1)]);
    expect(parsed.segments.whereType<CitationSegment>(), hasLength(3));
    expect(parsed.plainText, isNot(contains('[')));
  });

  group('while streaming', () {
    test('hides a marker that is not closed yet', () {
      for (final partial in [
        'Godot [',
        'Godot [1',
        'Godot [1, ',
        'Godot [So',
      ]) {
        expect(
          render(parseCitations(partial, sources, streaming: true)),
          'Godot',
          reason: partial,
        );
      }
    });

    test('keeps closed markers and ordinary text', () {
      expect(
        render(parseCitations('Godot [1]. It', sources, streaming: true)),
        'Godot {1}. It',
      );
      // Without streaming, an unclosed bracket is just text.
      expect(render(parseCitations('Godot [1', sources)), 'Godot [1');
    });
  });
}
