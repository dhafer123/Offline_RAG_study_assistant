// Writes test/fixtures/pdf/sample.pdf, the fixture for the PDF extraction
// test. Run from the repo root: `dart run tool/make_fixture_pdf.dart`.
//
// The PDF is written by hand (no PDF library needed) and has four pages:
//   1. English text over several lines.
//   2. A drawn rectangle and the page number only, like a scanned page.
//   3. French text with accents.
//   4. Nothing at all.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _pages = <List<String>>[
  [
    'Binary search finds an item in a sorted array.',
    'It halves the search interval at every step,',
    'so it runs in logarithmic time.',
  ],
  ['2'],
  [
    'Le tri rapide choisit un pivot et partitionne le tableau.',
    'Sa complexité moyenne est O(n log n) ; le pire cas est quadratique.',
  ],
  [],
];

const _font =
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
    '/Encoding /WinAnsiEncoding >>';

String _escape(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

String _content(int index, List<String> lines) {
  final ops = StringBuffer();
  // Page 2: a filled box standing in for a scanned image.
  if (index == 1) ops.writeln('0.8 g 72 300 468 400 re f 0 g');
  if (lines.isNotEmpty) {
    // Page 2's number sits at the bottom, like a footer.
    final (x, y) = index == 1 ? (300, 40) : (72, 720);
    ops
      ..writeln('BT /F1 12 Tf 16 TL $x $y Td')
      ..writeAll([for (final l in lines) '(${_escape(l)}) Tj T*'], '\n')
      ..writeln()
      ..writeln('ET');
  }
  return ops.toString();
}

void main() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '', // Pages, filled in below.
    _font,
  ];
  final pageRefs = <String>[];
  for (var i = 0; i < _pages.length; i++) {
    final content = _content(i, _pages[i]);
    final contentObj = objects.length + 2;
    pageRefs.add('${objects.length + 1} 0 R');
    objects
      ..add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents $contentObj 0 R >>',
      )
      ..add(
        '<< /Length ${latin1.encode(content).length} >>\n'
        'stream\n${content}endstream',
      );
  }
  objects[1] =
      '<< /Type /Pages /Kids [${pageRefs.join(' ')}] '
      '/Count ${_pages.length} >>';

  // Latin-1 matches WinAnsiEncoding for the accented letters used here.
  final out = BytesBuilder()..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.add(latin1.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
  }
  final xrefAt = out.length;
  final xref = StringBuffer()
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets) {
    xref.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  xref.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xrefAt\n%%EOF\n',
  );
  out.add(latin1.encode(xref.toString()));

  final file = File('test/fixtures/pdf/sample.pdf')
    ..createSync(recursive: true)
    ..writeAsBytesSync(out.takeBytes());
  stdout.writeln('Wrote ${file.path}');
}
