import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

/// A source cited by the answer: what a citation chip shows and opens.
@immutable
class Citation {
  const Citation({required this.number, required this.source});

  /// The `[n]` the model wrote, 1-based.
  final int number;
  final RetrievedChunk source;

  String get documentTitle => source.documentTitle;
  int get page => source.page;

  @override
  bool operator ==(Object other) =>
      other is Citation &&
      other.number == number &&
      other.source.chunk.id == source.chunk.id;

  @override
  int get hashCode => Object.hash(number, source.chunk.id);

  @override
  String toString() => 'Citation([$number] $documentTitle p.$page)';
}

/// A piece of a parsed answer, in reading order.
@immutable
sealed class AnswerSegment {
  const AnswerSegment();
}

/// Plain answer text.
final class TextSegment extends AnswerSegment {
  const TextSegment(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is TextSegment && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextSegment(${text.replaceAll('\n', r'\n')})';
}

/// One marker such as `[1, 3]`, with its valid citations in order.
final class CitationSegment extends AnswerSegment {
  const CitationSegment(this.citations);

  final List<Citation> citations;

  @override
  bool operator ==(Object other) =>
      other is CitationSegment && listEquals(other.citations, citations);

  @override
  int get hashCode => Object.hashAll(citations);

  @override
  String toString() => 'CitationSegment($citations)';
}

@immutable
class ParsedAnswer {
  const ParsedAnswer({required this.segments, required this.citations});

  final List<AnswerSegment> segments;

  /// Every source cited at least once, in order of first citation.
  final List<Citation> citations;

  /// The answer without its markers (e.g. for copying).
  String get plainText => [
    for (final s in segments)
      if (s is TextSegment) s.text,
  ].join();
}

// A bracket holding numbers separated by commas, semicolons, "and"/"et" or
// ranges, optionally after "source(s)": [1], [1, 2], [1-3], [Source 2].
final _marker = RegExp(
  r'\[\s*(?:sources?\s*)?(\d+(?:\s*(?:[,;–-]|and|et)\s*\d+)*)\s*\]',
  caseSensitive: false,
);
final _numberOrRange = RegExp(r'(\d+)(?:\s*[–-]\s*(\d+))?');

// The start of a marker still being streamed, at the very end of the text.
final _partialMarker = RegExp(
  r'\s*\[\s*(?:s(?:o(?:u(?:r(?:c(?:es?)?)?)?)?)?\s*)?[\d\s,;–-]*$',
  caseSensitive: false,
);

/// Splits [answer] into text and citations of [sources], where `[n]` is
/// `sources[n - 1]` (the order `buildAnswerPrompt` numbered them in).
///
/// Understands `[1]`, `[1][3]`, `[1, 2]`, `[1-3]` and `[Source 2]`. Numbers
/// that match no source are dropped; a marker left with none is removed
/// along with the space before it. Adjacent markers become one
/// [CitationSegment], without repeating a source.
///
/// While the answer is still streaming, pass [streaming] so a marker that
/// isn't closed yet (`... engine [1`) is hidden instead of shown as text.
ParsedAnswer parseCitations(
  String answer,
  List<RetrievedChunk> sources, {
  bool streaming = false,
}) {
  var text = answer;
  if (streaming) text = text.replaceFirst(_partialMarker, '');

  final segments = <AnswerSegment>[];
  final cited = <int, Citation>{};
  final pending = <Citation>[];
  var buffer = StringBuffer();
  var last = 0;

  void flushCitations() {
    if (pending.isEmpty) return;
    segments.add(CitationSegment(List.unmodifiable(pending)));
    pending.clear();
  }

  void flushText() {
    if (buffer.isEmpty) return;
    flushCitations();
    segments.add(TextSegment(buffer.toString()));
    buffer = StringBuffer();
  }

  // Space removed with an invalid marker, given back if a valid marker
  // follows right after it ("A [0][2]" reads "A [2]").
  var droppedSpace = '';
  for (final match in _marker.allMatches(text)) {
    var between = text.substring(last, match.start);
    last = match.end;
    final numbers = _numbers(match[1]!, sources.length);
    if (numbers.isEmpty) {
      // Invalid marker: drop it and the space that led to it.
      final kept = between.trimRight();
      buffer.write(kept);
      droppedSpace = kept.isEmpty
          ? droppedSpace + between
          : between.substring(kept.length);
      continue;
    }
    if (between.isEmpty) between = droppedSpace;
    droppedSpace = '';
    // "[1] [3]": only space since the last marker, so they form one segment.
    final adjacent =
        pending.isNotEmpty && buffer.isEmpty && between.trim().isEmpty;
    if (!adjacent) {
      buffer.write(between);
      flushText();
    }
    for (final n in numbers) {
      final citation = cited.putIfAbsent(
        n,
        () => Citation(number: n, source: sources[n - 1]),
      );
      if (!pending.contains(citation)) pending.add(citation);
    }
  }
  buffer.write(text.substring(last));
  flushText();
  flushCitations();

  return ParsedAnswer(
    segments: List.unmodifiable(segments),
    citations: List.unmodifiable(cited.values),
  );
}

/// The valid source numbers (1..[count]) in [body], in the order written,
/// without repeats. A range like `1-3` is expanded unless it's reversed or
/// wider than [count]; then only its ends are kept.
List<int> _numbers(String body, int count) {
  final numbers = <int>[];
  void add(int n) {
    if (n >= 1 && n <= count && !numbers.contains(n)) numbers.add(n);
  }

  for (final m in _numberOrRange.allMatches(body)) {
    final from = int.parse(m[1]!);
    final to = m[2] == null ? null : int.parse(m[2]!);
    if (to == null) {
      add(from);
    } else if (from <= to && to - from < count) {
      for (var n = from; n <= to; n++) {
        add(n);
      }
    } else {
      add(from);
      add(to);
    }
  }
  return numbers;
}
