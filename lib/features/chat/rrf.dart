import 'package:flutter/foundation.dart';

/// The RRF constant from Cormack et al. (2009). It damps the weight of the
/// top ranks so one list can't dominate the fusion.
const defaultRrfK = 60;

/// An item of the fused ranking.
@immutable
class FusedItem<T> {
  const FusedItem({
    required this.item,
    required this.score,
    required this.ranks,
  });

  final T item;

  /// Sum of `1 / (k + rank)` over the lists that contain [item].
  final double score;

  /// 1-based rank of [item] in each input list, null where it's absent.
  final List<int?> ranks;

  @override
  String toString() => 'FusedItem($item, $score, $ranks)';
}

/// Merges ranked lists with Reciprocal Rank Fusion.
///
/// Each item scores `1 / (k + rank)` per list it appears in (rank is
/// 1-based), and items are returned best score first. Only ranks are used,
/// so lists with incomparable scores (cosine similarity, BM25) can be fused.
/// Ties go to the item with the better best rank, then to the item that
/// appears first in the earlier list, so the result is deterministic.
/// Duplicates within a list count at their first position only. Returns at
/// most [limit] items when given.
List<FusedItem<T>> reciprocalRankFusion<T>(
  List<List<T>> rankings, {
  int k = defaultRrfK,
  int? limit,
}) {
  if (k < 0) throw ArgumentError.value(k, 'k', 'must be >= 0');
  if (limit != null && limit < 0) {
    throw ArgumentError.value(limit, 'limit', 'must be >= 0');
  }

  // Insertion order of the map = first appearance, used as the last tie-break.
  final ranks = <T, List<int?>>{};
  for (var list = 0; list < rankings.length; list++) {
    final ranking = rankings[list];
    for (var i = 0; i < ranking.length; i++) {
      final itemRanks = ranks.putIfAbsent(
        ranking[i],
        () => List<int?>.filled(rankings.length, null),
      );
      itemRanks[list] ??= i + 1;
    }
  }

  final fused = [
    for (final MapEntry(key: item, value: itemRanks) in ranks.entries)
      FusedItem(
        item: item,
        score: itemRanks.fold(
          0,
          (sum, rank) => rank == null ? sum : sum + 1 / (k + rank),
        ),
        ranks: List.unmodifiable(itemRanks),
      ),
  ];
  final order = {for (final (i, f) in fused.indexed) f.item: i};
  int bestRank(FusedItem<T> f) =>
      f.ranks.fold(1 << 30, (best, r) => r != null && r < best ? r : best);
  fused.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byRank = bestRank(a).compareTo(bestRank(b));
    if (byRank != 0) return byRank;
    return order[a.item]!.compareTo(order[b.item]!);
  });
  return limit == null || fused.length <= limit
      ? fused
      : fused.sublist(0, limit);
}
