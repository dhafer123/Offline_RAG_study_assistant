final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Turns free text into an FTS5 MATCH expression that can't be a syntax error.
///
/// Each word becomes a quoted term and the terms are OR-ed, so BM25 ranks
/// chunks by how many (and how rare) of the words they contain. Splitting on
/// letters and digits mirrors the `unicode61` tokenizer, so "l'algorithme"
/// searches "l" OR "algorithme". Returns null when there is no word.
String? buildFtsQuery(String text, {int maxTerms = 32}) {
  final terms = <String>{
    for (final match in _word.allMatches(text)) match[0]!.toLowerCase(),
  };
  if (terms.isEmpty) return null;
  return terms.take(maxTerms).map((t) => '"$t"').join(' OR ');
}
