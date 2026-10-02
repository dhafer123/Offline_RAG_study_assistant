import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/answer_config.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// What [AnswerService.answer] streams, in order: either [AnswerNotFound]
/// alone, or [AnswerSources], [AnswerLoadingModel] (only when the model
/// isn't loaded yet), [AnswerGenerating], [AnswerToken]s, then [AnswerDone].
@immutable
sealed class AnswerEvent {
  const AnswerEvent();
}

/// The gate refused the question: no chunk is close enough. The LLM was not
/// called.
final class AnswerNotFound extends AnswerEvent {
  const AnswerNotFound({
    required this.message,
    required this.language,
    required this.retrievalTime,
    this.bestSimilarity,
  });

  /// "Not found in your documents." in the question's language.
  final String message;
  final AnswerLanguage language;

  /// Similarity of the closest chunk, or null when nothing is indexed.
  final double? bestSimilarity;
  final Duration retrievalTime;
}

/// The sources given to the model, before it starts writing. `sources[n-1]`
/// is what an `[n]` in the answer refers to.
final class AnswerSources extends AnswerEvent {
  const AnswerSources({
    required this.prompt,
    required this.bestSimilarity,
    required this.retrievalTime,
  });

  final AnswerPrompt prompt;
  final double bestSimilarity;
  final Duration retrievalTime;

  List<RetrievedChunk> get sources => prompt.sources;
}

/// The LLM is being loaded (first question, or after it was unloaded): a
/// few seconds before generation can start.
final class AnswerLoadingModel extends AnswerEvent {
  const AnswerLoadingModel();
}

/// The model is reading the prompt: the wait before the first token (~17 s
/// on the test phone, see docs/METRICS.md).
final class AnswerGenerating extends AnswerEvent {
  const AnswerGenerating();
}

/// A piece of the answer as the model streams it.
final class AnswerToken extends AnswerEvent {
  const AnswerToken(this.text);

  final String text;
}

/// The answer is complete.
final class AnswerDone extends AnswerEvent {
  const AnswerDone({
    required this.text,
    required this.modelLoadTime,
    required this.generation,
  });

  /// The whole answer (all tokens joined).
  final String text;

  /// Time spent loading the LLM for this question (zero once it's loaded).
  final Duration modelLoadTime;
  final GenerationMetrics generation;
}

/// Answering failed. [message] is safe to show to the user.
class AnswerException implements Exception {
  const AnswerException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'AnswerException: $message'
      : 'AnswerException: $message ($cause)';
}

/// Answers a question from the indexed documents: retrieve, gate, prompt,
/// stream.
class AnswerService {
  AnswerService({
    required RetrievalService retrieval,
    required LlmEngine llm,
    this.config = const AnswerConfig(),
    StopwatchFactory stopwatch = Stopwatch.new,
  }) : _retrieval = retrieval,
       _llm = llm,
       _stopwatch = stopwatch;

  final RetrievalService _retrieval;
  final LlmEngine _llm;
  final AnswerConfig config;
  final StopwatchFactory _stopwatch;

  /// Streams the answer to [question] as [AnswerEvent]s.
  ///
  /// Cancelling the subscription stops generation. Errors are emitted as
  /// [AnswerException].
  Stream<AnswerEvent> answer(String question) async* {
    final language = detectQuestionLanguage(question);

    final (chunks, retrievalTime) = await _guard(
      "Couldn't search your documents. Try again; if it keeps failing, "
      'restart the app.',
      () => Perf.time(
        () => _retrieval.retrieve(question, k: config.topK),
        stopwatch: _stopwatch,
      ),
    );
    final best = bestSimilarity(chunks);
    if (best == null || best < config.similarityThreshold) {
      Perf.log(
        'answer gate: not found (best=${best?.toStringAsFixed(3)}, '
        'threshold=${config.similarityThreshold}, '
        'retrieval=${retrievalTime.inMilliseconds}ms)',
      );
      yield AnswerNotFound(
        message: notFoundReplies[language]!,
        language: language,
        bestSimilarity: best,
        retrievalTime: retrievalTime,
      );
      return;
    }

    final AnswerPrompt prompt;
    try {
      prompt = buildAnswerPrompt(
        question,
        chunks,
        budget: config.promptBudget,
      );
    } on PromptTooLongException catch (e) {
      throw AnswerException(
        'This question is too long. Try a shorter one.',
        cause: e,
      );
    }
    yield AnswerSources(
      prompt: prompt,
      bestSimilarity: best,
      retrievalTime: retrievalTime,
    );

    if (!_llm.isLoaded) yield const AnswerLoadingModel();
    final (_, loadTime) = await _guard(
      "Couldn't load the language model. Close other apps to free memory, "
      'then try again.',
      () => Perf.time(_llm.load, stopwatch: _stopwatch),
    );

    yield const AnswerGenerating();
    final timer = GenerationTimer(stopwatch: _stopwatch)..start();
    final answer = StringBuffer();
    try {
      await for (final token in _llm.generate(prompt.text)) {
        timer.onChunk();
        answer.write(token);
        yield AnswerToken(token);
      }
    } on LlmException catch (e) {
      throw AnswerException(
        'The model stopped while answering. Try again.',
        cause: e,
      );
    }
    final usage = _llm.lastUsage;
    final metrics = timer.finish(
      outputTokens: usage?.outputTokens,
      promptTokens: usage?.promptTokens,
    );
    Perf.log(
      'answer: retrieval=${retrievalTime.inMilliseconds}ms '
      'load=${loadTime.inMilliseconds}ms $metrics '
      'sources=${prompt.sources.length} '
      'promptEstimate=${prompt.estimatedTokens}',
    );
    yield AnswerDone(
      text: answer.toString(),
      modelLoadTime: loadTime,
      generation: metrics,
    );
  }

  /// Runs [action], turning embedder and LLM failures into
  /// [AnswerException]s with [message]. The technical detail stays in the
  /// exception's cause (logged, never shown).
  static Future<T> _guard<T>(
    String message,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on EmbedderException catch (e) {
      throw AnswerException(message, cause: e);
    } on LlmException catch (e) {
      throw AnswerException(message, cause: e);
    }
  }
}

/// The best cosine similarity among [chunks], or null if none has one.
///
/// What the gate compares to the threshold. With vector retrieval it's the
/// first chunk's; with hybrid, keyword-only chunks have none and are skipped.
double? bestSimilarity(List<RetrievedChunk> chunks) {
  double? best;
  for (final chunk in chunks) {
    final s = chunk.similarity;
    if (s != null && (best == null || s > best)) best = s;
  }
  return best;
}
