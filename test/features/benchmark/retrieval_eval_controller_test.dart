import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/sqlite_vector_index.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';
import 'package:offline_study_assistant/features/benchmark/retrieval_eval_controller.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_embedder.dart';

const _questions = '''
{"questions": [
  {"id": "q1", "lang": "en", "question": "Which engine renders the game scenes?",
   "answerable": true, "doc": "game", "pages": [2], "answer": "Godot"},
  {"id": "q2", "lang": "fr", "question": "Quel est le prix du ticket ?",
   "answerable": true, "doc": "game", "pages": [9], "answer": "?"},
  {"id": "u1", "lang": "en", "question": "Who invented transformers?",
   "answerable": false}
]}
''';

void main() {
  late Directory exportDir;
  late AppDatabase db;
  late FakeEmbedder embedder;

  setUp(() async {
    exportDir = await Directory.systemTemp.createTemp('eval_');
    db = AppDatabase(NativeDatabase.memory());
    embedder = FakeEmbedder();
    final index = SqliteVectorIndex(db, dimension: embedder.dimension);
    final docId = await db.insertDocument(
      title: 'game.pdf',
      path: '/pdfs/game.pdf',
      status: DocumentStatus.ready,
    );
    const texts = [
      'The menu has a start button.',
      'The game scenes are rendered by the Godot engine.',
    ];
    final ids = await db.insertChunks(docId, [
      for (var i = 0; i < texts.length; i++)
        NewChunk(page: i + 1, ordinal: i, text: texts[i]),
    ]);
    await index.add([
      for (var i = 0; i < ids.length; i++)
        ChunkVector(chunkId: ids[i], vector: embedder.vectorFor(texts[i])),
    ]);
  });

  tearDown(() async {
    await db.close();
    await exportDir.delete(recursive: true);
  });

  test('runs every question, summarizes and exports JSON', () async {
    final container = ProviderContainer(
      overrides: [
        evalQuestionsSourceProvider.overrideWith((ref) async => _questions),
        documentStoreProvider.overrideWithValue(db),
        vectorIndexProvider.overrideWithValue(
          SqliteVectorIndex(db, dimension: embedder.dimension),
        ),
        embedderProvider.overrideWithValue(embedder),
        exportDirectoryProvider.overrideWithValue(exportDir.path),
      ],
    );
    addTearDown(container.dispose);
    container.listen(retrievalEvalControllerProvider, (_, _) {});

    await container.read(retrievalEvalControllerProvider.notifier).run();
    final state = container.read(retrievalEvalControllerProvider);

    expect(state.status, RetrievalEvalStatus.done);
    expect(state.results, hasLength(3));
    expect(state.summary!.answerable, 2);
    expect(state.summary!.found, 1);
    expect(state.misses.single.question.id, 'q2');
    expect(embedder.queries, hasLength(3));

    final file = File(state.exportPath!);
    expect(file.parent.path, exportDir.path);
    expect(file.uri.pathSegments.last, startsWith('retrieval_hybrid_'));
    final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(report['method'], 'hybrid');
    expect(report['indexed_documents'], ['game.pdf']);
    expect((report['summary'] as Map)['recall_at_k'], 0.5);
  });

  test('evaluates the selected mode', () async {
    final container = ProviderContainer(
      overrides: [
        evalQuestionsSourceProvider.overrideWith((ref) async => _questions),
        documentStoreProvider.overrideWithValue(db),
        vectorIndexProvider.overrideWithValue(
          SqliteVectorIndex(db, dimension: embedder.dimension),
        ),
        embedderProvider.overrideWithValue(embedder),
        exportDirectoryProvider.overrideWithValue(exportDir.path),
      ],
    );
    addTearDown(container.dispose);
    container.listen(retrievalEvalControllerProvider, (_, _) {});
    final controller = container.read(retrievalEvalControllerProvider.notifier)
      ..selectMode(RetrievalMode.keyword);

    await controller.run();
    final state = container.read(retrievalEvalControllerProvider);

    expect(state.mode, RetrievalMode.keyword);
    expect(state.status, RetrievalEvalStatus.done);
    expect(embedder.loadCalls, 0);
    expect(File(state.exportPath!).uri.pathSegments.last, contains('keyword'));
    final report =
        jsonDecode(File(state.exportPath!).readAsStringSync())
            as Map<String, dynamic>;
    expect(report['method'], 'keyword');
  });

  test('reports a broken questions file as an error', () async {
    final container = ProviderContainer(
      overrides: [
        evalQuestionsSourceProvider.overrideWith((ref) async => '{oops'),
        exportDirectoryProvider.overrideWithValue(exportDir.path),
      ],
    );
    addTearDown(container.dispose);
    container.listen(retrievalEvalControllerProvider, (_, _) {});

    await container.read(retrievalEvalControllerProvider.notifier).run();
    final state = container.read(retrievalEvalControllerProvider);

    expect(state.status, RetrievalEvalStatus.error);
    expect(state.errorMessage, contains('FormatException'));
  });
}
