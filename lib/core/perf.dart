import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Creates the stopwatch used for a measurement. Tests pass a fake one.
typedef StopwatchFactory = Stopwatch Function();

/// Small timing helpers shared by services and the benchmark screen.
abstract final class Perf {
  /// Runs [action] and returns its result with the elapsed wall-clock time.
  static Future<(T, Duration)> time<T>(
    Future<T> Function() action, {
    StopwatchFactory stopwatch = Stopwatch.new,
  }) async {
    final sw = stopwatch()..start();
    final result = await action();
    sw.stop();
    return (result, sw.elapsed);
  }

  /// Median of [values]. Throws [ArgumentError] when empty.
  static double median(Iterable<num> values) {
    if (values.isEmpty) throw ArgumentError('median of an empty list');
    final sorted = values.map((v) => v.toDouble()).toList()..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Prints a `[perf]` line, visible in `adb logcat` in release builds too.
  static void log(String message) => debugPrint('[perf] $message');
}

/// Timing of one streamed generation, measured from the app's side.
@immutable
class GenerationMetrics {
  const GenerationMetrics({
    required this.timeToFirstToken,
    required this.total,
    required this.outputTokens,
    this.promptTokens,
  });

  /// From the `generate()` call to the first streamed chunk (prefill).
  final Duration timeToFirstToken;

  /// From the `generate()` call to the end of the stream.
  final Duration total;

  final int outputTokens;
  final int? promptTokens;

  Duration get decodeTime => total - timeToFirstToken;

  /// Decode speed: tokens after the first, divided by the time after the first.
  /// Null when there's nothing to divide (fewer than two tokens).
  double? get tokensPerSecond {
    final micros = decodeTime.inMicroseconds;
    if (outputTokens < 2 || micros <= 0) return null;
    return (outputTokens - 1) * Duration.microsecondsPerSecond / micros;
  }

  @override
  String toString() =>
      'ttft=${timeToFirstToken.inMilliseconds}ms '
      'total=${total.inMilliseconds}ms '
      'tokens=$outputTokens (prompt=${promptTokens ?? '?'}) '
      'tok/s=${tokensPerSecond?.toStringAsFixed(2) ?? 'n/a'}';
}

/// Records time to first token and total time while a stream is consumed.
///
/// Call [start] right before `generate()`, [onChunk] for every chunk and
/// [finish] when the stream is done.
class GenerationTimer {
  GenerationTimer({StopwatchFactory stopwatch = Stopwatch.new})
    : _sw = stopwatch();

  final Stopwatch _sw;
  Duration? _firstChunk;
  int _chunks = 0;

  int get chunks => _chunks;

  void start() => _sw.start();

  void onChunk() {
    _firstChunk ??= _sw.elapsed;
    _chunks++;
  }

  /// Stops the timer. [outputTokens] overrides the chunk count when the
  /// runtime reports real token counts (chunks can hold several tokens).
  GenerationMetrics finish({int? outputTokens, int? promptTokens}) {
    _sw.stop();
    final total = _sw.elapsed;
    return GenerationMetrics(
      timeToFirstToken: _firstChunk ?? total,
      total: total,
      outputTokens: outputTokens ?? _chunks,
      promptTokens: promptTokens,
    );
  }
}

/// Build and raster times of rendered frames, to check the UI stays smooth.
class FrameStats {
  /// Frame budget at 60 Hz. A frame whose build or raster phase takes longer
  /// is counted as janky (Flutter DevTools' definition).
  static const budget = Duration(microseconds: 16667);

  final _build = <int>[];
  final _raster = <int>[];

  int get count => _build.length;

  void add({required Duration build, required Duration raster}) {
    _build.add(build.inMicroseconds);
    _raster.add(raster.inMicroseconds);
  }

  /// Frames whose build or raster phase went over [budget].
  int get janky {
    var n = 0;
    for (var i = 0; i < count; i++) {
      if (_build[i] > budget.inMicroseconds ||
          _raster[i] > budget.inMicroseconds) {
        n++;
      }
    }
    return n;
  }

  /// [p]-th percentile (0–100) of build times, nearest rank.
  Duration buildPercentile(double p) => _percentile(_build, p);

  /// [p]-th percentile (0–100) of raster times, nearest rank.
  Duration rasterPercentile(double p) => _percentile(_raster, p);

  static Duration _percentile(List<int> micros, double p) {
    if (micros.isEmpty) return Duration.zero;
    final sorted = [...micros]..sort();
    final rank = ((p / 100) * sorted.length).ceil().clamp(1, sorted.length);
    return Duration(microseconds: sorted[rank - 1]);
  }

  @override
  String toString() {
    String ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);
    return 'frames=$count janky=$janky '
        'build p50/p90/p99/max=${ms(buildPercentile(50))}/'
        '${ms(buildPercentile(90))}/${ms(buildPercentile(99))}/'
        '${ms(buildPercentile(100))}ms '
        'raster p50/p90/p99/max=${ms(rasterPercentile(50))}/'
        '${ms(rasterPercentile(90))}/${ms(rasterPercentile(99))}/'
        '${ms(rasterPercentile(100))}ms';
  }
}

/// Collects [FrameStats] between [start] and [stop].
abstract interface class FrameMonitor {
  void start();

  /// Stops collecting and returns what was rendered since [start].
  FrameStats stop();
}

/// [FrameMonitor] fed by the engine's frame timings. They arrive in batches
/// (about once a second in release builds), so the last second before [stop]
/// may be missing.
class SchedulerFrameMonitor implements FrameMonitor {
  FrameStats? _stats;

  @override
  void start() {
    if (_stats != null) return;
    _stats = FrameStats();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  FrameStats stop() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final stats = _stats ?? FrameStats();
    _stats = null;
    return stats;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _stats?.add(build: t.buildDuration, raster: t.rasterDuration);
    }
  }
}
