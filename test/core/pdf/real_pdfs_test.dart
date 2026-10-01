// Extraction report for your own PDFs, skipped unless REAL_PDFS_DIR is set:
//
//   REAL_PDFS_DIR="C:/path/to/course pdfs" flutter test test/core/pdf/real_pdfs_test.dart
//
// The PDFs stay on your machine; they are never committed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/pdf/pdfrx_text_extractor.dart';

import '../../helpers/pdfium.dart';

void main() {
  final dirPath = Platform.environment['REAL_PDFS_DIR'];

  test(
    'extracts every PDF in REAL_PDFS_DIR',
    () async {
      final pdfs =
          Directory(dirPath!)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.pdf'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(pdfs, isNotEmpty, reason: 'no .pdf file in $dirPath');

      final extractor = PdfrxTextExtractor(initialize: initPdfiumForTests);
      for (final pdf in pdfs) {
        final watch = Stopwatch()..start();
        final doc = await extractor.extract(pdf.path);
        watch.stop();

        final chars = doc.pages.fold<int>(0, (n, p) => n + p.text.length);
        final textless = doc.textlessPages;
        stdout.writeln(
          '${pdf.uri.pathSegments.last}: ${doc.pageCount} pages, '
          '$chars chars, ${watch.elapsedMilliseconds} ms, '
          '${textless.isEmpty ? 'no textless pages' : 'textless: $textless'}'
          '${doc.isScanned ? ' (SCANNED)' : ''}',
        );
        expect(doc.pageCount, greaterThan(0));
      }
    },
    skip: dirPath == null ? 'set REAL_PDFS_DIR to run' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
