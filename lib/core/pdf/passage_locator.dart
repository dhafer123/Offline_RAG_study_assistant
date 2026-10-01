import 'dart:ui';

/// Where a passage lies in a page's text: `[start, end)` in UTF-16 code
/// units of that text.
typedef TextRange = ({int start, int end});

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

// Letters the text cleaner may have changed: accents (rebuilt from LaTeX
// spacing accents) and ligatures (expanded). Both sides are folded the same
// way, so "g´en´eral" on the page matches "général" in the chunk.
const _fold = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  'ﬀ': 'ff', 'ﬁ': 'fi', 'ﬂ': 'fl', 'ﬃ': 'ffi', 'ﬄ': 'ffl', 'ﬅ': 'st',
  'ﬆ': 'st',
};

/// [text] reduced to lower-case letters and digits without accents, with
/// the index in [text] each kept character came from.
({String text, List<int> source}) _normalize(String text) {
  final out = StringBuffer();
  final source = <int>[];
  for (var i = 0; i < text.length; i++) {
    final c = text[i].toLowerCase();
    final folded = _fold[c] ?? c;
    for (var j = 0; j < folded.length; j++) {
      if (_letterOrDigit.hasMatch(folded[j])) {
        out.write(folded[j]);
        source.add(i);
      }
    }
  }
  return (text: out.toString(), source: source);
}

/// Finds [passage] (a chunk of cleaned text) in [pageText] (the page's raw
/// text, as the PDF viewer has it).
///
/// The cleaner rejoins hyphenated words, rebuilds accents, expands ligatures
/// and drops headers, so the two never match character for character. Only
/// letters and digits are compared, and the passage is anchored by its first
/// and last [anchorLength] of them. Returns null when either end can't be
/// found.
TextRange? locatePassage(
  String pageText,
  String passage, {
  int anchorLength = 24,
}) {
  final page = _normalize(pageText);
  final target = _normalize(passage).text;
  if (target.isEmpty || page.text.isEmpty) return null;

  final n = target.length < anchorLength ? target.length : anchorLength;
  final start = page.text.indexOf(target.substring(0, n));
  if (start < 0) return null;
  // The cleaner only removes text, so on the page the passage is at least
  // as long as it is in the chunk: its end anchor can't start earlier.
  final end = page.text.indexOf(
    target.substring(target.length - n),
    start + target.length - n,
  );
  if (end < 0) return null;

  return (start: page.source[start], end: page.source[end + n - 1] + 1);
}

/// Merges per-character boxes into one box per line, in reading order.
///
/// Empty boxes (spaces often have no width) are skipped. A box joins the
/// current line when it overlaps it vertically by at least half the smaller
/// height and doesn't jump back to the left.
List<Rect> mergeLineRects(Iterable<Rect> chars) {
  final lines = <Rect>[];
  for (final r in chars) {
    if (r.isEmpty) continue;
    if (lines.isNotEmpty) {
      final line = lines.last;
      final overlap =
          (r.bottom < line.bottom ? r.bottom : line.bottom) -
          (r.top > line.top ? r.top : line.top);
      final minHeight = r.height < line.height ? r.height : line.height;
      final sameLine = overlap >= minHeight / 2 && r.left >= line.left - 1;
      if (sameLine) {
        lines.last = line.expandToInclude(r);
        continue;
      }
    }
    lines.add(r);
  }
  return lines;
}
