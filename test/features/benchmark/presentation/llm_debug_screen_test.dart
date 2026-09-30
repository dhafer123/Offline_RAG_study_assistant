import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/features/benchmark/presentation/llm_debug_screen.dart';

import '../../../helpers/fake_llm_engine.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, FakeLlmEngine engine) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [llmEngineProvider.overrideWithValue(engine)],
        child: const MaterialApp(home: LlmDebugScreen()),
      ),
    );
  }

  testWidgets('shows the streamed answer after Generate', (tester) async {
    await pumpScreen(tester, FakeLlmEngine(tokens: ['RAG ', 'retrieves.']));

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(find.text('RAG retrieves.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('shows the error message when loading fails', (tester) async {
    await pumpScreen(
      tester,
      FakeLlmEngine(loadError: const LlmException('Model file not found')),
    );

    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(find.text('Model file not found'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
  });
}
