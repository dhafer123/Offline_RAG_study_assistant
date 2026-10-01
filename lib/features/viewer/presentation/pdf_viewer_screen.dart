import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/core/pdf/pdf_page_viewer.dart';
import 'package:offline_study_assistant/features/viewer/viewer_target.dart';

/// A document opened at a cited page, with the cited passage highlighted.
class PdfViewerScreen extends ConsumerWidget {
  const PdfViewerScreen({
    required this.docId,
    required this.page,
    this.chunkId,
    super.key,
  });

  final int docId;
  final int page;
  final int? chunkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(
      viewerTargetProvider(docId: docId, page: page, chunkId: chunkId),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: switch (target) {
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.title, overflow: TextOverflow.ellipsis),
              Text('Page ${value.page}', style: theme.textTheme.bodySmall),
            ],
          ),
          _ => const Text('Document'),
        },
      ),
      body: switch (target) {
        AsyncData(:final value) => PdfPageViewer(
          path: value.path,
          page: value.page,
          highlight: value.highlight,
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ViewerTargetException
                  ? error.message
                  : 'This document could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
