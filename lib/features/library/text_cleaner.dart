/// Cleans text extracted from PDF pages before chunking.
///
/// Pure functions, no I/O: [cleanPages] runs every rule in order, and each
/// rule is public so it can be tested on its own. Pages stay aligned: the
/// output has one entry per input page, so citations keep the right page.
library;

/// Runs all cleaning rules on the pages of one document.
///
/// Order matters: accents are fixed first (a stray accent can sit between a
/// hyphen and its line break), then headers, footers and page numbers are
/// dropped while lines still match the PDF layout, then hyphenated line
/// breaks are rejoined and whitespace is normalized.
List<String> cleanPages(List<String> pages) {
  final lines = [
    for (final page in pages) fixSpacingAccents(page).split('\n'),
  ];
  final withoutEdges = removeRepeatedEdgeLines(lines);
  return [
    for (final page in withoutEdges)
      normalizeWhitespace(
        joinHyphenatedLines(
          collapseDotLeaders(removePageNumberLines(page).join('\n')),
        ),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Spacing accents (LaTeX PDFs)

const _acute = '\u00B4'; // ´
const _grave = '`';
const _circumflex = '\u02C6'; // ˆ
const _diaeresis = '\u00A8'; // ¨
const _cedilla = '\u00B8'; // ¸
const _tilde = '\u02DC'; // ˜

const Map<String, Map<String, String>> _composed = {
  _acute: {
    'a': 'á', 'e': 'é', 'i': 'í', 'ı': 'í', 'o': 'ó', 'u': 'ú', 'y': 'ý', //
    'A': 'Á', 'E': 'É', 'I': 'Í', 'O': 'Ó', 'U': 'Ú',
  },
  _grave: {
    'a': 'à', 'e': 'è', 'i': 'ì', 'ı': 'ì', 'o': 'ò', 'u': 'ù', //
    'A': 'À', 'E': 'È', 'U': 'Ù',
  },
  _circumflex: {
    'a': 'â', 'e': 'ê', 'i': 'î', 'ı': 'î', 'o': 'ô', 'u': 'û', //
    'A': 'Â', 'E': 'Ê', 'I': 'Î', 'O': 'Ô', 'U': 'Û',
  },
  _diaeresis: {
    'a': 'ä', 'e': 'ë', 'i': 'ï', 'ı': 'ï', 'o': 'ö', 'u': 'ü', 'y': 'ÿ', //
    'A': 'Ä', 'E': 'Ë', 'I': 'Ï', 'O': 'Ö', 'U': 'Ü',
  },
  _cedilla: {'c': 'ç', 'C': 'Ç'},
  _tilde: {'a': 'ã', 'n': 'ñ', 'o': 'õ', 'N': 'Ñ'},
};

/// Where an accent left at the end of a line goes (see [fixSpacingAccents]).
/// French capitals rarely carry accents, mostly É and À:
/// - acute: a word-initial E followed by one consonant and a vowel ("Etat",
///   "Ecole", "Equipe"), not "Elle", "Et", "En" or "Exemple";
/// - grave: the word "A" on its own ("A partir de" → "À partir de").
final Map<String, RegExp> _orphanTargets = {
  _acute: RegExp(
    r'(?<![\p{L}\p{N}])E(?=[bcdfghjlmnpqrstvz][aeiouyéèê])',
    unicode: true,
  ),
  _grave: RegExp(r'(?<![\p{L}\p{N}])A(?![\p{L}\p{N}])', unicode: true),
};

final _accentBefore = RegExp(
  '([$_acute$_grave$_circumflex$_diaeresis$_cedilla$_tilde])(\\p{L})',
  unicode: true,
);
final _cedillaAfter = RegExp('([cC])$_cedilla');
final _orphanAccent = RegExp('\\s([$_acute$_grave$_circumflex])\$');

/// Rebuilds accented letters that the PDF stores as a separate accent glyph.
///
/// pdfTeX documents without T1 fonts extract "g´en´eral", "`a", "maˆıtrise"
/// and "le¸cons"; this turns them back into "général", "à", "maîtrise" and
/// "leçons". For capitals, the accent often lands at the end of the line
/// ("A partir de ... `"): it moves to the likeliest capital on that line, or
/// is dropped when there is none.
String fixSpacingAccents(String text) {
  final lines = text.split('\n').map((line) {
    var fixed = line
        .replaceAllMapped(_accentBefore, (m) {
          final letter = _composed[m[1]]![m[2]];
          return letter ?? m[0]!;
        })
        .replaceAllMapped(_cedillaAfter, (m) => _composed[_cedilla]![m[1]]!);
    final orphan = _orphanAccent.firstMatch(fixed);
    if (orphan != null) {
      final accent = orphan[1]!;
      fixed = fixed.substring(0, orphan.start);
      final target = _orphanTargets[accent]?.firstMatch(fixed);
      if (target != null) {
        fixed = fixed.replaceRange(
          target.start,
          target.end,
          _composed[accent]![target[0]]!,
        );
      }
    }
    return fixed;
  });
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Headers, footers and page numbers

final _digits = RegExp(r'\d+');
final _spaces = RegExp(r'\s+');

String _edgeKey(String line) =>
    line.trim().replaceAll(_digits, '#').replaceAll(_spaces, ' ').toLowerCase();

/// Drops lines that repeat at the top or bottom of many pages: running
/// headers and footers ("Chapter 3 — Graphs", "Course notes · page 12").
///
/// Only the first and last [edgeLines] non-empty lines of each page are
/// considered, and digits are ignored so "Page 3" and "Page 4" match. A line
/// counts as repeated when it sits on the edge of at least [minRatio] of the
/// pages and at least [minPages] pages, so real headings that recur now and
/// then ("Chapitre 2") stay. Documents shorter than [minPages] are returned
/// unchanged.
List<List<String>> removeRepeatedEdgeLines(
  List<List<String>> pages, {
  int edgeLines = 2,
  double minRatio = 0.5,
  int minPages = 3,
}) {
  if (pages.length < minPages) return pages;

  List<int> edgeIndexes(List<String> page) {
    final nonEmpty = [
      for (var i = 0; i < page.length; i++)
        if (page[i].trim().isNotEmpty) i,
    ];
    return {
      ...nonEmpty.take(edgeLines),
      ...nonEmpty.skip(nonEmpty.length - edgeLines),
    }.toList();
  }

  final counts = <String, int>{};
  for (final page in pages) {
    for (final key in {for (final i in edgeIndexes(page)) _edgeKey(page[i])}) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final threshold = (pages.length * minRatio).ceil();
  final repeated = {
    for (final MapEntry(:key, :value) in counts.entries)
      if (value >= threshold && value >= minPages) key,
  };
  if (repeated.isEmpty) return pages;

  return [
    for (final page in pages)
      () {
        final drop = {
          for (final i in edgeIndexes(page))
            if (repeated.contains(_edgeKey(page[i]))) i,
        };
        return [
          for (var i = 0; i < page.length; i++)
            if (!drop.contains(i)) page[i],
        ];
      }(),
  ];
}

final _pageNumber = RegExp(
  '^(?:'
  r'[-–—]?\s*\d{1,4}\s*[-–—]?' // 12, - 12 -
  r'|(?:page|p\.)\s*\d{1,4}(?:\s*(?:/|of|sur|de)\s*\d{1,4})?' // Page 3 of 10
  r'|\d{1,4}\s*(?:/|of|sur|de)\s*\d{1,4}' // 3 / 10
  // Roman numerals up to 89 (front matter): iv, xii. The lookahead keeps
  // the empty string out.
  '|(?=[ivxlc])(?:xc|xl|l?x{0,3})(?:ix|iv|v?i{0,3})'
  r')$',
  caseSensitive: false,
);

/// Whether [line] is only a page number ("12", "- 12 -", "Page 3 of 10",
/// "3/10", "iv").
bool isPageNumberLine(String line) => _pageNumber.hasMatch(line.trim());

/// Drops a page number from the first and the last non-empty line of a page.
/// Numbers inside the page (list items, table cells) are kept.
List<String> removePageNumberLines(List<String> page) {
  final nonEmpty = [
    for (var i = 0; i < page.length; i++)
      if (page[i].trim().isNotEmpty) i,
  ];
  if (nonEmpty.isEmpty) return page;
  final drop = {
    if (isPageNumberLine(page[nonEmpty.first])) nonEmpty.first,
    if (isPageNumberLine(page[nonEmpty.last])) nonEmpty.last,
  };
  // A page holding only a number has no text worth keeping either way.
  return [
    for (var i = 0; i < page.length; i++)
      if (!drop.contains(i)) page[i],
  ];
}

// ---------------------------------------------------------------------------
// Line breaks and whitespace

final _dotLeader = RegExp(r'(?:[ \t]*\.){4,}[ \t]*');

/// Shrinks table-of-contents dot leaders ("Contexte . . . . . . 8") to one
/// space, so they don't fill chunks with dots.
String collapseDotLeaders(String text) => text.replaceAll(_dotLeader, ' ');

final _hyphenBreak = RegExp(
  r'(\p{L})-[ \t]*\n[ \t]*(\p{Ll})',
  unicode: true,
);

/// Marker pdfium puts where it already rejoined a word hyphenated at a line
/// break: "pédago" U+0002 "gique".
const _pdfiumHyphen = '\u0002';

/// Rejoins words split across lines with a hyphen ("algo-\nrithm" becomes
/// "algorithm").
///
/// pdfium already rejoins most of them but leaves a U+0002 marker inside the
/// word, which would split it in two for search; the marker is removed.
/// Hyphens still followed by a line break are joined only when the next line
/// starts with a lowercase letter, so "Jean-\nPaul" and lists ("-\n- item")
/// are left alone. A real compound broken exactly at its hyphen
/// ("non-\njoueur") loses the hyphen; that's rare and harmless for search.
String joinHyphenatedLines(String text) => text
    .replaceAll(_pdfiumHyphen, '')
    .replaceAllMapped(_hyphenBreak, (m) => '${m[1]}${m[2]}');

final _invisible = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F'
  '\u00AD\u200B-\u200D\u2060\uFEFF]',
);
final _oddSpace = RegExp('[\t\u00A0\u2000-\u200A\u202F\u205F\u3000]');
final _multiSpace = RegExp(' {2,}');
final _manyNewlines = RegExp(r'\n{3,}');

const _ligatures = {
  '\uFB00': 'ff',
  '\uFB01': 'fi',
  '\uFB02': 'fl',
  '\uFB03': 'ffi',
  '\uFB04': 'ffl',
  '\uFB05': 'st',
  '\uFB06': 'st',
};
final _ligature = RegExp('[\uFB00-\uFB06]');

/// Normalizes whitespace and invisible characters:
/// - drops control characters, soft hyphens and zero-width characters,
/// - expands ligatures ("\uFB01" → "fi") so words match when searched,
/// - turns tabs and non-breaking or other special spaces into plain spaces,
/// - collapses runs of spaces and trims each line,
/// - keeps at most one blank line between paragraphs and trims the page.
String normalizeWhitespace(String text) {
  final cleaned = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(_invisible, '')
      .replaceAllMapped(_ligature, (m) => _ligatures[m[0]]!)
      .replaceAll(_oddSpace, ' ')
      .replaceAll(_multiSpace, ' ');
  return cleaned
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .replaceAll(_manyNewlines, '\n\n')
      .trim();
}
