import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/db/sqlite_vector_index.dart';
import 'package:offline_study_assistant/core/pdf/pdf_text_extractor.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';
import 'package:offline_study_assistant/features/library/library_controller.dart';
import 'package:offline_study_assistant/features/library/pdf_files.dart';

import '../../helpers/fake_embedder.dart';

/// Extracts fixed pages per file name; unknown names fail as invalid PDFs.
/// A file name in [gates] waits for its completer before returning.
class ScriptedExtractor implements PdfTextExtractor {
  final pagesByName = <String, List<String>>{};
  final gates = <String, Completer<void>>{};

  @override
  Future<ExtractedDocument> extract(
    String path, {
    void Function(int done, int total)? onProgress,
  }) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    await gates[name]?.future;
    final pages = pagesByName[name];
    if (pages == null) {
      throw const PdfExtractionException(PdfExtractionError.invalidPdf);
    }
    return ExtractedDocument([
      for (var i = 0; i < pages.length; i++)
        ExtractedPage(pageNumber: i + 1, text: pages[i], hasText: true),
    ]);
  }
}

class FakeFrameMonitor implements FrameMonitor {
  int starts = 0;
  int stops = 0;

  @override
  void start() => starts++;

  @override
  FrameStats stop() {
    stops++;
    return FrameStats();
  }
}

class FakePicker implements PdfPicker {
  final results = <PickedPdf?>[];

  @override
  Future<PickedPdf?> pick() async => results.removeAt(0);
}

