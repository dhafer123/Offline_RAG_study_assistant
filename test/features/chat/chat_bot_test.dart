import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/features/chat/chat_bot.dart';
import 'package:offline_study_assistant/features/chat/chat_controller.dart';

import '../../helpers/fake_answer_service.dart';

void main() {
  ChatExchange exchange(ExchangePhase phase, {String answer = '', int n = 3}) =>
      ChatExchange(
        question: 'Why Godot?',
        phase: phase,
        answer: answer,
        sources: [
          for (var i = 1; i <= n; i++)
            FakeAnswerService.chunk(i, 'game.pdf', i, 'text $i'),
        ],
      );

  group('moodForExchange', () {
    test('follows the pipeline', () {
      expect(
        moodForExchange(exchange(ExchangePhase.searching)),
        BotMood.searching,
      );
      expect(
        moodForExchange(exchange(ExchangePhase.loadingModel)),
        BotMood.thinking,
      );
      expect(
        moodForExchange(exchange(ExchangePhase.generating)),
        BotMood.thinking,
      );
      expect(
        moodForExchange(exchange(ExchangePhase.generating, answer: 'Godot')),
        BotMood.talking,
      );
      expect(
        moodForExchange(exchange(ExchangePhase.done, answer: 'Godot [1].')),
        BotMood.happy,
      );
    });

    test('is confused when nothing was found, by the gate or the model', () {
      expect(
        moodForExchange(
          exchange(
            ExchangePhase.notFound,
            answer: 'Not found in your documents.',
          ),
        ),
        BotMood.confused,
      );
      expect(
        moodForExchange(
          exchange(
            ExchangePhase.done,
            answer: 'Introuvable dans vos documents.',
          ),
        ),
        BotMood.confused,
      );
    });

    test('is sad on errors and calm when stopped', () {
      expect(moodForExchange(exchange(ExchangePhase.error)), BotMood.sad);
      expect(moodForExchange(exchange(ExchangePhase.stopped)), BotMood.idle);
    });
  });

  group('waitingMessage', () {
    test('says what is happening before the first word', () {
      expect(
        waitingMessage(exchange(ExchangePhase.searching), Duration.zero),
        'Searching your documents…',
      );
      expect(
        waitingMessage(exchange(ExchangePhase.loadingModel), Duration.zero),
        'Loading the model…',
      );
      expect(
        waitingMessage(
          exchange(ExchangePhase.generating),
          const Duration(seconds: 3),
        ),
        'Reading 3 sources…',
      );
      expect(
        waitingMessage(
          exchange(ExchangePhase.generating, n: 1),
          const Duration(seconds: 3),
        ),
        'Reading 1 source…',
      );
    });

    test('changes during the long prefill wait', () {
      final x = exchange(ExchangePhase.generating);
      expect(
        waitingMessage(x, const Duration(seconds: 8)),
        'Thinking it over…',
      );
      expect(waitingMessage(x, const Duration(seconds: 16)), 'Almost there…');
      expect(waitingMessage(x, const Duration(minutes: 1)), 'Almost there…');
    });

    test('is null once words arrive or the answer ended', () {
      expect(
        waitingMessage(
          exchange(ExchangePhase.generating, answer: 'Godot'),
          Duration.zero,
        ),
        isNull,
      );
      expect(
        waitingMessage(exchange(ExchangePhase.done), Duration.zero),
        isNull,
      );
    });
  });
}
