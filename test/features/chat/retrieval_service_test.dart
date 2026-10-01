import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/sqlite_vector_index.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_embedder.dart';

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
    expect(
      results.first.similarity,
      greaterThanOrEqualTo(results.last.similarity),
    );
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
