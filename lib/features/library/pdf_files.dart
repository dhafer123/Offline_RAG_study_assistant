import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// A PDF the user picked, before it is copied into the app.
typedef PickedPdf = ({String path, String name});

/// Asks the user for a PDF. Null when they cancel.
// An interface so the Library controller can be tested without the platform
// picker.
// ignore: one_member_abstracts
abstract interface class PdfPicker {
  Future<PickedPdf?> pick();
}

/// [PdfPicker] using the system document picker (file_selector). On Android
/// it needs no storage permission; the result is a temporary copy in the
/// app's cache.
class FileSelectorPdfPicker implements PdfPicker {
  const FileSelectorPdfPicker();

  static const _pdf = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
    uniformTypeIdentifiers: ['com.adobe.pdf'],
  );

  @override
  Future<PickedPdf?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_pdf]);
    return file == null ? null : (path: file.path, name: file.name);
  }
}

/// The app's own copies of imported PDFs, in [directory].
///
/// Imported files are copied so they stay available offline whatever happens
/// to the original, and so the viewer can open them later.
class PdfFiles {
  PdfFiles(this.directory);

  final String directory;

  // Letters (accents included), digits, `_`, `.`, `-` and spaces are kept.
  static final _unsafe = RegExp(r'[^\p{L}\p{N}_.\- ]', unicode: true);

  /// Copies [source] into [directory] and returns the copy's path.
  ///
  /// The file is named after [name], made filesystem-safe, with " (2)",
  /// " (3)"... added when that name is taken.
  Future<String> importCopy(String source, {required String name}) async {
    await Directory(directory).create(recursive: true);
    final base = _baseName(name);
    var target = File('$directory/$base.pdf');
    for (var n = 2; target.existsSync(); n++) {
      target = File('$directory/$base ($n).pdf');
    }
    await File(source).copy(target.path);
    return target.path;
  }

  /// Deletes [path] if it is one of our copies; files elsewhere are never
  /// touched. No-op if it is already gone.
  Future<void> delete(String path) async {
    final file = File(path);
    if (file.parent.absolute.path != Directory(directory).absolute.path) {
      return;
    }
    if (file.existsSync()) await file.delete();
  }

  /// Title shown for a PDF named [name]: the file name without ".pdf".
  static String titleFor(String name) => name.toLowerCase().endsWith('.pdf')
      ? name.substring(0, name.length - 4)
      : name;

  static String _baseName(String name) {
    final safe = titleFor(name).replaceAll(_unsafe, '_').trim();
    return safe.isEmpty ? 'document' : safe;
  }
}
