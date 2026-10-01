/// Languages the app answers in.
enum AnswerLanguage { english, french }

final _word = RegExp(r'\p{L}+', unicode: true);
final _frenchLetter = RegExp('[àâæçéèêëîïôœùûüÿ]');

// Short function words that are frequent in questions and rare in the other
// language. "a" counts as English: French questions seldom use the verb
// ("a-t-il") and its accented "à" is caught by _frenchLetter.
const _french = {
  'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux', //
  'est', 'sont', 'quel', 'quelle', 'quels', 'quelles', 'que', 'qui', 'quoi',
  'pourquoi', 'comment', 'combien', 'où', 'dans', 'pour', 'sur', 'avec',
  'selon', 'entre', 'et', 'ou', 'il', 'elle', 'ils', 'peut', 'faut',
  'qu', 'd', 'l', 'c', 'n', 's', 'ce', 'cette', 'ces', 'son', 'sa', 'ses',
  'leur', 'leurs', 'par', 'en', 'pas', 'plus',
};
const _english = {
  'the', 'a', 'an', 'of', 'is', 'are', 'was', 'were', 'what', 'which', //
  'who', 'whom', 'why', 'how', 'when', 'where', 'does', 'do', 'did', 'in',
  'to', 'for', 'with', 'and', 'or', 'it', 'its', 'this', 'that', 'these',
  'can', 'must', 'should', 'would', 'from', 'by', 'about', 'many', 'much',
  'some', 'list', 'explain', 'give', 'between', 'be', 'has', 'have',
};

/// Guesses whether [question] is French or English.
///
/// Counts French and English function words, plus one point for French per
/// word with a French accent. English wins ties: it's the default for a
/// question with no clue (e.g. only technical terms).
AnswerLanguage detectQuestionLanguage(String question) {
  var french = 0;
  var english = 0;
  for (final match in _word.allMatches(question.toLowerCase())) {
    final word = match[0]!;
    if (_french.contains(word)) french++;
    if (_english.contains(word)) english++;
    if (_frenchLetter.hasMatch(word)) french++;
  }
  return french > english ? AnswerLanguage.french : AnswerLanguage.english;
}
