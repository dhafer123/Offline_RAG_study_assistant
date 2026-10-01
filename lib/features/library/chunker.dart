import 'package:offline_study_assistant/core/db/document_store.dart';

final _word = RegExp(r'\S+');

/// Splits cleaned pages into overlapping chunks of about [chunkWords] words.
///
/// [pages] holds one text per page, in order (index 0 is page 1). A chunk
/// never spans two pages, so every chunk cites exactly one page. Ordinals
/// count chunks across the whole document, from 0, with no gaps.
///
/// Per page:
/// - an empty page gives no chunk;
/// - a page of up to [chunkWords] words gives one chunk;
/// - a longer page gives windows of equal size, at most [chunkWords] words,
///   each sharing [overlapWords] words with the previous one. Sizes are
///   balanced so the last window isn't a short leftover (a 260-word page
///   gives two chunks of ~155 words, not 250 + 60).
///
/// A chunk's text is the page text from its first word to its last, so line
/// breaks inside it are kept.
List<NewChunk> chunkPages(
  List<String> pages, {
  int chunkWords = 250,
  int overlapWords = 50,
}) {
  if (chunkWords <= 0) {
    throw ArgumentError.value(chunkWords, 'chunkWords', 'must be positive');
  }
  if (overlapWords < 0 || overlapWords >= chunkWords) {
    throw ArgumentError.value(
      overlapWords,
      'overlapWords',
      'must be at least 0 and less than chunkWords ($chunkWords)',
    );
  }

  final chunks = <NewChunk>[];
  for (var index = 0; index < pages.length; index++) {
    final text = pages[index];
    final words = _word.allMatches(text).toList();
    for (final (start, end) in _windows(
      words.length,
      chunkWords,
      overlapWords,
    )) {
      chunks.add(
        NewChunk(
          page: index + 1,
          ordinal: chunks.length,
          text: text.substring(words[start].start, words[end - 1].end),
        ),
      );
    }
  }
  return chunks;
}

/// Word ranges `[start, end)` covering [count] words, as described in
/// [chunkPages].
List<(int, int)> _windows(int count, int maxSize, int overlap) {
  if (count == 0) return const [];
  if (count <= maxSize) return [(0, count)];

  final stride = maxSize - overlap;
  // Fewest windows that cover every word: n * stride + overlap >= count.
  final n = ((count - overlap) / stride).ceil();
  // Same size for all; never above maxSize given the choice of n.
  final size = ((count + (n - 1) * overlap) / n).ceil();
  final step = size - overlap;
  return [
    for (var i = 0; i < n; i++)
      (i * step, i == n - 1 ? count : i * step + size),
  ];
}
