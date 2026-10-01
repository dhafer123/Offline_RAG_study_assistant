import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// Token budget of the whole prompt (instructions, sources and question), in
/// [estimateTokens] units.
///
/// The model pads every prompt up to one of its fixed prefill sizes (256,
/// 512, 1024, 2560 tokens), and time to first token follows the padded size:
/// ~8.5 s up to 512, ~17 s up to 1024, ~44 s up to 2560 on the test phone
/// (docs/METRICS.md). 1000 estimated tokens is at most ~930 real ones (the
/// estimate ran 1.08–1.23× the real count, chat template included), so the
/// prompt stays in the 1024 step with room for about 4 sources.
const defaultPromptBudget = 1000;

/// What the model must reply when the sources don't hold the answer. Also
/// what the "not found" gate shows (task 3.3), so both read the same.
const Map<AnswerLanguage, String> notFoundReplies = {
  AnswerLanguage.english: 'Not found in your documents.',
  AnswerLanguage.french: 'Introuvable dans vos documents.',
};

final Set<String> _notFoundKeys = {
  for (final reply in notFoundReplies.values) _lettersOnly(reply),
};

String _lettersOnly(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');

/// Whether the model's [answer] is the "not found" reply (in either
/// language), ignoring case, punctuation and citation markers.
bool isNotFoundReply(String answer) =>
    _notFoundKeys.contains(_lettersOnly(answer));

/// Counts (or estimates) the tokens of a text.
typedef TokenCounter = int Function(String text);

final _letters = RegExp(r'\p{L}+', unicode: true);
final _symbols = RegExp(r'[^\p{L}\s]', unicode: true);

/// Estimates Gemma 3's token count without the tokenizer (which needs the
/// loaded model): one token per word plus one per 6 further letters, and one
/// per digit or punctuation mark (Gemma splits digits one by one).
///
/// Checked against the real tokenizer on the eval PDFs' chunks: 500 prompts
/// of 5 sources were estimated at 0.98–1.23× their real size (median 1.12).
/// A flat "characters / 3" was 1.54× on prose but under on digit-heavy
/// pages such as a table of contents. See docs/METRICS.md.
int estimateTokens(String text) {
  var tokens = 0;
  for (final word in _letters.allMatches(text)) {
    tokens += 1 + (word[0]!.length - 1) ~/ 6;
  }
  return tokens + _symbols.allMatches(text).length;
}

/// Thrown when the question alone leaves no room for any source.
class PromptTooLongException implements Exception {
  const PromptTooLongException(this.questionTokens, this.budget);

  final int questionTokens;
  final int budget;

  @override
  String toString() =>
      'PromptTooLongException: the question takes ~$questionTokens tokens, '
      'budget $budget';
}

/// A prompt ready for `LlmEngine.generate`.
@immutable
class AnswerPrompt {
  const AnswerPrompt({
    required this.text,
    required this.sources,
    required this.language,
    required this.estimatedTokens,
    required this.truncatedLast,
    required this.droppedSources,
  });

  final String text;

  /// The chunks in the prompt: `sources[n - 1]` is source `[n]`. This is
  /// what the citation parser (task 3.4) maps `[n]` markers back to.
  final List<RetrievedChunk> sources;
  final AnswerLanguage language;

  /// Size of [text] according to the builder's [TokenCounter].
  final int estimatedTokens;

  /// Whether the last source was cut to fit the budget.
  final bool truncatedLast;

  /// How many of the given chunks were left out to fit the budget.
  final int droppedSources;
}

/// Smallest piece of a source worth keeping when it has to be cut: below
/// this, a fragment is more likely to mislead than to help.
const _minSourceTokens = 60;

final _whitespace = RegExp(r'\s+');

// "[12]", "[3, 4]", "[1–3]": reference markers inside the course text. They
// would look like our citation markers, so they're rewritten as "(12)".
final _bracketNumbers = RegExp(r'\[(\s*\d+(?:\s*[,;–-]\s*\d+)*\s*)\]');

/// Builds the grounded prompt for [question] from [chunks] (best first).
///
/// Sources are numbered `[1]`, `[2]`… in the given order, and the whole
/// prompt stays within [budget] tokens: sources that don't fit are dropped
/// from the end, and the first one that only partly fits is cut at a word
/// boundary if at least ~60 tokens of it fit.
/// [countTokens] defaults to [estimateTokens].
///
/// Throws [ArgumentError] if [chunks] is empty (the "not found" gate answers
/// before a prompt is built) and [PromptTooLongException] if no source fits.
AnswerPrompt buildAnswerPrompt(
  String question,
  List<RetrievedChunk> chunks, {
  int budget = defaultPromptBudget,
  TokenCounter countTokens = estimateTokens,
}) {
  if (chunks.isEmpty) {
    throw ArgumentError.value(chunks, 'chunks', 'needs at least one source');
  }
  final q = question.trim().replaceAll(_whitespace, ' ');
  final language = detectQuestionLanguage(q);
  final head = _instructions(language);
  String assemble(List<String> blocks) =>
      '$head\nSources:\n\n${blocks.join('\n')}\nQuestion: $q';
  bool fits(List<String> blocks) => countTokens(assemble(blocks)) <= budget;

  final blocks = <String>[];
  final sources = <RetrievedChunk>[];
  var truncated = false;
  for (final chunk in chunks) {
    final label = '[${sources.length + 1}] ${_cite(chunk)}\n';
    final text = _sourceText(chunk.chunk.text);
    final full = '$label$text\n';
    if (fits([...blocks, full])) {
      blocks.add(full);
      sources.add(chunk);
      continue;
    }
    // Cut this source to what's left, then stop: later sources rank lower.
    final words = text.split(' ');
    String cutBlock(int n) => '$label${words.take(n).join(' ')}…\n';
    final kept = _maxWords(words.length, (n) => fits([...blocks, cutBlock(n)]));
    if (kept > 0 &&
        countTokens(words.take(kept).join(' ')) >= _minSourceTokens) {
      blocks.add(cutBlock(kept));
      sources.add(chunk);
      truncated = true;
    }
    break;
  }
  if (sources.isEmpty) {
    throw PromptTooLongException(countTokens(assemble(const [])), budget);
  }

  final text = assemble(blocks);
  return AnswerPrompt(
    text: text,
    sources: List.unmodifiable(sources),
    language: language,
    estimatedTokens: countTokens(text),
    truncatedLast: truncated,
    droppedSources: chunks.length - sources.length,
  );
}

String _instructions(AnswerLanguage language) {
  final answerIn = switch (language) {
    AnswerLanguage.english => 'English',
    AnswerLanguage.french => 'French',
  };
  return '''
You answer a student's question using only the numbered sources from their course documents.

Rules:
- Use only the information in the sources. Do not add outside knowledge.
- After each sentence, cite the sources it uses with their numbers in square brackets, like [1] or [2][3].
- Answer in $answerIn, even if the sources are in another language.
- Keep the answer short: a few sentences or a short list.
- If the sources do not contain the answer, reply only: ${notFoundReplies[language]}
''';
}

String _cite(RetrievedChunk chunk) =>
    '${chunk.documentTitle}, page ${chunk.page}';

/// The chunk's text on as few lines as possible: blank lines and line breaks
/// cost tokens and carry little for the model. Reference markers become
/// "(n)".
String _sourceText(String text) => text
    .replaceAllMapped(_bracketNumbers, (m) => '(${m[1]!.trim()})')
    .replaceAll(_whitespace, ' ')
    .trim();

/// The largest n in 0..[max] with [ok] true, assuming [ok] holds up to some
/// n and fails after (more words never fit better).
int _maxWords(int max, bool Function(int n) ok) {
  var lo = 0;
  var hi = max;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (ok(mid)) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}
