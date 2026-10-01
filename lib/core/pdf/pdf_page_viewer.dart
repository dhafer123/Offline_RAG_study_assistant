import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:offline_study_assistant/core/pdf/passage_locator.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:pdfrx/pdfrx.dart';

/// Shows a PDF opened at [page], with [highlight] (a chunk's text) marked on
/// that page when it can be found.
///
/// Wraps pdfrx so screens don't depend on it.
class PdfPageViewer extends StatefulWidget {
  const PdfPageViewer({
    required this.path,
    required this.page,
    this.highlight,
    this.onHighlightLocated,
    super.key,
  });

  /// Absolute path of the PDF file.
  final String path;

  /// 1-based page to open at.
  final int page;

  /// Text to mark on [page], e.g. the cited chunk.
  final String? highlight;

  /// Called once the highlight was looked for: true if it was found.
  final ValueChanged<bool>? onHighlightLocated;

  @override
  State<PdfPageViewer> createState() => _PdfPageViewerState();
}

class _PdfPageViewerState extends State<PdfPageViewer> {
  final _controller = PdfViewerController();

  /// Character boxes of the highlight, in PDF page coordinates.
  List<PdfRect> _highlight = const [];

  Future<void> _onReady(PdfDocument document, PdfViewerController _) async {
    final text = widget.highlight;
    if (text == null || widget.page > document.pages.length) return;
    try {
      // With progressive loading the page may not be loaded yet, and
      // loadStructuredText then returns empty text (its ensureLoaded flag is
      // ignored in pdfrx_engine 0.3.9), so wait for the page first.
      final page = await document.pages[widget.page - 1].waitForLoaded(
        timeout: const Duration(seconds: 10),
      );
      if (page == null) throw TimeoutException('page ${widget.page}');
      final pageText = await page.loadStructuredText();
      final range = locatePassage(pageText.fullText, text);
      Perf.log(
        'viewer highlight p.${widget.page}: '
        '${range == null ? 'not found' : '${range.start}-${range.end}'} '
        '(page ${pageText.fullText.length} chars, '
        '${pageText.charRects.length} boxes)',
      );
      if (!mounted) return;
      widget.onHighlightLocated?.call(range != null);
      if (range == null) return;
      setState(() {
        final rects = pageText.charRects;
        _highlight = rects.sublist(
          range.start.clamp(0, rects.length),
          range.end.clamp(0, rects.length),
        );
      });
      _controller.invalidate();
    } on Object catch (e) {
      Perf.log('viewer highlight failed: $e');
      // No highlight; the page is still shown.
      if (mounted) widget.onHighlightLocated?.call(false);
    }
  }

  void _paintHighlight(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    if (page.pageNumber != widget.page || _highlight.isEmpty) return;
    // Highlighter yellow, not a theme color: pages are white in both themes.
    final paint = Paint()
      ..color = const Color(0x66FFD54F)
      ..blendMode = BlendMode.multiply;
    final lines = mergeLineRects(
      _highlight.map((r) => r.toRectInDocument(page: page, pageRect: pageRect)),
    );
    for (final line in lines) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(line.inflate(1.5), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      widget.path,
      controller: _controller,
      initialPageNumber: widget.page,
      params: PdfViewerParams(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        onViewerReady: (document, controller) =>
            unawaited(_onReady(document, controller)),
        pagePaintCallbacks: [_paintHighlight],
        errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This PDF could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}
