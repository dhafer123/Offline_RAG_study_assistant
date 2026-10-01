import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/sqlite_vector_index.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';

const _dim = 4;

void main() {
  late AppDatabase db;
  late SqliteVectorIndex index;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    index = SqliteVectorIndex(db, dimension: _dim);
  });

  tearDown(() => db.close());

  /// Inserts a document with one chunk per vector; returns the chunk ids.
  Future<List<int>> addDoc(List<List<double>> vectors) async {
    final docId = await db.insertDocument(title: 'Doc', path: '/doc.pdf');
    final ids = await db.insertChunks(docId, [
      for (var i = 0; i < vectors.length; i++)
        NewChunk(page: 1, ordinal: i, text: 'chunk $i'),
    ]);
    await index.add([
      for (var i = 0; i < ids.length; i++)
        ChunkVector(chunkId: ids[i], vector: vectors[i]),
    ]);
    return ids;
  }

  test('returns the closest chunks first with cosine similarity', () async {
    final ids = await addDoc([
      [1, 0, 0, 0],
      [0, 1, 0, 0],
      [1, 1, 0, 0],
    ]);

    final hits = await index.search([1, 0, 0, 0]);

    expect(hits.map((h) => h.chunkId), [ids[0], ids[2], ids[1]]);
    expect(hits[0].similarity, closeTo(1, 1e-6));
    expect(hits[1].similarity, closeTo(0.7071, 1e-4));
    expect(hits[2].similarity, closeTo(0, 1e-6));
  });

  test('ignores vector length: only the direction counts', () async {
    final ids = await addDoc([
      [10, 0, 0, 0],
      [0, 0.1, 0, 0],
    ]);

    final hits = await index.search([0, 5, 0, 0]);

    expect(hits.first.chunkId, ids[1]);
    expect(hits.first.similarity, closeTo(1, 1e-6));
  });

  test('scores opposite vectors as -1', () async {
    await addDoc([
      [-1, 0, 0, 0],
    ]);

    final hits = await index.search([1, 0, 0, 0]);

    expect(hits.single.similarity, closeTo(-1, 1e-6));
  });

  test('returns at most k hits', () async {
    await addDoc([
      for (var i = 0; i < 10; i++) [1, i.toDouble(), 0, 0],
    ]);

    expect(await index.search([1, 0, 0, 0], k: 3), hasLength(3));
    expect(await index.search([1, 0, 0, 0], k: 0), isEmpty);
  });

  test('returns nothing for an empty index or a zero query', () async {
    expect(await index.search([1, 0, 0, 0]), isEmpty);

    await addDoc([
      [1, 0, 0, 0],
    ]);
    expect(await index.search([0, 0, 0, 0]), isEmpty);
  });

  test('rejects vectors and queries of the wrong length', () async {
    final ids = await addDoc([
      [1, 0, 0, 0],
    ]);

    expect(
      () => index.add([
        ChunkVector(chunkId: ids.single, vector: const [1, 0]),
      ]),
      throwsArgumentError,
    );
    expect(() => index.search([1, 0]), throwsArgumentError);
  });

  test('adding a vector for the same chunk replaces it', () async {
    final ids = await addDoc([
      [1, 0, 0, 0],
    ]);

    await index.add([
      ChunkVector(chunkId: ids.single, vector: const [0, 1, 0, 0]),
    ]);

    expect(await index.count(), 1);
    final hits = await index.search([0, 1, 0, 0]);
    expect(hits.single.similarity, closeTo(1, 1e-6));
  });

  test('sees vectors added after a search', () async {
    await addDoc([
      [1, 0, 0, 0],
    ]);
    await index.search([1, 0, 0, 0]);

    final later = await addDoc([
      [0, 0, 1, 0],
    ]);

    expect((await index.search([0, 0, 1, 0])).first.chunkId, later.single);
  });

  test('deleteByDoc removes only that document', () async {
    final keep = await addDoc([
      [1, 0, 0, 0],
    ]);
    final drop = await addDoc([
      [0, 1, 0, 0],
      [0, 0, 1, 0],
    ]);
    final dropDoc = (await db.chunksByIds(drop)).first.docId;
    await index.search([1, 0, 0, 0]);

    await index.deleteByDoc(dropDoc);

    expect(await index.count(), 1);
    final hits = await index.search([0, 1, 0, 0]);
    expect(hits.map((h) => h.chunkId), keep);
  });

  test('vectors go when their document is deleted from the database', () async {
    final keep = await addDoc([
      [1, 0, 0, 0],
    ]);
    final drop = await addDoc([
      [0, 1, 0, 0],
    ]);
    final dropDoc = (await db.chunksByIds(drop)).single.docId;
    // Fill the in-memory cache before deleting behind the index's back.
    expect(await index.search([0, 1, 0, 0]), hasLength(2));

    await db.deleteDocument(dropDoc);

    expect(await index.count(), 1);
    final hits = await index.search([0, 1, 0, 0]);
    expect(hits.map((h) => h.chunkId), keep);
  });

  test('vectors survive closing and reopening the database', () async {
    final dir = await Directory.systemTemp.createTemp('vector_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/study.db');

    final first = AppDatabase(NativeDatabase(file));
    final docId = await first.insertDocument(title: 'Doc', path: '/d.pdf');
    final ids = await first.insertChunks(docId, const [
      NewChunk(page: 1, ordinal: 0, text: 'a'),
    ]);
    await SqliteVectorIndex(first, dimension: _dim).add([
      ChunkVector(chunkId: ids.single, vector: const [0, 0, 0, 2]),
    ]);
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final hits = await SqliteVectorIndex(
      second,
      dimension: _dim,
    ).search([0, 0, 0, 1]);

    expect(hits.single.chunkId, ids.single);
    expect(hits.single.similarity, closeTo(1, 1e-6));
  });
}
