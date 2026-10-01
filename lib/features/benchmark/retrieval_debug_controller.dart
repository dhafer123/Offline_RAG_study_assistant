import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/embedder.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/core/perf.dart';
import 'package:offline_study_assistant/features/chat/answer_service.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';
import 'package:offline_study_assistant/features/library/ingestion_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'retrieval_debug_controller.g.dart';

enum RetrievalDebugStatus { idle, indexing, searching, answering, error }

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
    this.answer = '',
    this.answerInfo = '',
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

  /// Embedding the question plus the search.
  final Duration? searchTime;

  /// The streamed answer, or the gate's "not found" message.
  final String answer;

  /// Gate decision and timings of the last answer.
  final String answerInfo;
  final String? errorMessage;

  bool get isBusy =>
      status == RetrievalDebugStatus.indexing ||
      status == RetrievalDebugStatus.searching ||
      status == RetrievalDebugStatus.answering;

  RetrievalDebugState copyWith({
    RetrievalDebugStatus? status,
    List<String>? files,
    List<Document>? documents,
    int? vectorCount,
    IngestionProgress? progress,
    IngestionResult? lastIngestion,
    List<RetrievedChunk>? results,
    Duration? searchTime,
    String? answer,
    String? answerInfo,
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
      answer: answer ?? this.answer,
      answerInfo: answerInfo ?? this.answerInfo,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Indexes PDFs pushed to the pdfs folder, runs vector searches (task 2.5)
/// and answers questions through `AnswerService` (task 3.3, until the chat
/// screen).
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
    state = state.copyWith(
      status: RetrievalDebugStatus.searching,
      answer: '',
      answerInfo: '',
    );
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

  /// Answers [question]: the gate's verdict, the sources, then the streamed
  /// answer.
  Future<void> answer(String question) async {
    if (state.isBusy || question.trim().isEmpty) return;
    state = state.copyWith(
      status: RetrievalDebugStatus.answering,
      results: const [],
      answer: '',
      answerInfo: 'Retrieving…',
    );
    try {
      await for (final event
          in ref.read(answerServiceProvider).answer(question)) {
        if (!ref.mounted) return;
        state = switch (event) {
          AnswerNotFound(
            :final message,
            :final bestSimilarity,
            :final retrievalTime,
          ) =>
            state.copyWith(
              answer: message,
              answerInfo:
                  'Gate: best similarity '
                  '${bestSimilarity?.toStringAsFixed(3) ?? 'none'} < '
                  '${ref.read(answerConfigProvider).similarityThreshold}, '
                  'LLM not called · retrieval '
                  '${retrievalTime.inMilliseconds} ms',
            ),
          AnswerSources(
            :final prompt,
            :final bestSimilarity,
            :final retrievalTime,
          ) =>
            state.copyWith(
              results: prompt.sources,
              answerInfo:
                  'Gate passed (best ${bestSimilarity.toStringAsFixed(3)}) · '
                  'retrieval ${retrievalTime.inMilliseconds} ms · '
                  '${prompt.sources.length} sources, '
                  '~${prompt.estimatedTokens} prompt tokens · generating…',
            ),
          AnswerLoadingModel() => state.copyWith(
            answerInfo: '${state.answerInfo} (loading model)',
          ),
          AnswerGenerating() => state,
          AnswerToken(:final text) => state.copyWith(
            answer: state.answer + text,
          ),
          AnswerDone(:final modelLoadTime, :final generation) => state.copyWith(
            answerInfo:
                '${state.answerInfo.replaceAll(' · generating…', '')} · '
                'load ${modelLoadTime.inMilliseconds} ms · $generation',
          ),
        };
      }
      if (ref.mounted) {
        state = state.copyWith(status: RetrievalDebugStatus.idle);
      }
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
      AnswerException(:final message, :final cause) =>
        cause == null ? message : '$message ($cause)',
      _ => '$error',
    },
  );
}
