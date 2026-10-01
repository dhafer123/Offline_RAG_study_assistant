import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/app/router.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';
import 'package:offline_study_assistant/features/library/library_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);

    ref.listen(libraryControllerProvider.select((s) => s.message), (_, msg) {
      if (msg == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      controller.clearMessage();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Ask a question',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.push(AppRoutes.chat),
          ),
          IconButton(
            tooltip: 'Retrieval debug',
            icon: const Icon(Icons.manage_search),
            onPressed: () => context.push(AppRoutes.retrievalDebug),
          ),
          IconButton(
            tooltip: 'LLM benchmark',
            icon: const Icon(Icons.speed),
            onPressed: () => context.push(AppRoutes.llmBenchmark),
          ),
          IconButton(
            tooltip: 'LLM debug',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => context.push(AppRoutes.llmDebug),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.importPdf,
        icon: const Icon(Icons.add),
        label: const Text('Import PDF'),
      ),
      body: switch (state) {
        LibraryState(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        LibraryState(documents: []) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No documents yet.\nImport a course PDF to get started.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => ListView(
          // Room for the floating button under the last tile.
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (state.documents.any((d) => d.status == DocumentStatus.ready))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FilledButton.icon(
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Ask your documents'),
                  onPressed: () => context.push(AppRoutes.chat),
                ),
              ),
            for (final doc in state.documents)
              _DocumentTile(doc: doc, state: state),
          ],
        ),
      },
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.doc, required this.state});

  final Document doc;
  final LibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(libraryControllerProvider.notifier);
    final theme = Theme.of(context);
    final running = doc.id == state.runningId;
    final queued = state.queued.contains(doc.id);
    final failed = doc.status == DocumentStatus.failed && !queued && !running;
    final progress = running ? state.progress : null;

    final String subtitle;
    if (running) {
      subtitle = _progressLabel(progress);
    } else if (queued) {
      subtitle = 'Waiting to be indexed…';
    } else {
      subtitle = switch (doc.status) {
        DocumentStatus.ready =>
          doc.pageCount == 1 ? '1 page' : '${doc.pageCount} pages',
        DocumentStatus.failed => state.errors[doc.id] ?? 'Indexing failed.',
        DocumentStatus.pending || DocumentStatus.indexing => 'Not indexed',
      };
    }

    return ListTile(
      leading: Icon(
        failed
            ? Icons.error_outline
            : doc.status == DocumentStatus.ready && !running && !queued
            ? Icons.picture_as_pdf
            : Icons.hourglass_top,
        color: failed ? theme.colorScheme.error : null,
      ),
      title: Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: failed ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          if (running) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _fraction(progress)),
          ],
        ],
      ),
      trailing: PopupMenuButton<_Action>(
        tooltip: 'Actions for ${doc.title}',
        enabled: !running,
        onSelected: (action) async {
          switch (action) {
            case _Action.retry:
              await controller.retry(doc.id);
            case _Action.delete:
              if (await _confirmDelete(context, doc)) {
                await controller.delete(doc.id);
              }
          }
        },
        itemBuilder: (context) => [
          if (failed)
            const PopupMenuItem(value: _Action.retry, child: Text('Retry')),
          const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context, Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '"${doc.title}" and its index will be removed from the app. '
          'The original file is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static String _progressLabel(IngestionProgress? p) {
    if (p == null) return 'Starting…';
    final steps = p.total > 0 ? ' ${p.done}/${p.total}' : '';
    return switch (p.stage) {
      IngestionStage.extracting => 'Reading pages$steps',
      IngestionStage.chunking => 'Splitting into passages',
      IngestionStage.embedding => 'Indexing passages$steps',
      IngestionStage.saving => 'Saving',
    };
  }

  static double? _fraction(IngestionProgress? p) =>
      p == null || p.total == 0 ? null : p.done / p.total;
}

enum _Action { retry, delete }
