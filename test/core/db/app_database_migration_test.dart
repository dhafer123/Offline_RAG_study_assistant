import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';

Future<Set<String>> _names(AppDatabase db, String type) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = '$type' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return {for (final r in rows) r.read<String>('name')};
}

Future<List<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return [for (final r in rows) r.read<String>('name')];
}

Future<int> _userVersion(AppDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

void main() {
  test('a new database gets the latest schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _userVersion(db), db.schemaVersion);
    expect(
      await _names(db, 'table'),
      containsAll(<String>['documents', 'chunks', 'chunks_fts']),
    );
    expect(await _columns(db, 'documents'), [
      'id',
      'title',
      'path',
      'page_count',
      'indexed_at',
      'status',
    ]);
    expect(await _columns(db, 'chunks'), [
      'id',
      'doc_id',
      'page',
      'ordinal',
      'text',
    ]);
    expect(
      await _names(db, 'trigger'),
      {'chunks_ai', 'chunks_ad', 'chunks_au'},
    );
  });

  test('foreign keys are enforced on every open', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  test('reopening an existing file keeps its data', () async {
    final dir = await Directory.systemTemp.createTemp('study_db_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/study.db');

    final first = AppDatabase(NativeDatabase(file));
    final docId = await first.insertDocument(title: 'Algo', path: '/a.pdf');
    await first.insertChunks(docId, const [
      NewChunk(page: 1, ordinal: 0, text: 'dijkstra shortest path'),
    ]);
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);

    expect(await _userVersion(second), second.schemaVersion);
    expect((await second.getDocument(docId))?.title, 'Algo');
    expect(await second.searchKeyword('dijkstra'), hasLength(1));
  });

  test('upgrading runs only the missing steps and keeps data', () async {
    final dir = await Directory.systemTemp.createTemp('study_db_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/study.db');

    final v1 = AppDatabase(NativeDatabase(file));
    final docId = await v1.insertDocument(title: 'Algo', path: '/a.pdf');
    await v1.close();

    // A future v2 step. Re-running the v1 step would fail ("table documents
    // already exists"), so this also checks that only the new step runs.
    final v2 = AppDatabase(
      NativeDatabase(file),
      steps: [
        ...AppDatabase.migrationSteps,
        ['ALTER TABLE documents ADD COLUMN course TEXT'],
      ],
    );
    addTearDown(v2.close);

    expect(await _userVersion(v2), AppDatabase.migrationSteps.length + 1);
    expect(await _columns(v2, 'documents'), contains('course'));
    expect((await v2.getDocument(docId))?.title, 'Algo');
  });
}
