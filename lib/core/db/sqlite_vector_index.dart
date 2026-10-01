import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/core/db/vector_index.dart';

/// [VectorIndex] storing vectors in the app database (`chunk_vectors`) and
/// searching them by brute force.
///
/// Vectors are normalized before they are stored, so cosine similarity is a
/// plain dot product. All vectors are kept in one [Float32List] after the
/// first search (3 KB per chunk: ~5 MB for 1,500 chunks). Brute force is
/// exact, and fast enough at this scale: qdrant-edge also brute-forces below
/// ~20k points.
///
/// Rows cascade-delete with their chunk, so deleting a document or its chunks
/// in `AppDatabase` also removes the vectors.
class SqliteVectorIndex implements VectorIndex {
  SqliteVectorIndex(this._db, {this.dimension = 768});

  final AppDatabase _db;

  @override
  final int dimension;

  /// In-memory copy of every vector, built on the first search. Dropped when
  /// this index writes, and rebuilt when the row count changes (chunks
  /// deleted through `AppDatabase` cascade here without this class knowing).
  _Matrix? _cache;

  @override
  Future<void> add(List<ChunkVector> vectors) async {
    for (final v in vectors) {
      if (v.vector.length != dimension) {
        throw ArgumentError(
          'Vector for chunk ${v.chunkId} has ${v.vector.length} dimensions, '
          'expected $dimension',
        );
      }
    }
    await _db.transaction(() async {
      for (final v in vectors) {
        await _db.customInsert(
          'INSERT OR REPLACE INTO chunk_vectors (chunk_id, vector) '
          'VALUES (?, ?)',
          variables: [
            Variable.withInt(v.chunkId),
            Variable.withBlob(_encode(v.vector)),
          ],
        );
      }
    });
    _cache = null;
  }

  @override
  Future<List<VectorHit>> search(List<double> query, {int k = 20}) async {
    if (query.length != dimension) {
      throw ArgumentError(
        'Query has ${query.length} dimensions, expected $dimension',
      );
    }
    if (k <= 0) return const [];
    final cached = _cache;
    final matrix = cached != null && cached.ids.length == await count()
        ? cached
        : _cache = await _load();
    final q = _normalized(query);
    if (q == null) return const [];

    final scores = Float64List(matrix.ids.length);
    for (var row = 0; row < matrix.ids.length; row++) {
      final offset = row * dimension;
      var dot = 0.0;
      for (var i = 0; i < dimension; i++) {
        dot += matrix.values[offset + i] * q[i];
      }
      scores[row] = dot;
    }
    final order = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    return [
      for (final row in order.take(k))
        VectorHit(chunkId: matrix.ids[row], similarity: scores[row]),
    ];
  }

  @override
  Future<void> deleteByDoc(int docId) async {
    await _db.customUpdate(
      'DELETE FROM chunk_vectors WHERE chunk_id IN '
      '(SELECT id FROM chunks WHERE doc_id = ?)',
      variables: [Variable.withInt(docId)],
      updateKind: UpdateKind.delete,
    );
    _cache = null;
  }

  @override
  Future<int> count() async {
    final row = await _db
        .customSelect('SELECT COUNT(*) AS n FROM chunk_vectors')
        .getSingle();
    return row.read<int>('n');
  }

  Future<_Matrix> _load() async {
    final rows = await _db
        .customSelect('SELECT chunk_id, vector FROM chunk_vectors')
        .get();
    final ids = Int64List(rows.length);
    final values = Float32List(rows.length * dimension);
    for (var row = 0; row < rows.length; row++) {
      ids[row] = rows[row].read<int>('chunk_id');
      final vector = _decode(rows[row].read<Uint8List>('vector'));
      values.setRange(row * dimension, (row + 1) * dimension, vector);
    }
    return _Matrix(ids, values);
  }

  /// Unit-length float32 bytes (host byte order, little-endian on Android).
  /// A zero vector is stored as is and scores 0 against everything.
  Uint8List _encode(List<double> vector) {
    final unit = _normalized(vector) ?? Float32List(vector.length);
    return unit.buffer.asUint8List();
  }

  Float32List _decode(Uint8List bytes) {
    if (bytes.length != dimension * 4) {
      throw StateError(
        'Stored vector has ${bytes.length} bytes, expected ${dimension * 4}',
      );
    }
    // Copy: the blob may not be 4-byte aligned for a direct view.
    return Uint8List.fromList(bytes).buffer.asFloat32List();
  }

  /// [vector] scaled to length 1, or null if it is all zeros.
  static Float32List? _normalized(List<double> vector) {
    var sumSquares = 0.0;
    for (final x in vector) {
      sumSquares += x * x;
    }
    if (sumSquares == 0) return null;
    final norm = math.sqrt(sumSquares);
    return Float32List.fromList([for (final x in vector) x / norm]);
  }
}

class _Matrix {
  _Matrix(this.ids, this.values);

  final Int64List ids;

  /// Row-major: row i is `values[i * dimension, (i + 1) * dimension)`.
  final Float32List values;
}
