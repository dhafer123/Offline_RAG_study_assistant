import 'dart:io';

import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

bool _initialized = false;

/// Loads a desktop pdfium build for host tests, downloading it once into
/// `.dart_tool/pdfrx`.
///
/// Replaces `pdfrxInitialize()`, which hangs on Windows with pdfrx_engine
/// 0.3.9: the worker isolate can run pdfium's init before it receives the
/// module path, then fails to load `pdfium.dll` by bare name. Setting the
/// path and starting the worker with a no-op job first avoids that race.
/// The app isn't affected: on Android pdfium is loaded by name from the APK.
Future<void> initPdfiumForTests() async {
  if (_initialized) return;
  final cacheDir = Directory('.dart_tool/pdfrx')..createSync(recursive: true);
  Pdfrx.getCacheDirectory ??= () => cacheDir.path;
  Pdfrx.pdfiumModulePath =
      await PDFiumDownloader.downloadAndGetPDFiumModulePath(
        cacheDir.path,
      );
  await PdfrxEntryFunctions.instance.compute((_) => 0, 0);
  await PdfrxEntryFunctions.instance.init();
  _initialized = true;
}