void main() {
  late Directory root;
  late AppDatabase db;
  late SqliteVectorIndex index;
  late ScriptedExtractor extractor;
  late FakePicker picker;
  late FakeFrameMonitor frames;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('library_');
    db = AppDatabase(NativeDatabase.memory());
    index = SqliteVectorIndex(db, dimension: 64);
    extractor = ScriptedExtractor();
    picker = FakePicker();
    frames = FakeFrameMonitor();
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        pdfsDirectoryProvider.overrideWithValue('${root.path}/pdfs'),
        documentStoreProvider.overrideWithValue(db),
        vectorIndexProvider.overrideWithValue(index),
        embedderProvider.overrideWithValue(FakeEmbedder()),
        pdfTextExtractorProvider.overrideWithValue(extractor),
        pdfPickerProvider.overrideWithValue(picker),
        frameMonitorProvider.overrideWithValue(frames),
      ],
    );
    addTearDown(container.dispose);
    container.listen(libraryControllerProvider, (_, _) {});
    return container;
  }

  LibraryState stateOf(ProviderContainer c) =>
      c.read(libraryControllerProvider);
  LibraryController controllerOf(ProviderContainer c) =>
      c.read(libraryControllerProvider.notifier);

  Future<void> idle(ProviderContainer c) async {
    for (var i = 0; i < 500; i++) {
      final s = stateOf(c);
      if (!s.loading && s.runningId == null && s.queued.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the library never became idle');
  }

  /// Makes a picked file named [name] whose text is [pages].
  void willPick(String name, {List<String>? pages}) {
    final file = File('${root.path}/picked_$name')
      ..writeAsStringSync('%PDF-1.4');
    picker.results.add((path: file.path, name: name));
    if (pages != null) extractor.pagesByName[name] = pages;
  }

  test('starts with the stored documents', () async {
    await db.insertDocument(
      title: 'Old',
      path: '/x.pdf',
      status: DocumentStatus.ready,
    );
    final c = makeContainer();

    await idle(c);

    expect(stateOf(c).documents.map((d) => d.title), ['Old']);
  });

  test('imports a PDF: copies it, indexes it, marks it ready', () async {
    final c = makeContainer();
    await idle(c);
    willPick('Graphs.pdf', pages: ['Dijkstra finds shortest paths.']);

    await controllerOf(c).importPdf();
    await idle(c);

    final doc = stateOf(c).documents.single;
    expect(doc.title, 'Graphs');
    expect(doc.status, DocumentStatus.ready);
    expect(doc.path, '${root.path}/pdfs/Graphs.pdf');
    expect(File(doc.path).existsSync(), isTrue);
    expect(await db.searchKeyword('dijkstra'), hasLength(1));
    expect(await index.count(), 1);
    expect((frames.starts, frames.stops), (1, 1));
  });

  test('does nothing when the user cancels the picker', () async {
    final c = makeContainer();
    await idle(c);
    picker.results.add(null);

    await controllerOf(c).importPdf();
    await idle(c);

    expect(stateOf(c).documents, isEmpty);
    expect(stateOf(c).message, isNull);
  });

  test('indexes one document at a time, in import order', () async {
    final c = makeContainer();
    await idle(c);
    extractor.gates['a.pdf'] = Completer<void>();
    willPick('a.pdf', pages: ['First document text.']);
    willPick('b.pdf', pages: ['Second document text.']);

    await controllerOf(c).importPdf();
    await controllerOf(c).importPdf();
    final a = stateOf(c).documents.firstWhere((d) => d.title == 'a');
    final b = stateOf(c).documents.firstWhere((d) => d.title == 'b');

    expect(stateOf(c).runningId, a.id);
    expect(stateOf(c).queued, [b.id]);
    expect(stateOf(c).isBusy(b.id), isTrue);

    extractor.gates['a.pdf']!.complete();
    await idle(c);

    expect(
      stateOf(c).documents.map((d) => d.status),
      everyElement(DocumentStatus.ready),
    );
  });

  test('a failed document shows why, and retry indexes it', () async {
    final c = makeContainer();
    await idle(c);
    willPick('broken.pdf');

    await controllerOf(c).importPdf();
    await idle(c);

    final doc = stateOf(c).documents.single;
    expect(doc.status, DocumentStatus.failed);
    expect(stateOf(c).errors[doc.id], 'This file is not a valid PDF.');

    extractor.pagesByName['broken.pdf'] = ['Now it has text.'];
    await controllerOf(c).retry(doc.id);
    await idle(c);

    expect(stateOf(c).documents.single.status, DocumentStatus.ready);
    expect(stateOf(c).errors, isEmpty);
  });

  test('delete removes the document, its vectors and the file', () async {
    final c = makeContainer();
    await idle(c);
    willPick('a.pdf', pages: ['Some text to index.']);
    await controllerOf(c).importPdf();
    await idle(c);
    final doc = stateOf(c).documents.single;

    await controllerOf(c).delete(doc.id);

    expect(stateOf(c).documents, isEmpty);
    expect(await index.count(), 0);
    expect(File(doc.path).existsSync(), isFalse);
  });

  test('resumes documents interrupted by the app closing', () async {
    final pending = await db.insertDocument(title: 'p', path: '/pdfs/p.pdf');
    final interrupted = await db.insertDocument(
      title: 'i',
      path: '/pdfs/i.pdf',
      status: DocumentStatus.indexing,
    );
    extractor.pagesByName
      ..['p.pdf'] = ['Pending text.']
      ..['i.pdf'] = ['Interrupted text.'];

    final c = makeContainer();
    await idle(c);

    for (final id in [pending, interrupted]) {
      expect((await db.getDocument(id))!.status, DocumentStatus.ready);
    }
  });

  group('describeIngestionError', () {
    IngestionException wrap(Object cause) =>
        IngestionException('failed', cause: cause);

    test('explains extraction errors', () {
      expect(
        describeIngestionError(
          wrap(
            const PdfExtractionException(PdfExtractionError.passwordProtected),
          ),
        ),
        'This PDF is password-protected.',
      );
      expect(
        describeIngestionError(
          wrap(const PdfExtractionException(PdfExtractionError.fileNotFound)),
        ),
        contains('missing'),
      );
    });

    test('explains embedder errors', () {
      expect(
        describeIngestionError(wrap(const EmbedderException('boom'))),
        contains('embedding model'),
      );
    });

    test("uses the service's own message when there is no cause", () {
      expect(
        describeIngestionError(
          const IngestionException('This PDF has no text layer'),
        ),
        'This PDF has no text layer',
      );
    });
  });
}
