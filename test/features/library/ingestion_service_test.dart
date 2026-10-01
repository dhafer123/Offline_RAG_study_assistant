import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/sqlite_vector_index.dart';
import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';

import '../../helpers/fake_embedder.dart';
import '../../helpers/fake_pdf_text_extractor.dart';

const _pages = [
  'Binary search finds an item in a sorted array by halving the interval.\n1',
  'Dijkstra computes shortest paths in graphs with non-negative weights.\n2',
];

void main() {
  late AppDatabase db;
  late SqliteVectorIndex index;
  late FakeEmbedder embedder;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    embedder = FakeEmbedder();
    index = SqliteVectorIndex(db, dimension: embedder.dimension);
  });

  tearDown(() => db.close());

  IngestionService service(PdfTextExtractor extractor, {FakeEmbedder? e}) =>
      IngestionService(
        extractor: extractor,
        store: db,
        embedder: e ?? embedder,
        index: index,
      );

  test('stores cleaned chunks and their vectors, then marks ready', () async {
    final result = await service(
      FakePdfTextExtractor(_pages),
    ).ingest('/pdfs/algo.pdf', title: 'algo.pdf');

    final doc = await db.getDocument(result.documentId);
    expect(doc!.status, DocumentStatus.ready);
    expect(doc.pageCount, 2);
    expect(doc.indexedAt, isNotNull);

    final chunks = await db.chunksForDocument(result.documentId);
    expect(chunks.map((c) => c.page), [1, 2]);
    // Cleaned: the page numbers are gone.
    expect(chunks.first.text, endsWith('halving the interval.'));
    expect(result.chunkCount, 2);
    expect(await index.count(), 2);
    expect(embedder.loadCalls, 1);
  });

  test('reports every stage in order', () async {
    final stages = <IngestionStage>[];

    await service(FakePdfTextExtractor(_pages)).ingest(
      '/pdfs/algo.pdf',
      title: 'algo.pdf',
      onProgress: (p) {
        if (stages.isEmpty || stages.last != p.stage) stages.add(p.stage);
      },
    );

    expect(stages, IngestionStage.values);
  });

  test('a scanned PDF fails without embedding anything', () async {
    final s = service(FakePdfTextExtractor(['', '12']));

    await expectLater(
      s.ingest('/pdfs/scan.pdf', title: 'scan.pdf'),
      throwsA(isA<IngestionException>()),
    );

    final doc = (await db.listDocuments()).single;
    expect(doc.status, DocumentStatus.failed);
    expect(embedder.documentCalls, 0);
  });

  test('an extraction error marks the document failed', () async {
    final s = service(
      FakePdfTextExtractor(
        const [],
        error: const PdfExtractionException(
          PdfExtractionError.passwordProtected,
        ),
      ),
    );

    await expectLater(
      s.ingest('/pdfs/locked.pdf', title: 'locked.pdf'),
      throwsA(
        isA<IngestionException>().having(
          (e) => e.cause,
          'cause',
          isA<PdfExtractionException>(),
        ),
      ),
    );
    expect((await db.listDocuments()).single.status, DocumentStatus.failed);
  });

  test('an embedding error stores no chunk and marks failed', () async {
    final failing = FakeEmbedder(failOnCall: 2);
    final s = IngestionService(
      extractor: FakePdfTextExtractor(_pages),
      store: db,
      embedder: failing,
      index: SqliteVectorIndex(db, dimension: failing.dimension),
    );

    await expectLater(
      s.ingest('/pdfs/algo.pdf', title: 'algo.pdf'),
      throwsA(isA<IngestionException>()),
    );

    final doc = (await db.listDocuments()).single;
    expect(doc.status, DocumentStatus.failed);
    expect(await db.chunksForDocument(doc.id), isEmpty);
    expect(await index.count(), 0);
  });
}
