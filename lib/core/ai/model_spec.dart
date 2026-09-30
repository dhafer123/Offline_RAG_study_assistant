import 'package:flutter/foundation.dart';

/// A model file the app downloads once and then uses offline.
@immutable
class ModelSpec {
  const ModelSpec({
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });

  final String fileName;
  final Uri url;
  final int sizeBytes;

  /// Lower-case hex SHA-256 of the complete file.
  final String sha256;

  /// Gemma 3 1B int4, hosted on this repo's GitHub Releases: Hugging Face
  /// requires a login for Gemma, which the app can't ship.
  static final gemma3 = ModelSpec(
    fileName: 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
    url: Uri.parse(
      'https://github.com/dhafer123/Offline_RAG_study_assistant/releases/'
      'download/models-v1/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
    ),
    sizeBytes: 584417280,
    sha256: '1325ae366d31950f137c9c357b9fa89448b176d76998180c08ceaca78bba98be',
  );
}
