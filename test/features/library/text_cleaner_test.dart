import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/features/library/text_cleaner.dart';

void main() {
  group('fixSpacingAccents', () {
    test('composes an accent glyph with the letter after it', () {
      expect(fixSpacingAccents('g´en´eral'), 'général');
      expect(fixSpacingAccents('syst`emes'), 'systèmes');
      expect(fixSpacingAccents('`a la fois'), 'à la fois');
      expect(fixSpacingAccents('int´erˆet'), 'intérêt');
      expect(fixSpacingAccents('na¨ıve'), 'naïve');
    });

    test('maps a dotless i under an accent to i', () {
      expect(fixSpacingAccents('maˆıtrise'), 'maîtrise');
    });

    test('composes a cedilla before or after c', () {
      expect(fixSpacingAccents('le¸cons'), 'leçons');
      expect(fixSpacingAccents('franc¸ais'), 'français');
    });

    test('moves an acute accent left at the end of a line to its É', () {
      expect(fixSpacingAccents('1 Etat de l’art ´'), '1 État de l’art');
    });

    test('moves a grave accent left at the end of a line to its À', () {
      expect(
        fixSpacingAccents('aux ´evaluations. A partir de ces donn´ees `'),
        'aux évaluations. À partir de ces données',
      );
    });

    test('drops a stray accent when no capital can take it', () {
      expect(fixSpacingAccents('Elle et Exemple ´'), 'Elle et Exemple');
      expect(fixSpacingAccents('Avec les donn´ees `'), 'Avec les données');
    });

    test('fixes each line on its own', () {
      expect(
        fixSpacingAccents('1 Etat ´\nA partir de `\nfin'),
        '1 État\nÀ partir de\nfin',
      );
    });

    test('leaves normal text, code and unknown pairs alone', () {
      const text = 'déjà vu, `x`, café, rock´n´roll';
      expect(fixSpacingAccents(text), text);
    });
  });

  group('removeRepeatedEdgeLines', () {
    // Distinct body text per page, as in a real document.
    const bodies = [
      ['Graphs model pairwise relations.', 'Edges join vertices.'],
      ['A tree is a connected acyclic graph.', 'It has n - 1 edges.'],
      ['BFS visits nodes level by level.', 'It uses a queue.'],
      ['DFS goes deep first.', 'It uses a stack.'],
      ['Dijkstra needs non-negative weights.', 'It uses a heap.'],
      ['Prim builds a spanning tree.', 'Kruskal sorts the edges.'],
    ];

    test('drops headers and footers repeated on most pages', () {
      final pages = [
        for (var i = 0; i < 5; i++)
          ['Algorithms — Chapter 2', ...bodies[i], 'Course notes · ${i + 1}'],
      ];

      final cleaned = removeRepeatedEdgeLines(pages);

      expect(cleaned, bodies.take(5).toList());
    });

    test('ignores digits so numbered footers match', () {
      final pages = [
        for (var i = 0; i < 4; i++) [...bodies[i], 'Page ${i + 1} of 4'],
      ];

      expect(removeRepeatedEdgeLines(pages), bodies.take(4).toList());
    });

    test('keeps a heading that recurs on only a few pages', () {
      final pages = [
        for (var i = 0; i < 6; i++)
          [if (i < 2) 'Chapitre ${i + 1}', ...bodies[i]],
      ];

      expect(removeRepeatedEdgeLines(pages), pages);
    });

    test('only removes lines on the edges of a page', () {
      final pages = [
        for (var i = 0; i < 4; i++)
          ['Header', bodies[i][0], 'Header', bodies[i][1], 'Footer'],
      ];

      final cleaned = removeRepeatedEdgeLines(pages);

      expect(cleaned.first, [bodies[0][0], 'Header', bodies[0][1]]);
    });

    test('skips blank lines when finding the edges', () {
      final pages = [
        for (var i = 0; i < 3; i++) ['', '  ', 'Header', ...bodies[i], ''],
      ];

      final cleaned = removeRepeatedEdgeLines(pages);

      expect(cleaned.first.where((l) => l.trim().isNotEmpty), bodies[0]);
    });

    test('leaves short documents unchanged', () {
      final pages = [
        ['Header', 'one'],
        ['Header', 'two'],
      ];

      expect(removeRepeatedEdgeLines(pages), same(pages));
    });
  });

  group('page numbers', () {
    test('recognizes common page number lines', () {
      for (final line in [
        '12',
        ' 7 ',
        '- 12 -',
        '— 3 —',
        'Page 3',
        'page 3 of 10',
        'Page 3 sur 10',
        'p. 4',
        '3 / 10',
        'iv',
        'XII',
      ]) {
        expect(isPageNumberLine(line), isTrue, reason: line);
      }
    });

    test('rejects text that only looks like one', () {
      for (final line in [
        '',
        '1. Introduction',
        '12 apples',
        'Chapter 3',
        'civil',
        'mix',
        '12345',
      ]) {
        expect(isPageNumberLine(line), isFalse, reason: line);
      }
    });

    test('drops a page number on the first or last non-empty line', () {
      expect(removePageNumberLines(['Text.', '', '12', '']), [
        'Text.',
        '',
        '',
      ]);
      expect(removePageNumberLines(['iv', 'Preface.']), ['Preface.']);
    });

    test('keeps numbers inside the page', () {
      final page = ['Steps:', '1', 'Open the file.', '2', 'Read it.'];

      expect(removePageNumberLines(page), page);
    });
  });

  group('joinHyphenatedLines', () {
    test('rejoins a word split across lines', () {
      expect(
        joinHyphenatedLines('the algo-\nrithm runs'),
        'the algorithm runs',
      );
      expect(joinHyphenatedLines('cor- \n  respondantes'), 'correspondantes');
      expect(joinHyphenatedLines('ap-\nprentissage'), 'apprentissage');
    });

    test('removes the marker pdfium leaves in words it rejoined', () {
      expect(
        joinHyphenatedLines('aux pro\u0002fils et la pédago\u0002gique'),
        'aux profils et la pédagogique',
      );
    });

    test('keeps hyphens that are not at a line break', () {
      expect(joinHyphenatedLines('content-based\nfiltering'), isNot(''));
      expect(
        joinHyphenatedLines('content-based\nfiltering'),
        'content-based\nfiltering',
      );
    });

    test('keeps the hyphen before a capital, a digit or a list', () {
      for (final text in ['Jean-\nPaul', 'COVID-\n19', 'items -\n- next']) {
        expect(joinHyphenatedLines(text), text);
      }
    });
  });

  group('collapseDotLeaders', () {
    test('turns table-of-contents dots into one space', () {
      expect(
        collapseDotLeaders('1.1 Contexte . . . . . . . . 8'),
        '1.1 Contexte 8',
      );
      expect(collapseDotLeaders('Intro.........3'), 'Intro 3');
    });

    test('keeps ellipses and decimals', () {
      expect(collapseDotLeaders('Wait... 3.14'), 'Wait... 3.14');
    });
  });

  group('normalizeWhitespace', () {
    test('collapses spaces and tabs and trims lines', () {
      expect(normalizeWhitespace('  a \t  b  \n   c  '), 'a b\nc');
    });

    test('turns special spaces into plain spaces', () {
      expect(normalizeWhitespace('a\u00A0b\u2009c\u202Fd'), 'a b c d');
    });

    test('drops control characters', () {
      expect(normalizeWhitespace('a\u0001b\u0007c\u001Fd\u007F'), 'abcd');
    });

    test('drops soft hyphens and zero-width characters', () {
      expect(normalizeWhitespace('algo\u00ADrithm\u200B\uFEFF'), 'algorithm');
    });

    test('expands ligatures', () {
      expect(
        normalizeWhitespace('\uFB01le e\uFB00ect \uFB02ow'),
        'file effect flow',
      );
    });

    test('keeps one blank line between paragraphs at most', () {
      expect(normalizeWhitespace('a\n\n\n\n b\r\nc\rd'), 'a\n\nb\nc\nd');
    });

    test('returns an empty string for blank text', () {
      expect(normalizeWhitespace(' \n\t\n '), '');
    });
  });

  group('cleanPages', () {
    test('runs every rule and keeps one entry per page', () {
      const page2 =
          'Cours IA\nA chaque interaction, les informations cor- `\n'
          'respondantes . . . . . . 8\n2';
      final pages = [
        'Cours IA\n1 Etat de l’art ´\nLes syst`emes de recom-\nmandation.\n1',
        page2,
        'Cours IA\n\n\n3',
      ];

      expect(cleanPages(pages), [
        '1 État de l’art\nLes systèmes de recommandation.',
        'À chaque interaction, les informations correspondantes 8',
        '',
      ]);
    });

    test('handles an empty document', () {
      expect(cleanPages(const []), isEmpty);
    });
  });
}
