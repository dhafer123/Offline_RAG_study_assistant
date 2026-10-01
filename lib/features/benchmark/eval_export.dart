import 'dart:convert';
import 'dart:io';

/// `<prefix>_20261001-201612.json`: sortable, and safe in file names.
String reportFileName(String prefix, DateTime time) {
  final stamp = time
      .toIso8601String()
      .split('.')
      .first
      .replaceAll(RegExp('[-:]'), '')
      .replaceAll('T', '-');
  return '${prefix}_$stamp.json';
}

/// Writes [report] as indented JSON to [directory]/[fileName], replacing
/// any previous version, and returns the file's path.
Future<String> writeReport(
  String directory,
  String fileName,
  Map<String, Object?> report,
) async {
  final dir = Directory(directory);
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  return file.path;
}
