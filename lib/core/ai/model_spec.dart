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

  /// A file on this repo's `models-v1` GitHub release. Hugging Face requires
  /// a login for Gemma models, which the app can't ship.
  ModelSpec.release({
    required String fileName,
    required int sizeBytes,
    required String sha256,
  }) : this(
         fileName: fileName,
         url: Uri.parse('$_releaseBase/$fileName'),
         sizeBytes: sizeBytes,
         sha256: sha256,
       );

  static const _releaseBase =
      'https://github.com/dhafer123/Offline_RAG_study_assistant/releases/'
      'download/models-v1';

  final String fileName;
  final Uri url;
  final int sizeBytes;

  /// Lower-case hex SHA-256 of the complete file.
  final String sha256;

  /// Gemma 3 1B int4: generates the answers.
  static final gemma3 = ModelSpec.release(
    fileName: 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
    sizeBytes: 584417280,
    sha256: '1325ae366d31950f137c9c357b9fa89448b176d76998180c08ceaca78bba98be',
  );

  /// EmbeddingGemma 300M (512-token build): embeds passages and questions.
  /// The file name must match `GemmaEmbedder.modelFileName`.
  static final embeddingGemma = ModelSpec.release(
    fileName: 'embeddinggemma-300M_seq512_mixed-precision.tflite',
    sizeBytes: 179132472,
    sha256: 'ad09e81557203cb0e177abf9bf8727dfe138a7d394aa0f70f0b2ed16432e121a',
  );

  /// EmbeddingGemma's tokenizer (`GemmaEmbedder.tokenizerFileName`).
  static final embeddingTokenizer = ModelSpec.release(
    fileName: 'sentencepiece.model',
    sizeBytes: 4683319,
    sha256: 'd6daa52d93d7aad10e8388bd526c4e501d914b47177398d1d9621f1fe48438c7',
  );

  /// Everything the app needs, downloaded as one bundle: 733 MB.
  static final List<ModelSpec> all = [
    gemma3,
    embeddingGemma,
    embeddingTokenizer,
  ];
}
