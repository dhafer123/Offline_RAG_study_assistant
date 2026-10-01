import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_model_config.dart';
import 'package:offline_study_assistant/features/benchmark/llm_benchmark.dart';
import 'package:offline_study_assistant/features/benchmark/llm_benchmark_controller.dart';
import 'package:offline_study_assistant/features/benchmark/prompt_sweep_controller.dart';

class LlmBenchmarkScreen extends ConsumerWidget {
  const LlmBenchmarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(llmBenchmarkControllerProvider);
    final controller = ref.read(llmBenchmarkControllerProvider.notifier);
    final model = ref.watch(activeLlmModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('LLM benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Unloads and reloads the model, then answers a fixed prompt, '
            '${state.totalRuns} times. Use a release build.',
          ),
          const SizedBox(height: 16),
          DropdownButton<LlmModelConfig>(
            value: model,
            isExpanded: true,
            items: [
              for (final config in LlmModelConfig.benchmarkModels)
                DropdownMenuItem(value: config, child: Text(config.name)),
            ],
            onChanged: state.isRunning
                ? null
                : (config) {
                    if (config == null) return;
                    ref.read(activeLlmModelProvider.notifier).select(config);
                  },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: state.isRunning ? null : controller.run,
                child: const Text('Run benchmark'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: state.isRunning ? controller.cancel : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (state.isRunning) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.runs.length / state.totalRuns,
            ),
            const SizedBox(height: 4),
            Text('Run ${state.runs.length + 1} of ${state.totalRuns}…'),
          ],
          if (state.errorMessage case final message?) ...[
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (state.result case final result?) ...[
            const SizedBox(height: 16),
            _ResultCard(result: result),
          ],
          if (state.runs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Runs', style: theme.textTheme.titleSmall),
            for (final (i, run) in state.runs.indexed)
              Text(
                '${i + 1}. load ${_s(run.loadTime)} · '
                'TTFT ${_s(run.generation.timeToFirstToken)} · '
                '${run.generation.outputTokens} tok · '
                '${run.generation.tokensPerSecond?.toStringAsFixed(2) ?? '–'}'
                ' tok/s',
                style: theme.textTheme.bodySmall,
              ),
          ],
          const Divider(height: 32),
          const _PromptSweepSection(),
        ],
      ),
    );
  }

  static String _s(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(2)} s';
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final LlmBenchmarkResult result;

  @override
  Widget build(BuildContext context) {
    final summary = result.summary();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Median of ${result.runs.length} runs',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('Load: ${result.medianLoadSeconds.toStringAsFixed(2)} s'),
            Text(
              'Cold load (run 1): '
              '${result.coldLoadSeconds.toStringAsFixed(2)} s',
            ),
            Text(
              'Time to first token: '
              '${result.medianTimeToFirstTokenSeconds.toStringAsFixed(2)} s',
            ),
            Text(
              'Tokens/sec: '
              '${result.medianTokensPerSecond?.toStringAsFixed(2) ?? '–'}',
            ),
            Text(
              'Output tokens: ${result.medianOutputTokens.toStringAsFixed(0)}'
              ' · prompt tokens: ${result.promptTokens ?? '–'}',
            ),
            Text('Peak RSS: ${result.peakRssMb ?? '–'} MB'),
            const SizedBox(height: 8),
            Text(
              'Answer (run 1)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SelectableText(result.runs.first.answer),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy summary'),
              onPressed: () => Clipboard.setData(ClipboardData(text: summary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time to first token against prompt size, with the model kept loaded.
class _PromptSweepSection extends ConsumerWidget {
  const _PromptSweepSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptSweepControllerProvider);
    final controller = ref.read(promptSweepControllerProvider.notifier);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prompt-length sweep', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Builds RAG prompts of 200 to 2,450 tokens from the indexed '
          'documents and measures time to first token, 3 runs each.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: state.isRunning ? null : controller.run,
              child: const Text('Run sweep'),
            ),
            const SizedBox(width: 8),
            if (state.isRunning) ...[
              OutlinedButton(
                onPressed: controller.cancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Text(
                state.total == 0
                    ? 'Warming up…'
                    : 'Run ${state.done}/${state.total}',
              ),
            ],
          ],
        ),
        if (state.errorMessage case final message?) ...[
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        for (final m in state.medians)
          Text(
            'target ${m.target} → ${m.promptTokens ?? '?'} tokens: '
            'TTFT ${m.ttftSeconds.toStringAsFixed(2)} s',
          ),
        if (state.exportPath case final path?) ...[
          const SizedBox(height: 8),
          SelectableText('Saved to $path', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
