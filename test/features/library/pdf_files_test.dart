import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/features/library/pdf_files.dart';

void main() {
  late Directory root;
  late PdfFiles files;
  late File source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pdf_files_');
    files = PdfFiles('${root.path}/pdfs');
    source = File('${root.path}/picked.pdf')..writeAsStringSync('%PDF-1.4');
  });

  tearDown(() => root.delete(recursive: true));

  test('copies the PDF into the folder, creating it', () async {
    final path = await files.importCopy(source.path, name: 'Cours 1.pdf');

    expect(path, '${root.path}/pdfs/Cours 1.pdf');
    expect(File(path).readAsStringSync(), '%PDF-1.4');
    expect(source.existsSync(), isTrue);
  });

  test('numbers the copy when the name is taken', () async {
    final first = await files.importCopy(source.path, name: 'notes.pdf');
    final second = await files.importCopy(source.path, name: 'notes.pdf');
    final third = await files.importCopy(source.path, name: 'summary');

    expect(first, endsWith('/notes.pdf'));
    expect(second, endsWith('/notes (2).pdf'));
    expect(third, endsWith('/summary.pdf'));
  });

  test('makes the name filesystem-safe and keeps accents', () async {
    final path = await files.importCopy(
      source.path,
      name: "État: l'art/v2?.pdf",
    );

    expect(path, endsWith('/État_ l_art_v2_.pdf'));
  });

  test('falls back to a default name', () async {
    final path = await files.importCopy(source.path, name: '.pdf');

    expect(path, endsWith('/document.pdf'));
  });

  test('deletes its own copies only', () async {
    final copy = await files.importCopy(source.path, name: 'a.pdf');

    await files.delete(copy);
    await files.delete(source.path);
    await files.delete('${root.path}/pdfs/missing.pdf');

    expect(File(copy).existsSync(), isFalse);
    expect(source.existsSync(), isTrue, reason: 'outside the folder');
  });

  test('titleFor drops the .pdf extension', () {
    expect(PdfFiles.titleFor('Algo 2.PDF'), 'Algo 2');
    expect(PdfFiles.titleFor('notes'), 'notes');
  });
}
