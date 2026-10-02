import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/app/router.dart';
import 'package:offline_study_assistant/app/widgets/message_view.dart';
import 'package:offline_study_assistant/features/chat/chat_controller.dart';
import 'package:offline_study_assistant/features/chat/citation_parser.dart';
import 'package:offline_study_assistant/features/library/library_controller.dart';

/// Ask questions about the indexed documents; answers cite their pages.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final question = _input.text.trim();
    if (question.isEmpty || ref.read(chatControllerProvider).isBusy) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).ask(question).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final exchanges = state.exchanges.reversed.toList();
    // Unknown while the library loads: don't block the input for that.
    final noDocuments = ref.watch(hasReadyDocumentsProvider) == false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask your documents')),
      body: Column(
        children: [
          Expanded(
            child: exchanges.isEmpty
                ? noDocuments
                      ? MessageView(
                          icon: Icons.library_add_outlined,
                          title: 'No documents to search yet',
                          body:
                              'Import a course PDF in the library first. '
                              'Once it is indexed, you can ask questions '
                              'about it here.',
                          action: FilledButton.icon(
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go to the library'),
                            onPressed: () => context.go(AppRoutes.library),
                          ),
                        )
                      : const MessageView(
                          icon: Icons.forum_outlined,
                          title: 'Ask a question about your course PDFs.',
                          body:
                              'Answers come only from your documents and '
                              'cite the pages they use. Everything runs on '
                              'this phone, offline.',
                        )
                // Reversed so the latest answer stays in view as it grows.
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: exchanges.length,
                    itemBuilder: (context, i) =>
                        _ExchangeView(exchange: exchanges[i]),
                  ),
          ),
          _InputBar(
            controller: _input,
            enabled: !noDocuments,
            busy: state.isBusy,
            onSend: _send,
            onStop: () =>
                ref.read(chatControllerProvider.notifier).stop().ignore(),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Ask a question'),
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              IconButton.filledTonal(
                tooltip: 'Stop',
                icon: const Icon(Icons.stop),
                onPressed: onStop,
              )
            else
              IconButton.filled(
                tooltip: 'Send',
                icon: const Icon(Icons.send),
                onPressed: enabled ? onSend : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeView extends StatelessWidget {
  const _ExchangeView({required this.exchange});

  final ChatExchange exchange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = exchange.parsed;
    final status = _statusLabel();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                exchange.question,
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (status != null && exchange.answer.isEmpty)
            _Progress(label: status),
          if (exchange.phase == ExchangePhase.notFound)
            Row(
              children: [
                Icon(
                  Icons.search_off,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exchange.answer,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          else if (parsed.segments.isNotEmpty)
            _AnswerText(parsed: parsed),
          if (exchange.phase == ExchangePhase.stopped) ...[
            const SizedBox(height: 4),
            Text(
              'Stopped',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (exchange.phase == ExchangePhase.error) ...[
            const SizedBox(height: 4),
            Text(
              exchange.errorMessage ?? 'Something went wrong.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (parsed.citations.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CitationChips(citations: parsed.citations),
          ],
          if (exchange.generation case final g?
              when exchange.phase == ExchangePhase.done) ...[
            const SizedBox(height: 4),
            Text(
              'First word after '
              '${(g.timeToFirstToken.inMilliseconds / 1000).toStringAsFixed(1)}'
              ' s · ${(g.total.inMilliseconds / 1000).toStringAsFixed(1)} s '
              'in total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _statusLabel() => switch (exchange.phase) {
    ExchangePhase.searching => 'Searching your documents…',
    ExchangePhase.loadingModel => 'Loading the model…',
    ExchangePhase.generating =>
      exchange.sources.length == 1
          ? 'Reading 1 source…'
          : 'Reading ${exchange.sources.length} sources…',
    _ => null,
  };
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

/// The answer with each `[n]` drawn as a small tappable marker.
class _AnswerText extends StatelessWidget {
  const _AnswerText({required this.parsed});

  final ParsedAnswer parsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyLarge,
        children: [
          for (final segment in parsed.segments)
            switch (segment) {
              TextSegment(:final text) => TextSpan(text: text),
              CitationSegment(:final citations) => WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _InlineMarker(citations: citations),
              ),
            },
        ],
      ),
    );
  }
}

class _InlineMarker extends StatelessWidget {
  const _InlineMarker({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showSources(context, citations),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            citations.map((c) => c.number).join(', '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// One chip per cited page (two sources from the same page share a chip).
class _CitationChips extends StatelessWidget {
  const _CitationChips({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    final byPage = <(String, int), List<Citation>>{};
    for (final c in citations) {
      byPage.putIfAbsent((c.documentTitle, c.page), () => []).add(c);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final MapEntry(key: (title, page), value: cs) in byPage.entries)
          ActionChip(
            avatar: const Icon(Icons.description_outlined, size: 18),
            label: Text('$title · p. $page'),
            onPressed: () => openCitation(context, cs.first),
          ),
      ],
    );
  }
}

/// Opens the cited document at the cited page, highlighting the passage.
void openCitation(BuildContext context, Citation citation) {
  final chunk = citation.source.chunk;
  unawaited(
    context.push(
      AppRoutes.viewer(docId: chunk.docId, page: chunk.page, chunkId: chunk.id),
    ),
  );
}

/// Shows the passages behind [citations], each with a way to open its page.
Future<void> showSources(BuildContext context, List<Citation> citations) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              for (final c in citations) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '[${c.number}] ${c.documentTitle} · page ${c.page}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open page'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        // The sheet's context is gone once it's popped.
                        openCitation(context, c);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c.source.chunk.text),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
