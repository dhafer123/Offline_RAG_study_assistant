import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/features/benchmark/answer_eval.dart';
import 'package:offline_study_assistant/features/benchmark/answer_eval_controller.dart';

/// Runs every eval question through the full pipeline (task 4.1).
class AnswerEvalScreen extends ConsumerWidget {
  const AnswerEvalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(answerEvalControllerProvider);
    final controller = ref.read(answerEvalControllerProvider.notifier);
    final theme = Theme.of(context);
    final summary = state.summary.toJson();

    return Scaffold(
      appBar: AppBar(title: const Text('Answer eval')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Asks every question of eval/questions.json through the full '
            'pipeline (retrieval, gate, prompt, Gemma) and saves answers, '
            'citations and timings as JSON after each one. About 25 minutes: '
            'keep the screen on. Use a release build.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: state.isRunning ? null : controller.run,
                child: const Text('Run'),
              ),
              const SizedBox(width: 8),
              if (state.isRunning)
                OutlinedButton(
                  onPressed: controller.cancel,
                  child: const Text('Stop after this question'),
                ),
            ],
          ),
          if (state.isRunning) ...[
            const SizedBox(height: 16),
            Text('Question ${state.results.length + 1} of ${state.total}'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: state.total == 0
                  ? null
                  : state.results.length / state.total,
            ),
          ],
          if (state.errorMessage case final message?) ...[
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (state.results.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              state.status == AnswerEvalStatus.running
                  ? 'So far'
                  : 'Results (${state.status.name})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Answered ${summary['answered_answerable']}/'
              '${summary['answerable']} answerable · declined '
              '${summary['declined_unanswerable']}/${summary['unanswerable']} '
              'unanswerable',
            ),
            Text(
              'Right page in the prompt: ${summary['source_hit']} · '
              'cited: ${summary['cites_right_page']}',
            ),
            Text(
              'Median first word ${_s(summary['median_ttft_ms'])} · '
              '${_rate(summary['median_tokens_per_second'])} tok/s',
            ),
            if (state.exportPath case final path?) ...[
              const SizedBox(height: 8),
              SelectableText(
                'Saved to $path',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const Divider(height: 32),
            for (final r in state.results.reversed) _ResultTile(result: r),
          ],
        ],
      ),
    );
  }

  static String _rate(Object? rate) =>
      rate is num ? rate.toStringAsFixed(2) : '–';

  static String _s(Object? ms) =>
      ms is num ? '${(ms / 1000).toStringAsFixed(1)} s' : '–';
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final AnswerEvalResult result;

  @override
  Widget build(BuildContext context) {
    final q = result.question;
    final verdict = switch (result) {
      AnswerEvalResult(error: final e?) => 'error: $e',
      AnswerEvalResult(refusedByGate: true) => 'gate: not found',
      AnswerEvalResult(modelSaidNotFound: true) => 'model: not found',
      _ =>
        'cites ${result.parsed.citations.map((c) => '${c.documentTitle} '
            'p.${c.page}').join(', ')}',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${q.id} · ${q.question}'),
      subtitle: Text(
        '$verdict\n${result.answer}',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
