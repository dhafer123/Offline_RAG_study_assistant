import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/features/model_setup/presentation/model_setup_screen.dart';

import '../../../helpers/fake_model_manager.dart';

void main() {
  const total = 584417280; // 557 MB
  const mb = 1024 * 1024;

  late FakeModelManager manager;
  late FakeAppSettings settings;

  Future<void> pumpScreen(WidgetTester tester, ModelState state) async {
    manager = FakeModelManager(state);
    settings = FakeAppSettings();
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

  testWidgets('offers the download with its size', (tester) async {
    await pumpScreen(tester, const ModelNotDownloaded(totalBytes: total));

    expect(find.textContaining('(557 MB) is downloaded once'), findsOneWidget);
    expect(find.textContaining('Gemma Terms of Use'), findsOneWidget);
    await tester.tap(find.text('Download (557 MB)'));

    expect(manager.downloadCalls, 1);
  });

  testWidgets('offers to resume an interrupted download', (tester) async {
    await pumpScreen(
      tester,
      const ModelNotDownloaded(partialBytes: 200 * mb, totalBytes: total),
    );

    await tester.tap(find.text('Resume (200 of 557 MB)'));

    expect(manager.downloadCalls, 1);
  });

  testWidgets('shows progress and can pause', (tester) async {
    await pumpScreen(
      tester,
      const ModelDownloading(receivedBytes: total ~/ 4, totalBytes: total),
    );

    expect(find.text('139 of 557 MB · 25%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.25, 1e-9));

    await tester.tap(find.text('Pause'));
    expect(manager.pauseCalls, 1);
  });

  testWidgets('follows state changes', (tester) async {
    await pumpScreen(tester, const ModelChecking());
    expect(find.text('Checking the model…'), findsOneWidget);

    manager.emit(const ModelChecking(verifying: true));
    await tester.pump();

    expect(find.text('Verifying the model…'), findsOneWidget);
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
    await tester.tap(find.text('Resume (300 of 557 MB)'));

    expect(manager.downloadCalls, 1);
  });

  testWidgets('the Wi-Fi only switch is saved', (tester) async {
    await pumpScreen(tester, const ModelNotDownloaded(totalBytes: total));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(settings.wifiOnlyDownloads, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  test('every error kind has a message', () {
    for (final kind in ModelErrorKind.values) {
      expect(errorMessage(kind), isNotEmpty);
    }
  });
}
