import 'dart:convert';
import 'dart:io';

import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';
import 'package:pdfrx/pdfrx.dart';

/// [PdfTextExtractor] backed by pdfium through pdfrx.
class PdfrxTextExtractor implements PdfTextExtractor {
  /// [initialize] loads pdfium. The app uses pdfrx's Flutter initializer
  /// (pdfium bundled in the APK); host tests pass `pdfrxInitialize`, which
  /// fetches a desktop pdfium build once into a local cache.
  PdfrxTextExtractor({Future<void> Function()? initialize})
    : _initialize = initialize ?? pdfrxFlutterInitialize;

  final Future<void> Function() _initialize;

  @override
  Future<ExtractedDocument> extract(
    String path, {
    void Function(int done, int total)? onProgress,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const PdfExtractionException(PdfExtractionError.fileNotFound);
    }
    // Checked here because pdfrx on Windows reports every open failure as a
    // password error.
    if (!await _hasPdfHeader(file)) {
      throw const PdfExtractionException(PdfExtractionError.invalidPdf);
    }
    await _initialize();

    final PdfDocument document;
    try {
      // No password provider: protected PDFs are rejected, not prompted for.
      document = await PdfDocument.openFile(path);
    } on PdfPasswordException catch (e) {
      throw PdfExtractionException(
        PdfExtractionError.passwordProtected,
        cause: e,
      );
    } on PdfException catch (e) {
      throw PdfExtractionException(PdfExtractionError.invalidPdf, cause: e);
    }

    try {
      final total = document.pages.length;
      final pages = <ExtractedPage>[];
      for (final page in document.pages) {
        final raw = await page.loadText();
        final text = _normalizeLineBreaks(raw?.fullText ?? '');
        pages.add(
          ExtractedPage(
            pageNumber: page.pageNumber,
            text: text,
            hasText: hasUsableText(text),
          ),
        );
        onProgress?.call(pages.length, total);
      }
      return ExtractedDocument(pages);
    } finally {
      await document.dispose();
    }
  }

  /// PDF readers accept the `%PDF-` marker anywhere in the first 1 KB.
  static Future<bool> _hasPdfHeader(File file) async {
    final head = await file
        .openRead(0, 1024)
        .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
    return latin1.decode(head).contains('%PDF-');
  }

  static String _normalizeLineBreaks(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
