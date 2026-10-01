import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/viewer/viewer_target.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('viewer_');
    container = ProviderContainer(
      overrides: [documentStoreProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<int> addDoc({bool withFile = true}) async {
    final path = '${dir.path}/game.pdf';
    if (withFile) File(path).writeAsBytesSync([37, 80, 68, 70]);
    return db.insertDocument(
      title: 'game.pdf',
      path: path,
      pageCount: 34,
      status: DocumentStatus.ready,
    );
  }

  Future<ViewerTarget> read({required int docId, int page = 27, int? chunk}) {
    final provider = viewerTargetProvider(
      docId: docId,
      page: page,
      chunkId: chunk,
    );
    // Auto-dispose: keep it alive until it has loaded.
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    return container.read(provider.future);
  }

  test('gives the file, the page and the chunk text to highlight', () async {
    final docId = await addDoc();
    final [chunkId] = await db.insertChunks(docId, [
      const NewChunk(page: 27, ordinal: 0, text: 'Godot 4 was chosen.'),
    ]);

    final target = await read(docId: docId, chunk: chunkId);

    expect(target.title, 'game.pdf');
    expect(target.path, endsWith('game.pdf'));
    expect(target.page, 27);
    expect(target.highlight, 'Godot 4 was chosen.');
  });

  test('opens without a highlight when no chunk is given or found', () async {
    final docId = await addDoc();

    expect((await read(docId: docId)).highlight, isNull);
    expect((await read(docId: docId, chunk: 999)).highlight, isNull);
  });

  test('keeps the page within the document', () async {
    final docId = await addDoc();

    expect((await read(docId: docId, page: 99)).page, 34);
    expect((await read(docId: docId, page: 0)).page, 1);
  });

  test('explains a deleted document or a missing file', () async {
    await expectLater(
      read(docId: 42),
      throwsA(
        isA<ViewerTargetException>().having(
          (e) => e.message,
          'message',
          'This document was removed from your library.',
        ),
      ),
    );
    final docId = await addDoc(withFile: false);
    await expectLater(
      read(docId: docId),
      throwsA(
        isA<ViewerTargetException>().having(
          (e) => e.message,
          'message',
          contains('missing'),
        ),
      ),
    );
  });
}
