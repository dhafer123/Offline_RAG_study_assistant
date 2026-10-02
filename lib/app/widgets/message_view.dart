import 'package:flutter/material.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';

/// The bot (in [mood]), a title and an explanation, for empty and error
/// states.
class MessageView extends StatelessWidget {
  const MessageView({
    required this.mood,
    required this.title,
    required this.body,
    this.action,
    this.isError = false,
    super.key,
  });

  final BotMood mood;
  final String title;
  final String body;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BotAvatar(mood: mood, size: 128),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isError ? scheme.error : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
