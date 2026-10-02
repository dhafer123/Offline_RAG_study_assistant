import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/features/chat/chat_controller.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';

/// The bot's face next to an answer: what the pipeline is doing.
BotMood moodForExchange(ChatExchange exchange) => switch (exchange.phase) {
  ExchangePhase.searching => BotMood.searching,
  ExchangePhase.loadingModel => BotMood.thinking,
  // Prefill (no word yet) is the long wait; then the answer streams.
  ExchangePhase.generating =>
    exchange.answer.isEmpty ? BotMood.thinking : BotMood.talking,
  // The model can also reply "not found" itself.
  ExchangePhase.done =>
    isNotFoundReply(exchange.answer) ? BotMood.confused : BotMood.happy,
  ExchangePhase.notFound => BotMood.confused,
  ExchangePhase.stopped => BotMood.idle,
  ExchangePhase.error => BotMood.sad,
};

/// What the bot says while the user waits, or null once words arrive.
///
/// Prefill takes ~17 s on the test phone with no visible progress, so the
/// message changes as time passes.
String? waitingMessage(ChatExchange exchange, Duration elapsed) {
  if (exchange.answer.isNotEmpty) return null;
  final n = exchange.sources.length;
  return switch (exchange.phase) {
    ExchangePhase.searching => 'Searching your documents…',
    ExchangePhase.loadingModel => 'Loading the model…',
    ExchangePhase.generating when elapsed < const Duration(seconds: 8) =>
      n == 1 ? 'Reading 1 source…' : 'Reading $n sources…',
    ExchangePhase.generating when elapsed < const Duration(seconds: 16) =>
      'Thinking it over…',
    ExchangePhase.generating => 'Almost there…',
    _ => null,
  };
}
