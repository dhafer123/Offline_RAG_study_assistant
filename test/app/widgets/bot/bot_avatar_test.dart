import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/features/benchmark/presentation/bot_preview_screen.dart';

void main() {
  Future<void> pumpBot(
    WidgetTester tester,
    BotMood mood, {
    bool disableAnimations = false,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: BotAvatar(mood: mood)),
      ),
    ),
  );

  testWidgets('paints every mood, with a label for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final mood in BotMood.values) {
      await pumpBot(tester, mood);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull, reason: mood.name);
      expect(find.bySemanticsLabel(mood.label), findsOne, reason: mood.name);
    }
    semantics.dispose();
  });

  testWidgets('a still mood stops animating after its bounce', (
    tester,
  ) async {
    await pumpBot(tester, BotMood.thinking);
    expect(tester.binding.hasScheduledFrame, isTrue);

    await pumpBot(tester, BotMood.happy);
    await tester.pump(const Duration(seconds: 1));

    // No loop, no blink: nothing repaints until the mood changes again.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a looping mood keeps animating', (tester) async {
    await pumpBot(tester, BotMood.talking);
    await tester.pump(const Duration(seconds: 2));

    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('holds still when the phone turns animations off', (
    tester,
  ) async {
    await pumpBot(tester, BotMood.thinking, disableAnimations: true);
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);

    await pumpBot(tester, BotMood.searching, disableAnimations: true);
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the preview screen shows every mood and plays an answer', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BotPreviewScreen()));

    await tester.tap(find.text('Play an answer'));
    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
    // Back to idle at the end of the demo answer.
    final idle = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'idle'),
    );
    expect(idle.selected, isTrue);
  });
}
