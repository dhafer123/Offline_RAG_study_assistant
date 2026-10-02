import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/features/model_setup/presentation/model_setup_screen.dart';

import '../../../helpers/fake_model_manager.dart';

void main() {
  const total = 768233071; // 733 MB, the three files
  const mb = 1024 * 1024;

  late FakeModelManager manager;
  late FakeAppSettings settings;

  Future<void> pumpScreen(WidgetTester tester, ModelState state) async {
    manager = FakeModelManager(state);
    settings = FakeAppSettings();
    // A phone-sized window: the screen scrolls on smaller ones.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWithValue(settings),
          modelManagerProvider.overrideWithValue(manager),
        ],
        child: const MaterialApp(home: ModelSetupScreen()),
      ),
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
  }

  testWidgets('explains the app before the download', (tester) async {
    await pumpScreen(tester, const ModelNotDownloaded(totalBytes: total));

    expect(find.text("Hi, I'm Lumi!"), findsOneWidget);
    expect(find.text('Your study assistant in PageWise'), findsOneWidget);
    expect(findBot(BotMood.happy), findsOneWidget);
    expect(find.text('Works offline'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.textContaining('800 MB of free storage'), findsOneWidget);
  });

  testWidgets('offers the download with its size', (tester) async {
    await pumpScreen(tester, const ModelNotDownloaded(totalBytes: total));

    expect(find.textContaining('(733 MB) are downloaded once'), findsOneWidget);
    expect(find.textContaining('Gemma Terms of Use'), findsOneWidget);
    await tapText(tester, 'Download (733 MB)');

    expect(manager.downloadCalls, 1);
  });

  testWidgets('offers to resume an interrupted download', (tester) async {
    await pumpScreen(
      tester,
      const ModelNotDownloaded(partialBytes: 200 * mb, totalBytes: total),
    );

    await tapText(tester, 'Resume (200 of 733 MB)');

    expect(manager.downloadCalls, 1);
  });

  testWidgets('shows progress and can pause', (tester) async {
    await pumpScreen(
      tester,
      const ModelDownloading(receivedBytes: 366 * mb, totalBytes: total),
    );

    expect(find.text('366 of 733 MB · 49%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(366 * mb / total, 1e-9));

    await tapText(tester, 'Pause');
    expect(manager.pauseCalls, 1);
  });

  testWidgets('follows state changes', (tester) async {
    await pumpScreen(tester, const ModelChecking());
    expect(find.text('Checking the models…'), findsOneWidget);

    manager.emit(const ModelChecking(verifying: true));
    await tester.pump();

    expect(find.text('Verifying the models…'), findsOneWidget);
  });

  testWidgets('explains a failure and retries from the kept bytes', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const ModelFailed(
        ModelErrorKind.network,
        partialBytes: 300 * mb,
        totalBytes: total,
      ),
    );

    expect(find.text(errorMessage(ModelErrorKind.network)), findsOneWidget);
    await tapText(tester, 'Resume (300 of 733 MB)');

    expect(manager.downloadCalls, 1);
  });

  testWidgets('the Wi-Fi only switch is saved', (tester) async {
    await pumpScreen(tester, const ModelNotDownloaded(totalBytes: total));

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(settings.wifiOnlyDownloads, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  test("the bot's mood follows the download", () {
    expect(moodForModelState(const ModelChecking()), BotMood.searching);
    expect(
      moodForModelState(const ModelNotDownloaded(totalBytes: total)),
      BotMood.happy,
    );
    expect(
      moodForModelState(
        const ModelDownloading(receivedBytes: 1, totalBytes: total),
      ),
      BotMood.thinking,
    );
    expect(
      moodForModelState(
        const ModelFailed(ModelErrorKind.wifiRequired, totalBytes: total),
      ),
      BotMood.surprised,
    );
    expect(
      moodForModelState(
        const ModelFailed(ModelErrorKind.network, totalBytes: total),
      ),
      BotMood.sad,
    );
  });

  test('every error kind has a message', () {
    for (final kind in ModelErrorKind.values) {
      expect(errorMessage(kind), isNotEmpty);
    }
  });
}

Finder findBot(BotMood mood) =>
    find.byWidgetPredicate((w) => w is BotAvatar && w.mood == mood);
