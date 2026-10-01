import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/chat_controller.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';

import '../../helpers/fake_answer_service.dart';

void main() {
  late FakeAnswerService service;
  late ProviderContainer container;

  final sources = [
    FakeAnswerService.chunk(1, 'game.pdf', 27, 'Godot 4 was chosen.'),
    FakeAnswerService.chunk(2, 'game.pdf', 26, 'Conclusion.'),
  ];

  setUp(() {
    service = FakeAnswerService();
    container = ProviderContainer(
      overrides: [answerServiceProvider.overrideWithValue(service)],
    )..listen(chatControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  ChatController controller() =>
      container.read(chatControllerProvider.notifier);
  ChatExchange last() => container.read(chatControllerProvider).exchanges.last;

  test('follows the answer from search to done', () async {
    final asking = controller().ask('  Why Godot?  ');
    await pumpEventQueue();

    expect(service.questions, ['Why Godot?']);
    expect(last().question, 'Why Godot?');
    expect(last().phase, ExchangePhase.searching);
    expect(container.read(chatControllerProvider).isBusy, isTrue);

    service.emit(FakeAnswerService.sourcesEvent(sources));
    await pumpEventQueue();
    expect(last().phase, ExchangePhase.generating);
    expect(last().sources, sources);

    service.emit(const AnswerLoadingModel());
    await pumpEventQueue();
    expect(last().phase, ExchangePhase.loadingModel);

    service.emit(const AnswerGenerating());
    await pumpEventQueue();
    expect(last().phase, ExchangePhase.generating);

    service
      ..emit(const AnswerToken('Godot is flexible '))
      ..emit(const AnswerToken('[1]'));
    await pumpEventQueue();
    expect(last().phase, ExchangePhase.generating);
    expect(last().answer, 'Godot is flexible [1]');

    service.emit(FakeAnswerService.doneEvent('Godot is flexible [1]'));
    await service.close();
    await asking;

    expect(last().phase, ExchangePhase.done);
    expect(last().generation!.outputTokens, 64);
    expect(last().parsed.citations.single.page, 27);
    expect(container.read(chatControllerProvider).isBusy, isFalse);
  });

  test('shows the gate refusal', () async {
    final asking = controller().ask('Who invented transformers?');
    service.emit(
      const AnswerNotFound(
        message: 'Not found in your documents.',
        language: AnswerLanguage.english,
        retrievalTime: Duration(seconds: 2),
        bestSimilarity: 0.25,
      ),
    );
    await service.close();
    await asking;

    expect(last().phase, ExchangePhase.notFound);
    expect(last().answer, 'Not found in your documents.');
    expect(last().parsed.citations, isEmpty);
  });

  test('shows the message of a failure', () async {
    final asking = controller().ask('Q?');
    service.fail(const AnswerException('Could not load the language model'));
    await asking;

    expect(last().phase, ExchangePhase.error);
    expect(last().errorMessage, 'Could not load the language model');
    expect(container.read(chatControllerProvider).isBusy, isFalse);
  });

  test('hides other errors behind a generic message', () async {
    final asking = controller().ask('Q?');
    service.fail(StateError('boom'));
    await asking;

    expect(last().errorMessage, 'Something went wrong while answering.');
  });

  test('stop keeps the partial answer and ends the question', () async {
    final asking = controller().ask('Q?');
    service
      ..emit(FakeAnswerService.sourcesEvent(sources))
      ..emit(const AnswerToken('Godot is'));
    await pumpEventQueue();

    await controller().stop();
    await asking;

    expect(service.cancelled, isTrue);
    expect(last().phase, ExchangePhase.stopped);
    expect(last().answer, 'Godot is');
    expect(container.read(chatControllerProvider).isBusy, isFalse);
  });

  test('ignores blank questions and questions while busy', () async {
    await controller().ask('   ');
    expect(container.read(chatControllerProvider).exchanges, isEmpty);

    controller().ask('First?').ignore();
    await pumpEventQueue();
    controller().ask('Second?').ignore();
    await pumpEventQueue();

    expect(service.questions, ['First?']);
    expect(container.read(chatControllerProvider).exchanges, hasLength(1));
  });

  test('keeps earlier exchanges', () async {
    var asking = controller().ask('First?');
    service.emit(FakeAnswerService.doneEvent(''));
    await service.close();
    await asking;
    asking = controller().ask('Second?');
    await pumpEventQueue();

    final exchanges = container.read(chatControllerProvider).exchanges;
    expect([for (final e in exchanges) e.question], ['First?', 'Second?']);
    expect(exchanges.first.phase, ExchangePhase.done);
    await controller().stop();
    await asking;
  });

  test('hides a citation marker still being streamed', () async {
    final asking = controller().ask('Q?');
    service
      ..emit(FakeAnswerService.sourcesEvent(sources))
      ..emit(const AnswerToken('Godot [1'));
    await pumpEventQueue();

    expect(last().parsed.plainText, 'Godot');
    await controller().stop();
    await asking;
    // Once stopped, the text is shown as it is.
    expect(last().parsed.plainText, 'Godot [1');
  });
}
