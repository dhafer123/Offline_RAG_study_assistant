import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/fts_query.dart';

void main() {
  group('buildFtsQuery', () {
    test('quotes each word and joins them with OR', () {
      expect(
        buildFtsQuery('binary search tree'),
        '"binary" OR "search" OR "tree"',
      );
    });

    test('drops punctuation and FTS5 operators', () {
      expect(
        buildFtsQuery('What is "NOT" a (B-tree)? * ^col:x'),
        '"what" OR "is" OR "not" OR "a" OR "b" OR "tree" OR "col" OR "x"',
      );
    });

    test('keeps accented letters and splits on apostrophes', () {
      expect(
        buildFtsQuery("Qu'est-ce qu'une itération ?"),
        '"qu" OR "est" OR "ce" OR "une" OR "itération"',
      );
    });

    test('lowercases and removes duplicates', () {
      expect(buildFtsQuery('Graph graph GRAPH 42'), '"graph" OR "42"');
    });

    test('returns null when there is no word', () {
      expect(buildFtsQuery(''), isNull);
      expect(buildFtsQuery('?! ... "" *'), isNull);
    });

    test('caps the number of terms', () {
      expect(buildFtsQuery('a b c d', maxTerms: 2), '"a" OR "b"');
    });
  });
}
