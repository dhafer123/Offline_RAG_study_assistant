import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/features/benchmark/llm_debug_controller.dart';

class LlmDebugScreen extends ConsumerWidget {
  const LlmDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(llmDebugControllerProvider);
    final controller = ref.read(llmDebugControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('LLM debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Prompt', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          const Text(LlmDebugController.prompt),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: state.isBusy ? null : controller.run,
                child: const Text('Generate'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: state.status == LlmDebugStatus.generating
                    ? controller.stop
                    : null,
                child: const Text('Stop'),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(_statusLabel(state.status))),
            ],
          ),
          if (state.isBusy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (state.errorMessage case final message?
              when state.status == LlmDebugStatus.error) ...[
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          SelectableText(state.output),
        ],
      ),
    );
  }

  static String _statusLabel(LlmDebugStatus status) => switch (status) {
    LlmDebugStatus.idle => 'Idle',
    LlmDebugStatus.loading => 'Loading model…',
    LlmDebugStatus.generating => 'Generating…',
    LlmDebugStatus.done => 'Done',
    LlmDebugStatus.error => 'Error',
  };
}
