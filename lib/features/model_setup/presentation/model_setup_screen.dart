import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';

/// First launch: downloads the model once (task 1.6). The router sends every
/// route here until the model is ready.
class ModelSetupScreen extends ConsumerWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentModelStateProvider);
    final wifiOnly = ref.watch(wifiOnlyDownloadsProvider);
    final manager = ref.read(modelManagerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set up')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Download the AI model', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Answers are generated on your phone. The model '
            '(${formatMegabytes(_totalBytes(state))}) is downloaded once; '
            'after that the app works fully offline.',
          ),
          const SizedBox(height: 8),
          Text(
            'Gemma is provided under and subject to the Gemma Terms of Use '
            'found at ai.google.dev/gemma/terms. By downloading it you agree '
            'to its use restrictions (ai.google.dev/gemma/prohibited_use_policy).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Download on Wi-Fi only'),
            value: wifiOnly,
            onChanged: (value) =>
                ref.read(wifiOnlyDownloadsProvider.notifier).set(value: value),
          ),
          const SizedBox(height: 24),
          ..._body(context, state, manager),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    ModelState state,
    ModelManager manager,
  ) {
    final theme = Theme.of(context);
    return switch (state) {
      ModelChecking(:final verifying) => [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(verifying ? 'Verifying the model…' : 'Checking the model…'),
      ],
      ModelNotDownloaded(:final partialBytes, :final totalBytes) => [
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: Text(
            partialBytes > 0
                ? 'Resume (${formatProgress(partialBytes, totalBytes)})'
                : 'Download (${formatMegabytes(totalBytes)})',
          ),
          onPressed: manager.download,
        ),
      ],
      ModelDownloading(:final receivedBytes, :final totalBytes) => [
        LinearProgressIndicator(value: state.fraction),
        const SizedBox(height: 8),
        Text(
          '${formatProgress(receivedBytes, totalBytes)} · '
          '${(state.fraction * 100).floor()}%',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.pause),
          label: const Text('Pause'),
          onPressed: manager.pause,
        ),
      ],
      ModelFailed(:final kind, :final partialBytes, :final totalBytes) => [
        Text(
          errorMessage(kind),
          style: TextStyle(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text(
            partialBytes > 0
                ? 'Resume (${formatProgress(partialBytes, totalBytes)})'
                : 'Try again',
          ),
          onPressed: manager.download,
        ),
      ],
      ModelReady() => [const Text('The model is ready.')],
    };
  }

  static int? _totalBytes(ModelState state) => switch (state) {
    ModelNotDownloaded(:final totalBytes) ||
    ModelDownloading(:final totalBytes) ||
    ModelFailed(:final totalBytes) => totalBytes,
    _ => null,
  };
}

/// "557 MB" (binary megabytes, as Android's storage settings show them).
String formatMegabytes(int? bytes) {
  if (bytes == null) return 'about 560 MB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}

/// "123 of 557 MB".
String formatProgress(int receivedBytes, int totalBytes) =>
    '${(receivedBytes / (1024 * 1024)).floor()} of '
    '${formatMegabytes(totalBytes)}';

String errorMessage(ModelErrorKind kind) => switch (kind) {
  ModelErrorKind.wifiRequired =>
    'Waiting for Wi-Fi. Connect to Wi-Fi, or turn off "Download on Wi-Fi '
        'only".',
  ModelErrorKind.network =>
    'The download was interrupted. Check your connection and try again.',
  ModelErrorKind.server =>
    "The download server didn't respond as expected. Try again later.",
  ModelErrorKind.checksum =>
    'The downloaded file was damaged, so it was deleted. Try again.',
  ModelErrorKind.storage =>
    "Couldn't save the model. Free up about 600 MB of storage and try again.",
};
