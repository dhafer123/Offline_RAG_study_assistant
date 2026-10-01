import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';
import 'package:offline_study_assistant/core/pdf/pdfrx_text_extractor.dart';

import '../../helpers/pdfium.dart';

// Fixture built by tool/make_fixture_pdf.dart.
const _fixture = 'test/fixtures/pdf/sample.pdf';

void main() {
  final extractor = PdfrxTextExtractor(initialize: initPdfiumForTests);

  test('extracts text per page and flags pages without text', () async {
    final doc = await extractor.extract(_fixture);

    expect(doc.pageCount, 4);
    expect(doc.pages.map((p) => p.pageNumber), [1, 2, 3, 4]);

    final english = doc.pages[0];
    expect(english.hasText, isTrue);
    expect(english.text, contains('Binary search finds an item'));
    expect(english.text, contains('logarithmic time'));
    expect(english.text, isNot(contains('\r')));

    final french = doc.pages[2];
    expect(french.hasText, isTrue);
    expect(french.text, contains('complexité moyenne'));

    // Page 2 has only a drawn box and its page number; page 4 is blank.
    expect(doc.textlessPages, [2, 4]);
    expect(doc.pages[3].text.trim(), isEmpty);
    expect(doc.isScanned, isFalse);
  });

  test('reports progress after each page', () async {
    final calls = <(int, int)>[];

    await extractor.extract(_fixture, onProgress: (d, t) => calls.add((d, t)));

    expect(calls, [(1, 4), (2, 4), (3, 4), (4, 4)]);
  });

  test('a missing file throws fileNotFound', () async {
    await expectLater(
      extractor.extract('test/fixtures/pdf/missing.pdf'),
      throwsA(
        isA<PdfExtractionException>().having(
          (e) => e.error,
          'error',
          PdfExtractionError.fileNotFound,
        ),
      ),
    );
  });

  test('a file that is not a PDF throws invalidPdf', () async {
    final dir = await Directory.systemTemp.createTemp('pdf_extract_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/notes.pdf')
      ..writeAsStringSync('just some text, not a PDF');

    await expectLater(
      extractor.extract(file.path),
      throwsA(
        isA<PdfExtractionException>().having(
          (e) => e.error,
          'error',
          PdfExtractionError.invalidPdf,
        ),
      ),
    );
  });
}
