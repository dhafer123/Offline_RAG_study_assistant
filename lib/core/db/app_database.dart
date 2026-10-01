import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/fts_query.dart';

/// SQLite database (drift) holding documents, chunks and the FTS5 index.
///
/// The schema is plain SQL run through drift's migration hooks: drift's code
/// generator can't be resolved alongside riverpod_generator on this Flutter
/// version (conflicting analyzer pins), so queries are written by hand.
class AppDatabase extends GeneratedDatabase implements DocumentStore {
  AppDatabase(
    super.executor, {
    DateTime Function()? clock,
    @visibleForTesting List<List<String>> steps = migrationSteps,
  }) : _clock = clock ?? DateTime.now,
       _steps = steps;

  /// Opens (or creates) the database file at [path] on a background isolate.
  factory AppDatabase.open(String path) =>
      AppDatabase(NativeDatabase.createInBackground(File(path)));

  /// Schema steps, one entry per version: `migrationSteps[n]` takes a database
  /// from version `n` to `n + 1`. Append a step to change the schema; never
  /// edit a step that has shipped.
  static const List<List<String>> migrationSteps = [
    // v1: documents, chunks, FTS5 index over chunk text.
    [
      '''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        path TEXT NOT NULL,
        page_count INTEGER NOT NULL DEFAULT 0 CHECK (page_count >= 0),
        indexed_at INTEGER,
        status TEXT NOT NULL
          CHECK (status IN ('pending', 'indexing', 'ready', 'failed'))
      )''',
      '''
      CREATE TABLE chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_id INTEGER NOT NULL REFERENCES documents (id) ON DELETE CASCADE,
        page INTEGER NOT NULL CHECK (page >= 1),
        ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
        text TEXT NOT NULL,
        UNIQUE (doc_id, ordinal)
      )''',
      // External-content FTS5 table: the text lives in `chunks` only.
      '''
      CREATE VIRTUAL TABLE chunks_fts USING fts5 (
        text,
        content = 'chunks',
        content_rowid = 'id',
        tokenize = 'unicode61 remove_diacritics 2'
      )''',
      '''
      CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
        INSERT INTO chunks_fts (rowid, text) VALUES (new.id, new.text);
      END''',
      '''
      CREATE TRIGGER chunks_ad AFTER DELETE ON chunks BEGIN
        INSERT INTO chunks_fts (chunks_fts, rowid, text)
          VALUES ('delete', old.id, old.text);
      END''',
      '''
      CREATE TRIGGER chunks_au AFTER UPDATE OF text ON chunks BEGIN
        INSERT INTO chunks_fts (chunks_fts, rowid, text)
          VALUES ('delete', old.id, old.text);
        INSERT INTO chunks_fts (rowid, text) VALUES (new.id, new.text);
      END''',
    ],
    // v2: chunk embeddings (see SqliteVectorIndex).
    [
      '''
      CREATE TABLE chunk_vectors (
        chunk_id INTEGER PRIMARY KEY REFERENCES chunks (id) ON DELETE CASCADE,
        vector BLOB NOT NULL
      )''',
    ],
  ];

  final DateTime Function() _clock;
  final List<List<String>> _steps;

  @override
  int get schemaVersion => _steps.length;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => _runSteps(from: 0, to: schemaVersion),
    onUpgrade: (_, from, to) => _runSteps(from: from, to: to),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _runSteps({required int from, required int to}) async {
    for (var version = from; version < to; version++) {
      for (final statement in _steps[version]) {
        await customStatement(statement);
      }
    }
  }

