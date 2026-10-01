import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval_controller.dart';

class RetrievalEvalScreen extends ConsumerWidget {
  const RetrievalEvalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(retrievalEvalControllerProvider);
    final controller = ref.read(retrievalEvalControllerProvider.notifier);
    final theme = Theme.of(context);
    final running = state.status == RetrievalEvalStatus.running;

    return Scaffold(
      appBar: AppBar(title: const Text('Retrieval eval')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Runs every question of eval/questions.json through retrieval '
            '(top $defaultEvalK, '
            '${RetrievalEvalController.method}) against the indexed '
            'documents, then exports the results as JSON.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: running ? null : controller.run,
            child: const Text('Run eval'),
          ),
          if (running) ...[
            const SizedBox(height: 16),
            Text('Question ${state.done}/${state.total}'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: state.total == 0 ? null : state.done / state.total,
            ),
          ],
          if (state.errorMessage case final message?
              when state.status == RetrievalEvalStatus.error) ...[
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (state.summary case final summary?) ...[
            const SizedBox(height: 24),
            Text(
              'Recall@${summary.k}: '
              '${(summary.recall * 100).toStringAsFixed(1)}% '
              '(${summary.found}/${summary.answerable})',
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              'MRR ${summary.mrr.toStringAsFixed(3)} · median '
              '${summary.medianLatency.inMilliseconds} ms per question',
            ),
            const SizedBox(height: 12),
            for (final MapEntry(:key, :value) in {
              ...summary.byLang,
              ...summary.byDoc,
            }.entries)
              Text('$key: ${value.found}/${value.total}'),
            if (state.exportPath case final path?) ...[
              const SizedBox(height: 12),
              SelectableText(
                'Saved to $path',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const Divider(height: 32),
            Text(
              'Misses (${state.misses.length})',
              style: theme.textTheme.titleMedium,
            ),
            for (final miss in state.misses) _MissTile(result: miss),
          ],
        ],
      ),
    );
  }
}

class _MissTile extends StatelessWidget {
  const _MissTile({required this.result});

  final QuestionResult result;

  @override
  Widget build(BuildContext context) {
    final q = result.question;
    final got = [
      for (final h in result.hits.take(3))
        '${h.documentTitle} p.${h.page} (${h.similarity.toStringAsFixed(2)})',
    ].join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${q.id} · ${q.question}'),
      subtitle: Text('Expected ${q.doc} p.${q.pages.join('/')}\nGot $got'),
    );
  }
}
