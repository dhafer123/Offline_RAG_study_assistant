import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/app/router.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_debug_controller.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';

class RetrievalDebugScreen extends ConsumerStatefulWidget {
  const RetrievalDebugScreen({super.key});

  @override
  ConsumerState<RetrievalDebugScreen> createState() =>
      _RetrievalDebugScreenState();
}

class _RetrievalDebugScreenState extends ConsumerState<RetrievalDebugScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(
        () => ref.read(retrievalDebugControllerProvider.notifier).refresh(),
      ),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(retrievalDebugControllerProvider);
    final controller = ref.read(retrievalDebugControllerProvider.notifier);
    final theme = Theme.of(context);
    final indexed = {for (final d in state.documents) d.path};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retrieval debug'),
        actions: [
          IconButton(
            tooltip: 'Retrieval eval',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: state.isBusy
                ? null
                : () => context.push(AppRoutes.retrievalEval),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: state.isBusy ? null : controller.refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'PDFs (${state.documents.length} indexed, '
            '${state.vectorCount} vectors)',
            style: theme.textTheme.titleMedium,
          ),
          if (state.files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No PDF found. Push some to files/pdfs with adb (see README).',
              ),
            ),
          for (final path in state.files)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(path.split(RegExp(r'[/\\]')).last),
              trailing: indexed.contains(path)
                  ? const Icon(Icons.check)
                  : TextButton(
                      onPressed: state.isBusy
                          ? null
                          : () => controller.index(path),
                      child: const Text('Index'),
                    ),
            ),
          if (state.status == RetrievalDebugStatus.indexing) ...[
            const SizedBox(height: 8),
            Text(_progressLabel(state.progress)),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _fraction(state.progress)),
          ],
          if (state.lastIngestion case final result?) ...[
            const SizedBox(height: 8),
            Text('Last indexing: $result', style: theme.textTheme.bodySmall),
          ],
          const Divider(height: 32),
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: controller.search,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: state.isBusy
                    ? null
                    : () => controller.search(_query.text),
                child: const Text('Search'),
              ),
              const SizedBox(width: 16),
              if (state.status == RetrievalDebugStatus.searching)
                const Text('Searching…')
              else if (state.searchTime case final time?)
                Text('${time.inMilliseconds} ms'),
            ],
          ),
          if (state.errorMessage case final message?
              when state.status == RetrievalDebugStatus.error) ...[
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 8),
          for (final (i, r) in state.results.indexed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[${i + 1}] ${r.documentTitle} · p. ${r.page} · '
                      '${r.similarity.toStringAsFixed(3)}',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.chunk.text,
                      maxLines: 6,
                      overflow: TextOverflow.fade,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _progressLabel(IngestionProgress? p) {
    if (p == null) return 'Starting…';
    final steps = p.total > 0 ? ' ${p.done}/${p.total}' : '';
    return switch (p.stage) {
      IngestionStage.extracting => 'Extracting pages$steps',
      IngestionStage.chunking => 'Cleaning and chunking',
      IngestionStage.embedding => 'Embedding chunks$steps',
      IngestionStage.saving => 'Saving',
    };
  }

  static double? _fraction(IngestionProgress? p) =>
      p == null || p.total == 0 ? null : p.done / p.total;
}
