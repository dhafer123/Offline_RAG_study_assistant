import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/sqlite_vector_index.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_embedder.dart';

/// Returns fixed hits in a fixed order, whatever the query, so fusion tests
/// don't depend on the fake embedder's hash buckets.
class _FixedVectorIndex implements VectorIndex {
  _FixedVectorIndex(this.hits);

  final List<VectorHit> hits;
  final ks = <int>[];

  @override
  int get dimension => 64;

  @override
  Future<List<VectorHit>> search(List<double> query, {int k = 20}) async {
    ks.add(k);
    return hits.take(k).toList();
  }

  @override
  Future<void> add(List<ChunkVector> vectors) async {}

  @override
  Future<void> deleteByDoc(int docId) async {}

  @override
  Future<int> count() async => hits.length;
}

void main() {
  late AppDatabase db;
  late SqliteVectorIndex index;
  late FakeEmbedder embedder;
  late RetrievalService retrieval;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    embedder = FakeEmbedder();
    index = SqliteVectorIndex(db, dimension: embedder.dimension);
    retrieval = RetrievalService(embedder: embedder, index: index, store: db);
  });

  tearDown(() => db.close());

  Future<void> addDoc(String title, List<String> pages) async {
    final docId = await db.insertDocument(title: title, path: '/$title');
    final chunks = [
      for (var i = 0; i < pages.length; i++)
        NewChunk(page: i + 1, ordinal: i, text: pages[i]),
    ];
    final ids = await db.insertChunks(docId, chunks);
    await index.add([
      for (var i = 0; i < ids.length; i++)
        ChunkVector(chunkId: ids[i], vector: embedder.vectorFor(pages[i])),
    ]);
  }

  test('returns the best chunks with their document and page', () async {
    await addDoc('graphs.pdf', [
      'A graph has vertices and edges.',
      'Dijkstra finds the shortest path between two vertices.',
    ]);
    await addDoc('sorting.pdf', ['Quicksort picks a pivot.']);

    final results = await retrieval.retrieve(
      'shortest path between vertices',
      k: 2,
    );

    expect(results, hasLength(2));
    expect(results.first.documentTitle, 'graphs.pdf');
    expect(results.first.page, 2);
    expect(results.first.chunk.text, startsWith('Dijkstra'));
    expect(results.first.similarity, isNotNull);
    expect(results.first.score, greaterThan(results.last.score));
  });

  group('hybrid', () {
    late List<int> ids;

    // Chunk 0 is the vector favorite; chunk 2 holds the exact rare term.
    setUp(() async {
      final docId = await db.insertDocument(title: 'c.pdf', path: '/c.pdf');
      ids = await db.insertChunks(docId, [
        const NewChunk(page: 1, ordinal: 0, text: 'Recommender systems.'),
        const NewChunk(page: 2, ordinal: 1, text: 'Cold start for new users.'),
        const NewChunk(page: 3, ordinal: 2, text: 'Burke proposed hybrids.'),
      ]);
    });

    RetrievalService withVectorHits(List<(int, double)> hits, {int? cand}) =>
        RetrievalService(
          embedder: embedder,
          index: _FixedVectorIndex([
            for (final (i, s) in hits)
              VectorHit(chunkId: ids[i], similarity: s),
          ]),
          store: db,
          candidates: cand ?? 20,
        );

    test('adds keyword-only matches, with no similarity', () async {
      final service = withVectorHits([(0, 0.6), (1, 0.5)]);

      final results = await service.retrieve(
        'Who is Burke?',
        mode: RetrievalMode.hybrid,
      );

      expect([for (final r in results) r.page], [1, 3, 2]);
      final burke = results[1];
      expect(burke.similarity, isNull);
      expect(burke.score, closeTo(1 / 61, 1e-12));
      expect(results.first.similarity, 0.6);
    });

    test('ranks a chunk found by both searches first', () async {
      final service = withVectorHits([(0, 0.6), (1, 0.5)]);

      final results = await service.retrieve(
        'cold start users',
        mode: RetrievalMode.hybrid,
      );

      expect(results.first.page, 2);
      expect(results.first.score, closeTo(1 / 62 + 1 / 61, 1e-12));
      expect(results.first.similarity, 0.5);
    });

    test('takes candidates from each search, then keeps k', () async {
      final index = _FixedVectorIndex([
        VectorHit(chunkId: ids[0], similarity: 0.6),
        VectorHit(chunkId: ids[1], similarity: 0.5),
      ]);
      final service = RetrievalService(
        embedder: embedder,
        index: index,
        store: db,
        candidates: 7,
      );

      final results = await service.retrieve(
        'Burke',
        k: 1,
        mode: RetrievalMode.hybrid,
      );

      expect(index.ks, [7]);
      expect(results, hasLength(1));
    });

    test('defaults to vector mode, which ignores keyword matches', () async {
      final service = withVectorHits([(0, 0.6), (1, 0.5)]);

      final results = await service.retrieve('Who is Burke?');

      expect(defaultRetrievalMode, RetrievalMode.vector);
      expect([for (final r in results) r.page], [1, 2]);
      expect([for (final r in results) r.score], [0.6, 0.5]);
    });

    test('keyword mode skips the embedder', () async {
      final service = withVectorHits([(0, 0.6)]);

      final results = await service.retrieve(
        'Who is Burke?',
        mode: RetrievalMode.keyword,
      );

      expect([for (final r in results) r.page], [3]);
      expect(results.single.similarity, isNull);
      expect(results.single.score, greaterThan(0));
      expect(embedder.loadCalls, 0);
      expect(embedder.queries, isEmpty);
    });

    test('still works when no word of the question is indexed', () async {
      final service = withVectorHits([(1, 0.4)]);

      final results = await service.retrieve(
        'xyzzy?',
        mode: RetrievalMode.hybrid,
      );

      expect([for (final r in results) r.page], [2]);
    });
  });

  test('embeds the question as a query, loading the model first', () async {
    await addDoc('a.pdf', ['text']);

    await retrieval.retrieve('What is a graph?');

    expect(embedder.loadCalls, 1);
    expect(embedder.queries, ['What is a graph?']);
  });

  test('returns nothing for a blank question or an empty library', () async {
    expect(await retrieval.retrieve('   '), isEmpty);
    expect(embedder.queries, isEmpty);
    expect(await retrieval.retrieve('anything'), isEmpty);
  });
}
