import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/app/router.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/app/widgets/message_view.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/settings/app_settings.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';
import 'package:offline_study_assistant/features/library/library_bot.dart';
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
          const _MoreMenu(),
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
        LibraryState(loadFailed: true) => MessageView(
          mood: BotMood.sad,
          title: "Couldn't open your library",
          body:
              'Your documents are still on the phone. Try again; if it '
              'keeps failing, restart the app.',
          isError: true,
          action: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            onPressed: controller.retryLoad,
          ),
        ),
        LibraryState(documents: []) => const MessageView(
          mood: BotMood.happy,
          title: 'No documents yet',
          body:
              "Import a course PDF and I'll read it, right here on the phone. "
              'Then ask me anything about it: every answer shows the pages '
              'it comes from.\n\nScanned PDFs (pages that are only images) '
              "can't be read yet.",
        ),
        _ => ListView(
          // Room for the floating button under the last tile.
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            _GreetingCard(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Your documents',
                style: Theme.of(context).textTheme.titleMedium,
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

    final scheme = theme.colorScheme;
    final ready = doc.status == DocumentStatus.ready && !running && !queued;
    final (icon, background, foreground) = failed
        ? (Icons.error_outline, scheme.errorContainer, scheme.onErrorContainer)
        : ready
        ? (
            Icons.picture_as_pdf_outlined,
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
          )
        : (
            Icons.hourglass_top,
            scheme.surfaceContainerHighest,
            scheme.onSurfaceVariant,
          );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: foreground),
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

/// The bot at the top of the list: what it's doing, and the way to the chat.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.state});

  final LibraryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final greeting = libraryGreeting(state);
    final progress = state.progress;
    final canAsk = state.documents.any(
      (d) => d.status == DocumentStatus.ready && !state.isBusy(d.id),
    );

    return Card(
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
        child: Row(
          children: [
            BotAvatar(mood: greeting.mood, size: 88),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    greeting.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.runningId != null) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress == null || progress.total == 0
                          ? null
                          : progress.done / progress.total,
                    ),
                  ],
                  if (canAsk) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('Ask your documents'),
                      onPressed: () => context.push(AppRoutes.chat),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Appearance, plus the measurement screens used for `docs/METRICS.md`
/// (they stay in release builds, where the numbers are taken).
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu();

  static const _appearance = 'appearance';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) async {
        if (value == _appearance) {
          await _chooseAppearance(context, ref);
        } else {
          await context.push(value);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _appearance,
          child: ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Appearance'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: AppRoutes.retrievalDebug,
          child: ListTile(
            leading: Icon(Icons.manage_search),
            title: Text('Retrieval debug'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.llmBenchmark,
          child: ListTile(
            leading: Icon(Icons.speed),
            title: Text('LLM benchmark'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.llmDebug,
          child: ListTile(
            leading: Icon(Icons.bug_report_outlined),
            title: Text('LLM debug'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.botPreview,
          child: ListTile(
            leading: Icon(Icons.smart_toy_outlined),
            title: Text('Bot preview'),
          ),
        ),
      ],
    );
  }

  static Future<void> _chooseAppearance(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final chosen = await showDialog<AppThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          RadioGroup<AppThemeMode>(
            groupValue: ref.read(themeModeSettingProvider),
            onChanged: (mode) => Navigator.pop(context, mode),
            child: const Column(
              children: [
                RadioListTile(
                  value: AppThemeMode.system,
                  title: Text('Same as the phone'),
                ),
                RadioListTile(value: AppThemeMode.light, title: Text('Light')),
                RadioListTile(value: AppThemeMode.dark, title: Text('Dark')),
              ],
            ),
          ),
        ],
      ),
    );
    if (chosen != null) {
      await ref.read(themeModeSettingProvider.notifier).set(chosen);
    }
  }
}
