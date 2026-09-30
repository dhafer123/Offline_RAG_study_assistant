import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/perf.dart';

/// One benchmark run: a fresh model load, then one full answer.
@immutable
class LlmBenchmarkRun {
  const LlmBenchmarkRun({
    required this.loadTime,
    required this.generation,
    required this.answer,
  });

  final Duration loadTime;
  final GenerationMetrics generation;

  /// The full streamed answer, to compare models on quality too.
  final String answer;

  @override
  String toString() => 'load=${loadTime.inMilliseconds}ms $generation';
}

@immutable
class LlmBenchmarkResult {
  const LlmBenchmarkResult({required this.runs, this.peakRssBytes});

  final List<LlmBenchmarkRun> runs;

  /// Peak resident memory of the whole app process (Dart + native), from
  /// `getrusage`. A cross-check for the Android Studio profiler.
  final int? peakRssBytes;

  /// The first load of the session: includes runtime init and a cold file
  /// cache, so it's slower than the median.
  double get coldLoadSeconds => runs.first.loadTime.inMicroseconds / 1e6;

  double get medianLoadSeconds =>
      Perf.median(runs.map((r) => r.loadTime.inMicroseconds)) / 1e6;

  double get medianTimeToFirstTokenSeconds =>
      Perf.median(
        runs.map((r) => r.generation.timeToFirstToken.inMicroseconds),
      ) /
      1e6;

  /// Median over the runs that produced at least two tokens.
  double? get medianTokensPerSecond {
    final rates = runs.map((r) => r.generation.tokensPerSecond).nonNulls;
    return rates.isEmpty ? null : Perf.median(rates);
  }

  double get medianOutputTokens =>
      Perf.median(runs.map((r) => r.generation.outputTokens));

  int? get promptTokens => runs.first.generation.promptTokens;

  int? get peakRssMb =>
      peakRssBytes == null ? null : (peakRssBytes! / (1024 * 1024)).round();

  String summary() =>
      'runs=${runs.length} '
      'load=${medianLoadSeconds.toStringAsFixed(2)}s '
      '(cold ${coldLoadSeconds.toStringAsFixed(2)}s) '
      'ttft=${medianTimeToFirstTokenSeconds.toStringAsFixed(2)}s '
      'tok/s=${medianTokensPerSecond?.toStringAsFixed(2) ?? 'n/a'} '
      'outTokens=${medianOutputTokens.toStringAsFixed(0)} '
      'promptTokens=${promptTokens ?? '?'} '
      'peakRss=${peakRssMb ?? '?'}MB';
}

/// Measures load time, time to first token and decode speed of an
/// [LlmEngine], unloading and reloading the model before every run.
class LlmBenchmark {
  LlmBenchmark(
    this._engine, {
    StopwatchFactory stopwatch = Stopwatch.new,
    int? Function()? peakRssBytes,
  }) : _stopwatch = stopwatch,
       _peakRssBytes = peakRssBytes ?? _processMaxRss;

  final LlmEngine _engine;
  final StopwatchFactory _stopwatch;
  final int? Function() _peakRssBytes;

  /// A RAG-shaped prompt: one short source passage and a question about it.
  static const prompt =
      'Answer the question using only the source below. '
      'Cite the source as [1].\n\n'
      '[1] Photosynthesis takes place in the chloroplasts of plant cells. '
      'In the light-dependent reactions, which happen in the thylakoid '
      'membranes, chlorophyll absorbs light energy and uses it to split water '
      'molecules. This releases oxygen as a by-product and produces ATP and '
      'NADPH. In the Calvin cycle, which happens in the stroma, the enzyme '
      'RuBisCO fixes carbon dioxide from the air into organic molecules. ATP '
      'and NADPH from the first stage provide the energy and electrons needed '
      'to turn these molecules into glucose. The rate of photosynthesis '
      'depends on light intensity, carbon dioxide concentration and '
      'temperature; when one of them is in short supply it becomes the '
      'limiting factor.\n\n'
      'Question: What are the two stages of photosynthesis, where does each '
      'one happen, and what does each one produce?';

  /// Runs the benchmark [runs] times. [onRun] is called after every run.
  /// [label] (e.g. the model name) prefixes the log lines.
  /// When [isCancelled] returns true, stops before the next run and returns
  /// the runs so far (throws [StateError] if there are none).
  ///
  /// Throws [LlmException] if a load or a generation fails.
  Future<LlmBenchmarkResult> run({
    String prompt = LlmBenchmark.prompt,
    int runs = 10,
    void Function(int index, LlmBenchmarkRun run)? onRun,
    bool Function()? isCancelled,
    String label = 'llm',
  }) async {
    final results = <LlmBenchmarkRun>[];
    for (var i = 0; i < runs; i++) {
      if (isCancelled?.call() ?? false) break;
      final result = await _runOnce(prompt);
      results.add(result);
      Perf.log('$label run ${i + 1}/$runs: $result');
      if (i == 0) Perf.log('$label answer: ${jsonEncode(result.answer)}');
      onRun?.call(i, result);
    }
    if (results.isEmpty) throw StateError('Benchmark cancelled before a run');

    final result = LlmBenchmarkResult(
      runs: List.unmodifiable(results),
      peakRssBytes: _peakRssBytes(),
    );
    Perf.log('$label benchmark: ${result.summary()}');
    return result;
  }

  Future<LlmBenchmarkRun> _runOnce(String prompt) async {
    await _engine.unload();
    final (_, loadTime) = await Perf.time(
      _engine.load,
      stopwatch: _stopwatch,
    );

    final timer = GenerationTimer(stopwatch: _stopwatch)..start();
    final answer = StringBuffer();
    await for (final chunk in _engine.generate(prompt)) {
      timer.onChunk();
      answer.write(chunk);
    }
    final usage = _engine.lastUsage;
    final generation = timer.finish(
      outputTokens: usage?.outputTokens,
      promptTokens: usage?.promptTokens,
    );
    return LlmBenchmarkRun(
      loadTime: loadTime,
      generation: generation,
      answer: answer.toString(),
    );
  }

  static int? _processMaxRss() {
    try {
      return ProcessInfo.maxRss;
    } on Object {
      return null;
    }
  }
}
