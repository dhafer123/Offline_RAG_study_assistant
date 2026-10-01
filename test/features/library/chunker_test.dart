import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/library/chunker.dart';

/// A page of [count] distinct words: "p1w0 p1w1 ...".
String page(int number, int count) =>
    [for (var i = 0; i < count; i++) 'p${number}w$i'].join(' ');

List<String> wordsOf(NewChunk chunk) => chunk.text.split(RegExp(r'\s+'));

void main() {
  group('short pages', () {
    test('a page under the limit is one chunk with all its text', () {
      final chunks = chunkPages(['Binary search halves the interval.']);

      expect(chunks, hasLength(1));
      expect(chunks.single.text, 'Binary search halves the interval.');
      expect(chunks.single.page, 1);
      expect(chunks.single.ordinal, 0);
    });

    test('a page of exactly the limit is one chunk', () {
      final chunks = chunkPages([page(1, 250)]);

      expect(chunks, hasLength(1));
      expect(wordsOf(chunks.single), hasLength(250));
    });

    test('short pages are never merged across pages', () {
      final chunks = chunkPages(['First page.', 'Second page.', 'Third.']);

      expect(chunks.map((c) => c.text), [
        'First page.',
        'Second page.',
        'Third.',
      ]);
      expect(chunks.map((c) => c.page), [1, 2, 3]);
      expect(chunks.map((c) => c.ordinal), [0, 1, 2]);
    });

    test('keeps line breaks inside a chunk and trims the edges', () {
      final chunks = chunkPages(['\n  1.1 Contexte\nLes jeux 2D.\n\n']);

      expect(chunks.single.text, '1.1 Contexte\nLes jeux 2D.');
    });
  });

  group('long pages', () {
    test('splits into windows of at most 250 words overlapping by 50', () {
      final chunks = chunkPages([page(1, 1000)]);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(wordsOf(chunk).length, lessThanOrEqualTo(250));
        expect(chunk.page, 1);
      }
      for (var i = 1; i < chunks.length; i++) {
        final previous = wordsOf(chunks[i - 1]);
        final current = wordsOf(chunks[i]);
        expect(
          current.take(50),
          previous.skip(previous.length - 50),
          reason: 'chunk $i should start with the last 50 words of ${i - 1}',
        );
      }
    });

    test('covers every word of the page, in order', () {
      final text = page(1, 1234);
      final chunks = chunkPages([text]);

      final covered = <String>[];
      for (final (i, chunk) in chunks.indexed) {
        covered.addAll(wordsOf(chunk).skip(i == 0 ? 0 : 50));
      }
      expect(covered, text.split(' '));
    });

    test('balances sizes instead of leaving a short last chunk', () {
      final chunks = chunkPages([page(1, 260)]);

      expect(chunks.map((c) => wordsOf(c).length), [155, 155]);
    });

    test('uses the fewest windows that fit', () {
      // 450 words = 250 + 200 new: two windows of 250 words.
      expect(chunkPages([page(1, 450)]).map((c) => wordsOf(c).length), [
        250,
        250,
      ]);
      // One more word needs a third window.
      expect(chunkPages([page(1, 451)]), hasLength(3));
    });

    test('ordinals continue across pages', () {
      final chunks = chunkPages([page(1, 600), page(2, 100), page(3, 600)]);

      expect(
        chunks.map((c) => c.ordinal),
        List.generate(chunks.length, (i) => i),
      );
      expect(chunks.map((c) => c.page).toSet(), {1, 2, 3});
      // No chunk mixes words from two pages.
      for (final chunk in chunks) {
        expect(
          wordsOf(chunk).every((w) => w.startsWith('p${chunk.page}w')),
          isTrue,
        );
      }
    });

    test('respects custom sizes', () {
      final chunks = chunkPages(
        [page(1, 100)],
        chunkWords: 40,
        overlapWords: 10,
      );

      expect(
        chunks.map((c) => wordsOf(c).length).every((n) => n <= 40),
        isTrue,
      );
      expect(
        wordsOf(chunks[1]).first,
        wordsOf(chunks[0])[wordsOf(chunks[0]).length - 10],
      );
    });

    test('works without overlap', () {
      final chunks = chunkPages([page(1, 500)], overlapWords: 0);

      expect(chunks.map((c) => wordsOf(c).length), [250, 250]);
      expect(wordsOf(chunks[1]).first, 'p1w250');
    });
  });

  group('empty pages', () {
    test('an empty or blank page gives no chunk but keeps page numbers', () {
      final chunks = chunkPages(['Intro.', '', ' \n\t ', 'Conclusion.']);

      expect(chunks.map((c) => c.text), ['Intro.', 'Conclusion.']);
      expect(chunks.map((c) => c.page), [1, 4]);
      expect(chunks.map((c) => c.ordinal), [0, 1]);
    });

    test('a document with no text gives no chunks', () {
      expect(chunkPages(['', '  ']), isEmpty);
      expect(chunkPages(const []), isEmpty);
    });
  });

  group('arguments', () {
    test('rejects a non-positive size or an overlap not below the size', () {
      expect(() => chunkPages(['a'], chunkWords: 0), throwsArgumentError);
      expect(() => chunkPages(['a'], overlapWords: -1), throwsArgumentError);
      expect(
        () => chunkPages(['a'], chunkWords: 40, overlapWords: 40),
        throwsArgumentError,
      );
    });
  });
}
