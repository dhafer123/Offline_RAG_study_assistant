import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';

void main() {
  group('hasUsableText', () {
    test('accepts a normal paragraph', () {
      expect(hasUsableText('Binary search halves the interval.'), isTrue);
    });

    test('rejects empty and whitespace-only text', () {
      expect(hasUsableText(''), isFalse);
      expect(hasUsableText(' \n\t \n'), isFalse);
    });

    test('rejects a lone page number or stray glyphs', () {
      expect(hasUsableText('  12  '), isFalse);
      expect(hasUsableText('Page 3 / 120 — • • •'), isFalse);
    });

    test('counts letters and digits only, including accents', () {
      expect(hasUsableText('é' * 19), isFalse);
      expect(hasUsableText('é' * 20), isTrue);
      expect(hasUsableText('. , ; ' * 50), isFalse);
    });

    test('uses the given threshold', () {
      expect(hasUsableText('abc', minChars: 3), isTrue);
      expect(hasUsableText('ab', minChars: 3), isFalse);
    });
  });

  group('ExtractedDocument', () {
    ExtractedPage page(int n, {required bool hasText}) =>
        ExtractedPage(pageNumber: n, text: '', hasText: hasText);

    test('lists textless pages', () {
      final doc = ExtractedDocument([
        page(1, hasText: true),
        page(2, hasText: false),
        page(3, hasText: true),
      ]);

      expect(doc.pageCount, 3);
      expect(doc.textlessPages, [2]);
      expect(doc.isScanned, isFalse);
    });

    test('is scanned when no page has text', () {
      final doc = ExtractedDocument([
        page(1, hasText: false),
        page(2, hasText: false),
      ]);

      expect(doc.isScanned, isTrue);
    });
  });
}
