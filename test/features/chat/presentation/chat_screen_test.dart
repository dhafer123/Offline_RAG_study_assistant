import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/presentation/chat_screen.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';

import '../../../helpers/fake_answer_service.dart';

void main() {
  late FakeAnswerService service;

  final sources = [
    FakeAnswerService.chunk(
      1,
      'game.pdf',
      27,
      'Godot 4 was chosen for its '
          'flexibility.',
    ),
    FakeAnswerService.chunk(2, 'game.pdf', 26, 'Conclusion of the design.'),
  ];

  Future<void> pumpChat(WidgetTester tester) async {
    service = FakeAnswerService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [answerServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
  }

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(find.byType(TextField), question);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
  }

  testWidgets('explains what to do before the first question', (tester) async {
    await pumpChat(tester);

    expect(find.text('Ask a question about your course PDFs.'), findsOne);
    expect(find.byTooltip('Send'), findsOne);
  });

  testWidgets('streams an answer with inline markers and page chips', (
    tester,
  ) async {
    await pumpChat(tester);
    await ask(tester, 'Why Godot?');

    expect(find.text('Why Godot?'), findsOne);
    expect(find.text('Searching your documents…'), findsOne);
    expect(find.byTooltip('Stop'), findsOne);
    expect(find.byType(TextField), findsOne);

    service.emit(FakeAnswerService.sourcesEvent(sources));
    await tester.pump();
    service.emit(const AnswerLoadingModel());
    await tester.pump();
    expect(find.text('Loading the model…'), findsOne);

    // Loaded: now the wait is the model reading the sources.
    service.emit(const AnswerGenerating());
    await tester.pump();
    expect(find.text('Loading the model…'), findsNothing);
    expect(find.text('Reading 2 sources…'), findsOne);

    service.emit(const AnswerToken('Godot is flexible [1].'));
    await tester.pump();
    expect(find.text('Loading the model…'), findsNothing);
    expect(
      find.textContaining('Godot is flexible', findRichText: true),
      findsOne,
    );
    expect(find.text('game.pdf · p. 27'), findsOne);
    // Only cited sources get a chip.
    expect(find.text('game.pdf · p. 26'), findsNothing);

    service.emit(FakeAnswerService.doneEvent('Godot is flexible [1].'));
    await service.close();
    await tester.pump();

    expect(find.byTooltip('Send'), findsOne);
    expect(find.text('First word after 18.4 s · 26.6 s in total'), findsOne);
  });

  testWidgets('shows "Reading n sources…" until the first word', (
    tester,
  ) async {
    await pumpChat(tester);
    await ask(tester, 'Why Godot?');
    service.emit(FakeAnswerService.sourcesEvent(sources));
    await tester.pump();

    expect(find.text('Reading 2 sources…'), findsOne);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
  });

  testWidgets('a chip opens the source passage', (tester) async {
    await pumpChat(tester);
    await ask(tester, 'Why Godot?');
    service
      ..emit(FakeAnswerService.sourcesEvent(sources))
      ..emit(const AnswerToken('Godot is flexible [1].'))
      ..emit(FakeAnswerService.doneEvent('Godot is flexible [1].'));
    await service.close();
    await tester.pump();

    await tester.tap(find.text('game.pdf · p. 27'));
    await tester.pumpAndSettle();

    expect(find.text('[1] game.pdf · page 27'), findsOne);
    expect(find.text('Godot 4 was chosen for its flexibility.'), findsOne);
  });

  testWidgets('stop keeps what was written', (tester) async {
    await pumpChat(tester);
    await ask(tester, 'Why Godot?');
    service
      ..emit(FakeAnswerService.sourcesEvent(sources))
      ..emit(const AnswerToken('Godot is'));
    await tester.pump();

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();

    expect(service.cancelled, isTrue);
    expect(find.textContaining('Godot is', findRichText: true), findsOne);
    expect(find.text('Stopped'), findsOne);
    expect(find.byTooltip('Send'), findsOne);
  });

  testWidgets('shows "not found" without chips', (tester) async {
    await pumpChat(tester);
    await ask(tester, 'Who invented transformers?');
    service.emit(
      const AnswerNotFound(
        message: 'Not found in your documents.',
        language: AnswerLanguage.english,
        retrievalTime: Duration(seconds: 2),
      ),
    );
    await service.close();
    await tester.pump();

    expect(find.text('Not found in your documents.'), findsOne);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('shows an error message', (tester) async {
    await pumpChat(tester);
    await ask(tester, 'Q?');
    service.fail(const AnswerException('Could not load the language model'));
    await tester.pump();

    expect(find.text('Could not load the language model'), findsOne);
    expect(find.byTooltip('Send'), findsOne);
  });

  testWidgets('does not send a blank question', (tester) async {
    await pumpChat(tester);
    await ask(tester, '   ');

    expect(service.questions, isEmpty);
    expect(find.text('Ask a question about your course PDFs.'), findsOne);
  });
}
