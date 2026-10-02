import 'dart:async';

import 'package:flutter/material.dart';
import 'package:offline_study_assistant/app/theme.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_painter.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_says.dart';

/// Every mood of the assistant bot, at the sizes the app uses, to check how
/// it looks before it goes into the screens.
class BotPreviewScreen extends StatefulWidget {
  const BotPreviewScreen({super.key});

  @override
  State<BotPreviewScreen> createState() => _BotPreviewScreenState();
}

class _BotPreviewScreenState extends State<BotPreviewScreen> {
  BotMood _mood = BotMood.idle;
  Timer? _demo;

  /// Plays an answer's moods with roughly the phone's timings (sped up).
  static const List<(BotMood, Duration)> _answer = [
    (BotMood.searching, Duration(milliseconds: 1500)),
    (BotMood.thinking, Duration(seconds: 5)),
    (BotMood.talking, Duration(seconds: 3)),
    (BotMood.happy, Duration(seconds: 2)),
    (BotMood.idle, Duration.zero),
  ];

  void _playAnswer([int step = 0]) {
    _demo?.cancel();
    final (mood, duration) = _answer[step];
    setState(() => _mood = mood);
    if (step + 1 < _answer.length) {
      _demo = Timer(duration, () => _playAnswer(step + 1));
    }
  }

  @override
  void dispose() {
    _demo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bot preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: BotAvatar(mood: _mood, size: 160)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mood in BotMood.values)
                ChoiceChip(
                  label: Text(mood.name),
                  selected: mood == _mood,
                  onSelected: (_) {
                    _demo?.cancel();
                    setState(() => _mood = mood);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play an answer'),
              onPressed: _playAnswer,
            ),
          ),
          _section(theme, 'All moods'),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            runSpacing: 12,
            children: [
              for (final mood in BotMood.values)
                SizedBox(
                  width: 104,
                  child: Column(
                    children: [
                      BotAvatar(mood: mood, size: 88),
                      Text(mood.name, style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
            ],
          ),
          _section(theme, 'Sizes (chat avatar: head only)'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final size in [24.0, 32.0, 40.0])
                BotAvatar(mood: _mood, size: size, showBody: false),
              for (final size in [56.0, 96.0])
                BotAvatar(mood: _mood, size: size),
            ],
          ),
          _section(theme, 'On light and dark backgrounds'),
          Row(
            children: [
              for (final brightness in Brightness.values)
                Expanded(
                  child: Container(
                    height: 120,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: brightness == Brightness.light
                          ? AppTheme.light.colorScheme.surface
                          : AppTheme.dark.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(child: BotAvatar(mood: _mood, size: 96)),
                  ),
                ),
            ],
          ),
          _section(theme, 'Speech bubble'),
          BotSays.text(
            mood: BotMood.happy,
            text:
                'Hi! I answer questions about your course PDFs, and I show '
                'you the pages I used.',
          ),
          const SizedBox(height: 12),
          BotSays.text(
            mood: BotMood.thinking,
            botSize: 44,
            text: 'Reading 3 sources… 12 s',
          ),
          const SizedBox(height: 24),
          Text(
            'Colors: helmet ${_hex(BotColors.helmet)}, visor '
            '${_hex(BotColors.visor)}, eyes ${_hex(BotColors.eye)}, ears '
            '${_hex(BotColors.ear)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Widget _section(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
    child: Text(title, style: theme.textTheme.titleMedium),
  );

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
