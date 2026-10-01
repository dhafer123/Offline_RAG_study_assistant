import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';

/// [PdfTextExtractor] returning fixed pages for every path.
class FakePdfTextExtractor implements PdfTextExtractor {
  FakePdfTextExtractor(List<String> pages, {this.error})
    : _pages = [
        for (var i = 0; i < pages.length; i++)
          ExtractedPage(
            pageNumber: i + 1,
            text: pages[i],
            hasText: hasUsableText(pages[i]),
          ),
      ];

  final List<ExtractedPage> _pages;
  final PdfExtractionException? error;
  final paths = <String>[];

  @override
  Future<ExtractedDocument> extract(
    String path, {
    void Function(int done, int total)? onProgress,
  }) async {
    paths.add(path);
    if (error case final e?) throw e;
    for (var i = 1; i <= _pages.length; i++) {
      onProgress?.call(i, _pages.length);
    }
    return ExtractedDocument(_pages);
  }
}