  @override
  Future<int> insertDocument({
    required String title,
    required String path,
    int pageCount = 0,
    DocumentStatus status = DocumentStatus.pending,
  }) {
    return customInsert(
      'INSERT INTO documents (title, path, page_count, status) '
      'VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(title),
        Variable.withString(path),
        Variable.withInt(pageCount),
        Variable.withString(status.name),
      ],
    );
  }

  @override
  Future<Document?> getDocument(int id) async {
    final row = await customSelect(
      'SELECT * FROM documents WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).getSingleOrNull();
    return row == null ? null : _toDocument(row);
  }

  @override
  Future<List<Document>> listDocuments() async {
    final rows = await customSelect(
      'SELECT * FROM documents ORDER BY id DESC',
    ).get();
    return rows.map(_toDocument).toList();
  }

  @override
  Future<void> updateDocument(
    int id, {
    DocumentStatus? status,
    int? pageCount,
  }) async {
    final sets = <String>[];
    final variables = <Variable>[];
    if (status != null) {
      sets.add('status = ?');
      variables.add(Variable.withString(status.name));
      if (status == DocumentStatus.ready) {
        sets.add('indexed_at = ?');
        variables.add(
          Variable.withInt(_clock().toUtc().millisecondsSinceEpoch),
        );
      }
    }
    if (pageCount != null) {
      sets.add('page_count = ?');
      variables.add(Variable.withInt(pageCount));
    }

    final changed = sets.isEmpty
        ? await _countDocuments(id)
        : await customUpdate(
            'UPDATE documents SET ${sets.join(', ')} WHERE id = ?',
            variables: [...variables, Variable.withInt(id)],
            updateKind: UpdateKind.update,
          );
    if (changed == 0) throw DocumentNotFoundException(id);
  }

  @override
  Future<void> deleteDocument(int id) async {
    // Chunks (and their FTS rows, via trigger) go with it: ON DELETE CASCADE.
    await customUpdate(
      'DELETE FROM documents WHERE id = ?',
      variables: [Variable.withInt(id)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<List<int>> insertChunks(int docId, List<NewChunk> chunks) {
    return transaction(() async {
      if (await _countDocuments(docId) == 0) {
        throw DocumentNotFoundException(docId);
      }
      final ids = <int>[];
      for (final chunk in chunks) {
        ids.add(
          await customInsert(
            'INSERT INTO chunks (doc_id, page, ordinal, text) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withInt(docId),
              Variable.withInt(chunk.page),
              Variable.withInt(chunk.ordinal),
              Variable.withString(chunk.text),
            ],
          ),
        );
      }
      return ids;
    });
  }

  @override
  Future<void> deleteChunks(int docId) async {
    await customUpdate(
      'DELETE FROM chunks WHERE doc_id = ?',
      variables: [Variable.withInt(docId)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<List<Chunk>> chunksForDocument(int docId) async {
    final rows = await customSelect(
      'SELECT * FROM chunks WHERE doc_id = ? ORDER BY ordinal',
      variables: [Variable.withInt(docId)],
    ).get();
    return rows.map(_toChunk).toList();
  }

  @override
  Future<List<Chunk>> chunksByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await customSelect(
      'SELECT * FROM chunks WHERE id IN ($placeholders)',
      variables: [for (final id in ids) Variable.withInt(id)],
    ).get();
    final byId = {for (final row in rows) row.read<int>('id'): _toChunk(row)};
    return [for (final id in ids) ?byId[id]];
  }

  @override
  Future<List<KeywordHit>> searchKeyword(String query, {int limit = 20}) async {
    final match = buildFtsQuery(query);
    if (match == null) return const [];
    final rows = await customSelect(
      'SELECT rowid AS chunk_id, bm25(chunks_fts) AS rank FROM chunks_fts '
      'WHERE chunks_fts MATCH ? ORDER BY rank LIMIT ?',
      variables: [Variable.withString(match), Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        KeywordHit(
          chunkId: row.read<int>('chunk_id'),
          score: -row.read<double>('rank'),
        ),
    ];
  }

  Future<int> _countDocuments(int id) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM documents WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).getSingle();
    return row.read<int>('n');
  }

  Document _toDocument(QueryRow row) {
    final indexedAt = row.readNullable<int>('indexed_at');
    return Document(
      id: row.read<int>('id'),
      title: row.read<String>('title'),
      path: row.read<String>('path'),
      pageCount: row.read<int>('page_count'),
      status: DocumentStatus.values.byName(row.read<String>('status')),
      indexedAt: indexedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(indexedAt, isUtc: true),
    );
  }

  Chunk _toChunk(QueryRow row) => Chunk(
    id: row.read<int>('id'),
    docId: row.read<int>('doc_id'),
    page: row.read<int>('page'),
    ordinal: row.read<int>('ordinal'),
    text: row.read<String>('text'),
  );
}
