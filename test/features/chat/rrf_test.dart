import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/features/chat/rrf.dart';

List<T> items<T>(List<FusedItem<T>> fused) => [for (final f in fused) f.item];

void main() {
  test('scores each item 1 / (k + rank) summed over the lists', () {
    final fused = reciprocalRankFusion([
      ['a', 'b'],
      ['b', 'c'],
    ]);

    final byItem = {for (final f in fused) f.item: f};
    expect(byItem['a']!.score, closeTo(1 / 61, 1e-12));
    expect(byItem['b']!.score, closeTo(1 / 62 + 1 / 61, 1e-12));
    expect(byItem['c']!.score, closeTo(1 / 62, 1e-12));
    expect(byItem['b']!.ranks, [2, 1]);
    expect(byItem['c']!.ranks, [null, 2]);
  });

  test('ranks an item found by both lists above single-list tops', () {
    final fused = reciprocalRankFusion([
      ['v1', 'v2', 'both'],
      ['k1', 'k2', 'both'],
    ]);

    // 2/63 > 1/61: agreement beats one list's first place.
    expect(fused.first.item, 'both');
    expect(items(fused), ['both', 'v1', 'k1', 'v2', 'k2']);
  });

  test('uses only ranks, not the scores behind them', () {
    // Same order as above, so the same result whatever the raw scores were.
    expect(
      items(
        reciprocalRankFusion([
          [3, 1, 2],
          [2],
        ]),
      ),
      [2, 3, 1],
    );
  });

  test('a smaller k gives the top ranks more weight', () {
    final rankings = [
      ['x', 'y', 'z'],
      ['z', 'q', 'y'],
    ];

    expect(reciprocalRankFusion(rankings).first.item, 'z');
    // k = 0: x = 1/1, z = 1/3 + 1/1, y = 1/2 + 1/3.
    expect(items(reciprocalRankFusion(rankings, k: 0)), [
      'z',
      'x',
      'y',
      'q',
    ]);
  });

  test('breaks ties by best rank, then by first appearance', () {
    // a and b both score 1/61, both at rank 1: a's list comes first.
    // c (1/62 + 1/63) is in both lists, so it leads.
    final fused = reciprocalRankFusion([
      ['a', 'c'],
      ['b', 'd', 'c'],
    ]);

    expect(items(fused), ['c', 'a', 'b', 'd']);
    // Equal scores and equal best rank: the earlier list wins.
    expect(
      items(
        reciprocalRankFusion([
          ['x'],
          ['y'],
        ]),
      ),
      ['x', 'y'],
    );
    expect(
      items(
        reciprocalRankFusion([
          ['y'],
          ['x'],
        ]),
      ),
      ['y', 'x'],
    );
  });

  test('cuts to limit after fusing', () {
    final fused = reciprocalRankFusion([
      ['a', 'b', 'c', 'd'],
      ['d', 'c'],
    ], limit: 2);

    expect(items(fused), ['d', 'c']);
    expect(
      reciprocalRankFusion([
        ['a'],
      ], limit: 5),
      hasLength(1),
    );
    expect(
      reciprocalRankFusion([
        ['a'],
      ], limit: 0),
      isEmpty,
    );
  });

  test('counts a duplicate within one list at its first position only', () {
    final fused = reciprocalRankFusion([
      ['a', 'b', 'a'],
    ]);

    expect(items(fused), ['a', 'b']);
    expect(fused.first.score, closeTo(1 / 61, 1e-12));
    expect(fused.first.ranks, [1]);
  });

  test('handles empty input and a single list', () {
    expect(reciprocalRankFusion<int>([]), isEmpty);
    expect(reciprocalRankFusion<int>([[], []]), isEmpty);
    expect(
      items(
        reciprocalRankFusion([
          <int>[],
          [5, 4],
        ]),
      ),
      [5, 4],
    );
  });

  test('rejects a negative k or limit', () {
    expect(
      () => reciprocalRankFusion([
        ['a'],
      ], k: -1),
      throwsArgumentError,
    );
    expect(
      () => reciprocalRankFusion([
        ['a'],
      ], limit: -1),
      throwsArgumentError,
    );
  });
}
