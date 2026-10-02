import 'package:flutter/material.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';

/// The bot with a speech bubble next to it.
class BotSays extends StatelessWidget {
  const BotSays({
    required this.mood,
    required this.child,
    this.botSize = 56,
    super.key,
  });

  /// A line of text in the bubble.
  BotSays.text({
    required BotMood mood,
    required String text,
    double botSize = 56,
    Key? key,
  }) : this(mood: mood, botSize: botSize, key: key, child: Text(text));

  final BotMood mood;
  final double botSize;

  /// The bubble's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        BotAvatar(mood: mood, size: botSize),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: EdgeInsets.only(bottom: botSize * 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              // The small corner points at the bot.
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onSurface),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
