import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'retrieval_debug_controller.g.dart';

enum RetrievalDebugStatus { idle, indexing, searching, error }

@immutable
class RetrievalDebugState {
  const RetrievalDebugState({
    this.status = RetrievalDebugStatus.idle,
    this.files = const [],
    this.documents = const [],
    this.vectorCount = 0,
    this.progress,
    this.lastIngestion,
    this.results = const [],
    this.searchTime,
    this.errorMessage,
  });

  final RetrievalDebugStatus status;

  /// PDFs found in the pdfs folder (absolute paths).
  final List<String> files;
  final List<Document> documents;
  final int vectorCount;
  final IngestionProgress? progress;
  final IngestionResult? lastIngestion;
  final List<RetrievedChunk> results;

  /// Embedding the question plus the vector search.
  final Duration? searchTime;
  final String? errorMessage;

  bool get isBusy =>
      status == RetrievalDebugStatus.indexing ||
      status == RetrievalDebugStatus.searching;

  RetrievalDebugState copyWith({
    RetrievalDebugStatus? status,
    List<String>? files,
    List<Document>? documents,
    int? vectorCount,
    IngestionProgress? progress,
    IngestionResult? lastIngestion,
    List<RetrievedChunk>? results,
    Duration? searchTime,
    String? errorMessage,
  }) {
    return RetrievalDebugState(
      status: status ?? this.status,
      files: files ?? this.files,
      documents: documents ?? this.documents,
      vectorCount: vectorCount ?? this.vectorCount,
      progress: progress ?? this.progress,
      lastIngestion: lastIngestion ?? this.lastIngestion,
      results: results ?? this.results,
      searchTime: searchTime ?? this.searchTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Indexes PDFs pushed to the pdfs folder and runs vector searches (task 2.5).
@riverpod
class RetrievalDebugController extends _$RetrievalDebugController {
  @override
  RetrievalDebugState build() => const RetrievalDebugState();

  /// Reloads the PDF files, the indexed documents and the vector count.
  Future<void> refresh() async {
    final dir = Directory(ref.read(pdfsDirectoryProvider));
    final files = dir.existsSync()
        ? (dir
              .listSync()
              .whereType<File>()
              .map((f) => f.path)
              .where((p) => p.toLowerCase().endsWith('.pdf'))
              .toList()
            ..sort())
        : <String>[];
    final documents = await ref.read(documentStoreProvider).listDocuments();
    final vectorCount = await ref.read(vectorIndexProvider).count();
    if (!ref.mounted) return;
    state = state.copyWith(
      files: files,
      documents: documents,
      vectorCount: vectorCount,
    );
  }

  Future<void> index(String path) async {
    if (state.isBusy) return;
    state = RetrievalDebugState(
      status: RetrievalDebugStatus.indexing,
      files: state.files,
      documents: state.documents,
      vectorCount: state.vectorCount,
    );
    try {
      final result = await ref
          .read(ingestionServiceProvider)
          .ingest(
            path,
            title: path.split(RegExp(r'[/\\]')).last,
            onProgress: (p) {
              if (ref.mounted) state = state.copyWith(progress: p);
            },
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        status: RetrievalDebugStatus.idle,
        lastIngestion: result,
      );
    } on Object catch (e) {
      if (ref.mounted) state = _failed(e);
    }
    if (ref.mounted) await refresh();
  }

  Future<void> search(String question) async {
    if (state.isBusy || question.trim().isEmpty) return;
    state = state.copyWith(status: RetrievalDebugStatus.searching);
    try {
      final (results, time) = await Perf.time(
        () => ref.read(retrievalServiceProvider).retrieve(question),
      );
      Perf.log('search "$question": ${time.inMilliseconds}ms');
      if (!ref.mounted) return;
      state = state.copyWith(
        status: RetrievalDebugStatus.idle,
        results: results,
        searchTime: time,
      );
    } on Object catch (e) {
      if (ref.mounted) state = _failed(e);
    }
  }

  RetrievalDebugState _failed(Object error) => state.copyWith(
    status: RetrievalDebugStatus.error,
    errorMessage: switch (error) {
      IngestionException(:final message, :final cause) =>
        cause == null ? message : '$message: $cause',
      EmbedderException(:final message) => message,
      _ => '$error',
    },
  );
}
