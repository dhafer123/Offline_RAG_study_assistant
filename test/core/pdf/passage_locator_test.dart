import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/pdf/passage_locator.dart';

String slice(String text, TextRange? r) => text.substring(r!.start, r.end);

void main() {
  group('locatePassage', () {
    test('finds a passage copied verbatim', () {
      const page = 'Intro line.\nGodot 4 was chosen for its flexibility.\nEnd.';

      final r = locatePassage(page, 'Godot 4 was chosen for its flexibility.');

      // From the first to the last letter or digit: punctuation at the edges
      // isn't compared, so it isn't included.
      expect(slice(page, r), 'Godot 4 was chosen for its flexibility');
    });

    test('ignores what the cleaner changed: hyphens, spaces, accents', () {
      // Raw page text: hyphenated line break, LaTeX spacing accents, double
      // spaces and a running header the cleaner removed.
      const page =
          'Rapport de projet   2024\n'
          "Le moteur a été choisi pour l'implémen-\n"
          'tation, il est g´en´eral et rapide.\n'
          'Page 27';
      const chunk =
          "Le moteur a été choisi pour l'implémentation, il est général et "
          'rapide.';

      final r = locatePassage(page, chunk);

      expect(slice(page, r), startsWith('Le moteur'));
      expect(slice(page, r), endsWith('rapide'));
    });

    test('matches ligatures expanded by the cleaner', () {
      const page = 'The eﬃcient ﬁlter works on every ﬂow.';

      final r = locatePassage(
        page,
        'The efficient filter works on every flow.',
      );

      expect(r, isNotNull);
      expect(slice(page, r), startsWith('The'));
      expect(slice(page, r), endsWith('ﬂow'));
    });

    test('finds a short passage', () {
      const page = 'Title\nShort caption here\nBody text.';

      expect(
        slice(page, locatePassage(page, 'Short caption')),
        'Short caption',
      );
    });

    test('anchors the end after the start, past repeated phrases', () {
      const page =
          'the model is small. Intro. The model runs on the phone and the '
          'model is small.';
      const chunk = 'The model runs on the phone and the model is small.';

      final r = locatePassage(page, chunk, anchorLength: 12);

      expect(slice(page, r), chunk.substring(0, chunk.length - 1));
    });

    test('returns null when the passage is not on the page', () {
      expect(locatePassage('Some other page.', 'Godot 4 was chosen'), isNull);
      expect(locatePassage('', 'text'), isNull);
      expect(locatePassage('text', '  ...  '), isNull);
    });

    test('returns null when only the start matches', () {
      const page = 'Godot 4 was chosen. Then the page ends.';

      expect(
        locatePassage(page, 'Godot 4 was chosen for reasons not on this page'),
        isNull,
      );
    });
  });

  group('mergeLineRects', () {
    test('merges the characters of a line into one box', () {
      final lines = mergeLineRects([
        const Rect.fromLTWH(10, 100, 5, 10),
        const Rect.fromLTWH(15, 101, 5, 10),
        const Rect.fromLTWH(20, 100, 5, 9),
      ]);

      expect(lines, [const Rect.fromLTRB(10, 100, 25, 111)]);
    });

    test('starts a new box on a new line', () {
      final lines = mergeLineRects([
        const Rect.fromLTWH(10, 100, 5, 10),
        const Rect.fromLTWH(15, 100, 5, 10),
        const Rect.fromLTWH(10, 115, 5, 10), // next line, back to the left
        const Rect.fromLTWH(15, 115, 5, 10),
      ]);

      expect(lines, [
        const Rect.fromLTRB(10, 100, 20, 110),
        const Rect.fromLTRB(10, 115, 20, 125),
      ]);
    });

    test('skips empty boxes such as spaces', () {
      final lines = mergeLineRects([
        const Rect.fromLTWH(10, 100, 5, 10),
        Rect.zero,
        const Rect.fromLTWH(20, 100, 5, 10),
      ]);

      expect(lines, [const Rect.fromLTRB(10, 100, 25, 110)]);
      expect(mergeLineRects(const []), isEmpty);
    });
  });
}
