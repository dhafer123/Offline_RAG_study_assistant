import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 1, 9, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(), clock: () => now);
  });

  tearDown(() => db.close());

  Future<int> addDoc([String title = 'Algorithms']) =>
      db.insertDocument(title: title, path: '/docs/$title.pdf');

  group('documents', () {
    test('insert then get returns the stored fields', () async {
      final id = await db.insertDocument(
        title: 'Algorithms',
        path: '/docs/algo.pdf',
        pageCount: 120,
      );

      final doc = await db.getDocument(id);

      expect(doc, isNotNull);
      expect(doc!.id, id);
      expect(doc.title, 'Algorithms');
      expect(doc.path, '/docs/algo.pdf');
      expect(doc.pageCount, 120);
      expect(doc.status, DocumentStatus.pending);
      expect(doc.indexedAt, isNull);
    });

    test('get returns null for an unknown id', () async {
      expect(await db.getDocument(42), isNull);
    });

    test('list returns newest first', () async {
      await addDoc('first');
      await addDoc('second');

      final titles = (await db.listDocuments()).map((d) => d.title);

      expect(titles, ['second', 'first']);
    });

    test('moving to ready sets indexedAt', () async {
      final id = await addDoc();

      await db.updateDocument(id, status: DocumentStatus.indexing);
      expect((await db.getDocument(id))!.indexedAt, isNull);

      await db.updateDocument(id, status: DocumentStatus.ready, pageCount: 7);
      final doc = (await db.getDocument(id))!;

      expect(doc.status, DocumentStatus.ready);
      expect(doc.pageCount, 7);
      expect(doc.indexedAt, now);
    });

    test('updating an unknown document throws', () async {
      expect(
        () => db.updateDocument(42, status: DocumentStatus.failed),
        throwsA(isA<DocumentNotFoundException>()),
      );
      expect(
        () => db.updateDocument(42),
        throwsA(isA<DocumentNotFoundException>()),
      );
    });

    test('deleting a document removes its chunks and their FTS rows', () async {
      final keep = await addDoc('keep');
      final drop = await addDoc('drop');
      await db.insertChunks(keep, const [
        NewChunk(page: 1, ordinal: 0, text: 'graph traversal with BFS'),
      ]);
      await db.insertChunks(drop, const [
        NewChunk(page: 1, ordinal: 0, text: 'graph coloring heuristics'),
      ]);

      await db.deleteDocument(drop);

      expect(await db.getDocument(drop), isNull);
      expect(await db.chunksForDocument(drop), isEmpty);
      final hits = await db.searchKeyword('graph');
      expect(hits, hasLength(1));
      expect(
        (await db.chunksByIds([hits.single.chunkId])).single.docId,
        keep,
      );
    });
  });

  group('chunks', () {
    test(
      'insert returns ids in order and chunks read back by ordinal',
      () async {
        final docId = await addDoc();

        final ids = await db.insertChunks(docId, const [
          NewChunk(page: 2, ordinal: 1, text: 'second'),
          NewChunk(page: 1, ordinal: 0, text: 'first'),
        ]);
        final chunks = await db.chunksForDocument(docId);

        expect(ids, hasLength(2));
        expect(chunks.map((c) => c.text), ['first', 'second']);
        expect(chunks.map((c) => c.id), [ids[1], ids[0]]);
        expect(chunks.first.page, 1);
        expect(chunks.first.docId, docId);
      },
    );

    test(
      'inserting for an unknown document throws and stores nothing',
      () async {
        await expectLater(
          db.insertChunks(42, const [NewChunk(page: 1, ordinal: 0, text: 'x')]),
          throwsA(isA<DocumentNotFoundException>()),
        );
        expect(await db.searchKeyword('x'), isEmpty);
      },
    );

    test('a failing batch is rolled back', () async {
      final docId = await addDoc();

      // Duplicate ordinal violates UNIQUE (doc_id, ordinal).
      await expectLater(
        db.insertChunks(docId, const [
          NewChunk(page: 1, ordinal: 0, text: 'kept?'),
          NewChunk(page: 1, ordinal: 0, text: 'duplicate'),
        ]),
        throwsA(anything),
      );

      expect(await db.chunksForDocument(docId), isEmpty);
    });

    test('byIds keeps the requested order and skips unknown ids', () async {
      final docId = await addDoc();
      final ids = await db.insertChunks(docId, const [
        NewChunk(page: 1, ordinal: 0, text: 'a'),
        NewChunk(page: 1, ordinal: 1, text: 'b'),
        NewChunk(page: 2, ordinal: 2, text: 'c'),
      ]);

      final chunks = await db.chunksByIds([ids[2], 999, ids[0]]);

      expect(chunks.map((c) => c.text), ['c', 'a']);
      expect(await db.chunksByIds(const []), isEmpty);
    });

    test('deleteChunks clears a document for re-indexing', () async {
      final docId = await addDoc();
      await db.insertChunks(docId, const [
        NewChunk(page: 1, ordinal: 0, text: 'old text about heaps'),
      ]);

      await db.deleteChunks(docId);
      await db.insertChunks(docId, const [
        NewChunk(page: 1, ordinal: 0, text: 'new text about tries'),
      ]);

      expect(await db.searchKeyword('heaps'), isEmpty);
      expect(await db.searchKeyword('tries'), hasLength(1));
      expect(await db.getDocument(docId), isNotNull);
    });
  });

  group('searchKeyword', () {
    late List<int> ids;

    setUp(() async {
      final docId = await addDoc();
      ids = await db.insertChunks(docId, const [
        NewChunk(
          page: 1,
          ordinal: 0,
          text: 'Dijkstra finds the shortest path in a weighted graph.',
        ),
        NewChunk(
          page: 2,
          ordinal: 1,
          text: 'A graph is a set of vertices and edges.',
        ),
        NewChunk(
          page: 3,
          ordinal: 2,
          text: "La complexité de l'algorithme de tri rapide est O(n log n).",
        ),
      ]);
    });

    test('ranks the chunk matching more terms first', () async {
      final hits = await db.searchKeyword('shortest path in a graph');

      expect(hits.map((h) => h.chunkId), [ids[0], ids[1]]);
      expect(hits.first.score, greaterThan(hits.last.score));
    });

    test('matches French text without accents', () async {
      final hits = await db.searchKeyword('complexite algorithme');

      expect(hits.single.chunkId, ids[2]);
    });

    test('accepts questions with FTS5 syntax characters', () async {
      final hits = await db.searchKeyword(
        'What is "Dijkstra" (NOT BFS)? path* -graph',
      );

      expect(hits.first.chunkId, ids[0]);
    });

    test('respects the limit', () async {
      expect(await db.searchKeyword('graph', limit: 1), hasLength(1));
    });

    test('returns nothing for no match or no words', () async {
      expect(await db.searchKeyword('quantum'), isEmpty);
      expect(await db.searchKeyword('?!'), isEmpty);
    });
  });
}
