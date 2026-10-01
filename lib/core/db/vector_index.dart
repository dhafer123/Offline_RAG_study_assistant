import 'package:flutter/foundation.dart';

/// The embedding of one stored chunk.
@immutable
class ChunkVector {
  const ChunkVector({required this.chunkId, required this.vector});

  final int chunkId;
  final List<double> vector;
}

/// A semantic match. Higher [similarity] means closer in meaning.
@immutable
class VectorHit {
  const VectorHit({required this.chunkId, required this.similarity});

  final int chunkId;

  /// Cosine similarity between the query and the chunk, from -1 to 1.
  final double similarity;
}

/// Stores chunk embeddings and finds the nearest ones to a query vector.
///
/// Implemented by `SqliteVectorIndex` (vectors in the app database); the rest
/// of the app only depends on this interface.
abstract interface class VectorIndex {
  /// Length every vector must have.
  int get dimension;

  /// Stores [vectors], replacing any existing vector for the same chunk.
  ///
  /// Throws [ArgumentError] if a vector has the wrong length.
  Future<void> add(List<ChunkVector> vectors);

  /// The [k] chunks most similar to [query], best first.
  Future<List<VectorHit>> search(List<double> query, {int k = 20});

  /// Removes the vectors of every chunk of [docId].
  Future<void> deleteByDoc(int docId);

  /// Number of stored vectors.
  Future<int> count();
}
