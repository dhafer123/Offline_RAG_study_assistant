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

  /// Provisional "not found" gate threshold (task 3.3); task 3.7 tunes it.
  ///
  /// On the eval set's vector run (`eval/results/retrieval_vector_*.json`)
  /// it refuses 2 of the 10 unanswerable questions and 2 of the 50
  /// answerable ones (best similarities 0.265 and 0.272, both French
  /// questions on English documents). The two groups overlap a lot, so the
  /// prompt's "reply Not found" rule is the second line of defense.
  static const defaultSimilarityThreshold = 0.30;

  /// Below this cosine similarity of the best chunk, the question is
  /// answered "not found" without calling the LLM.
  final double similarityThreshold;

  /// How many chunks are retrieved and offered to the prompt as sources.
  final int topK;

  /// Token budget of the whole prompt (see `buildAnswerPrompt`).
  final int promptBudget;
}
