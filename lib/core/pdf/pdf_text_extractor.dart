import 'package:flutter/foundation.dart';

/// The raw text of one PDF page.
@immutable
class ExtractedPage {
  const ExtractedPage({
    required this.pageNumber,
    required this.text,
    required this.hasText,
  });

  /// 1-based.
  final int pageNumber;

  /// Text as the PDF stores it, with line breaks normalized to `\n`.
  final String text;

  /// False when the page has (almost) no text layer, typically a scanned page.
  /// Such pages can't be searched until OCR exists (v2).
  final bool hasText;
}

@immutable
class ExtractedDocument {
  const ExtractedDocument(this.pages);

  final List<ExtractedPage> pages;

  int get pageCount => pages.length;

  /// Page numbers flagged as having no text.
  List<int> get textlessPages => [
    for (final page in pages)
      if (!page.hasText) page.pageNumber,
  ];

  /// True when no page has text, i.e. the whole PDF is a scan.
  bool get isScanned => pages.every((p) => !p.hasText);
}

enum PdfExtractionError {
  /// The file doesn't exist or can't be read.
  fileNotFound,

  /// The PDF is encrypted with a password.
  passwordProtected,

  /// The file isn't a valid PDF, or pdfium failed to parse it.
  invalidPdf,
}

class PdfExtractionException implements Exception {
  const PdfExtractionException(this.error, {this.cause});

  final PdfExtractionError error;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'PdfExtractionException: ${error.name}'
      : 'PdfExtractionException: ${error.name} ($cause)';
}

/// Fewer letters or digits than this means the page has no usable text layer.
/// A scanned page often still carries a page number or a stray glyph or two.
const minTextCharsPerPage = 20;

final _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Whether [text] holds enough letters or digits to count as real text.
bool hasUsableText(String text, {int minChars = minTextCharsPerPage}) =>
    _alphanumeric.allMatches(text).take(minChars).length >= minChars;

/// Extracts text page by page from a PDF on the device.
///
/// Implemented with pdfrx (`PdfrxTextExtractor`); the rest of the app only
/// depends on this interface.
// An interface on purpose: core components sit behind one (see CLAUDE.md).
// ignore: one_member_abstracts
abstract interface class PdfTextExtractor {
  /// Reads every page of the PDF at [path].
  ///
  /// [onProgress] is called after each page with the number of pages done and
  /// the total. Throws [PdfExtractionException] if the file can't be opened.
  Future<ExtractedDocument> extract(
    String path, {
    void Function(int done, int total)? onProgress,
  });
}
