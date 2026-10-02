import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';

/// First launch: explains the app, then downloads the model once (task 1.6).
/// The router sends every route here until the model is ready.
class ModelSetupScreen extends ConsumerWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentModelStateProvider);
    final wifiOnly = ref.watch(wifiOnlyDownloadsProvider);
    final manager = ref.read(modelManagerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: BotAvatar(mood: moodForModelState(state), size: 144),
              ),
              const SizedBox(height: 12),
              Text(
                "Hi, I'm your Study Assistant",
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask me questions about your course PDFs: I answer from them '
                'and show you the pages I used.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _Feature(
                icon: Icons.wifi_off,
                title: 'Works offline',
                body:
                    'Search and answers run on this phone. After this setup, '
                    'no internet connection is needed.',
              ),
              const _Feature(
                icon: Icons.lock_outline,
                title: 'Private',
                body: 'Your PDFs and questions never leave the phone.',
              ),
              const _Feature(
                icon: Icons.find_in_page_outlined,
                title: 'Checkable',
                body:
                    'Tap a citation to open the PDF at the page it came from.',
              ),
              const SizedBox(height: 8),
              Card.outlined(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'One-time download',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The AI model (${formatMegabytes(_totalBytes(state))}) '
                        'is downloaded once and stays on the phone. It needs '
                        'about 600 MB of free storage. If the download is '
                        'interrupted, it resumes where it stopped.',
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Download on Wi-Fi only'),
                        value: wifiOnly,
                        onChanged: (value) => ref
                            .read(wifiOnlyDownloadsProvider.notifier)
                            .set(value: value),
                      ),
                      const SizedBox(height: 8),
                      ..._body(context, state, manager),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gemma is provided under and subject to the Gemma Terms of Use '
                'found at ai.google.dev/gemma/terms. By downloading it you '
                'agree to its use restrictions '
                '(ai.google.dev/gemma/prohibited_use_policy).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bot's face on the setup screen: what the download is doing.
BotMood moodForModelState(ModelState state) => switch (state) {
  ModelChecking() => BotMood.searching,
  ModelNotDownloaded() || ModelReady() => BotMood.happy,
  ModelDownloading() => BotMood.thinking,
  // Waiting for Wi-Fi isn't a failure.
  ModelFailed(kind: ModelErrorKind.wifiRequired) => BotMood.surprised,
  ModelFailed() => BotMood.sad,
};

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
