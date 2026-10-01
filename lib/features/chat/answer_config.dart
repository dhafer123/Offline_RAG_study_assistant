import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';

/// Tunable settings of the answering pipeline, in one place.
@immutable
class AnswerConfig {
  const AnswerConfig({
    this.similarityThreshold = defaultSimilarityThreshold,
    this.topK = 5,
    this.promptBudget = defaultPromptBudget,
  });

  /// "Not found" gate threshold, chosen in task 3.7 (docs/METRICS.md).
  ///
  /// On the eval set it refuses 2 of the 10 unanswerable questions (both
  /// off-topic) and 2 of the 50 answerable ones, only one of which had its
  /// answer among the sources the prompt would have held. No threshold
  /// catches the near misses (topic present, fact absent) without refusing
  /// many answerable questions, so the gate only screens out clearly
  /// off-topic questions; the prompt's "reply Not found" rule handles the
  /// rest.
  static const defaultSimilarityThreshold = 0.30;

  /// Below this cosine similarity of the best chunk, the question is
  /// answered "not found" without calling the LLM.
  final double similarityThreshold;

  /// How many chunks are retrieved and offered to the prompt as sources.
  final int topK;

  /// Token budget of the whole prompt (see `buildAnswerPrompt`).
  final int promptBudget;
}
