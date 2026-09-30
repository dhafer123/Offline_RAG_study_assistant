import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/perf.dart';

import '../helpers/fake_stopwatch.dart';

void main() {
  group('Perf.median', () {
    test('odd count returns the middle value', () {
      expect(Perf.median([5, 1, 3]), 3);
    });

    test('even count averages the two middle values', () {
      expect(Perf.median([4, 1, 3, 2]), 2.5);
    });

    test('single value', () {
      expect(Perf.median([7]), 7);
    });

    test('empty throws', () {
      expect(() => Perf.median(<num>[]), throwsArgumentError);
    });
  });

  group('Perf.time', () {
    test('returns the result and the elapsed time', () async {
      final sw = FakeStopwatch();

      final (result, elapsed) = await Perf.time(() async {
        sw.advance(const Duration(milliseconds: 1500));
        return 42;
      }, stopwatch: () => sw);

      expect(result, 42);
      expect(elapsed, const Duration(milliseconds: 1500));
      expect(sw.isRunning, isFalse);
    });
  });

  group('GenerationTimer', () {
    test('measures time to first token and decode speed', () {
      final sw = FakeStopwatch();
      final timer = GenerationTimer(stopwatch: () => sw)..start();

      sw.advance(const Duration(seconds: 2));
      timer.onChunk();
      for (var i = 0; i < 10; i++) {
        sw.advance(const Duration(milliseconds: 100));
        timer.onChunk();
      }
      final metrics = timer.finish();

      expect(metrics.timeToFirstToken, const Duration(seconds: 2));
      expect(metrics.total, const Duration(seconds: 3));
      expect(metrics.outputTokens, 11);
      // 10 tokens after the first, in 1 s.
      expect(metrics.tokensPerSecond, closeTo(10, 1e-9));
    });

    test('uses reported token counts over the chunk count', () {
      final sw = FakeStopwatch();
      final timer = GenerationTimer(stopwatch: () => sw)..start();

      sw.advance(const Duration(seconds: 1));
      timer.onChunk();
      sw.advance(const Duration(seconds: 2));
      timer.onChunk();
      final metrics = timer.finish(outputTokens: 21, promptTokens: 150);

      expect(metrics.outputTokens, 21);
      expect(metrics.promptTokens, 150);
      expect(metrics.tokensPerSecond, closeTo(10, 1e-9));
    });

    test('no chunks: time to first token is the total, no speed', () {
      final sw = FakeStopwatch();
      final timer = GenerationTimer(stopwatch: () => sw)..start();

      sw.advance(const Duration(seconds: 1));
      final metrics = timer.finish();

      expect(metrics.timeToFirstToken, const Duration(seconds: 1));
      expect(metrics.outputTokens, 0);
      expect(metrics.tokensPerSecond, isNull);
    });

    test('a single token has no decode speed', () {
      final sw = FakeStopwatch();
      final timer = GenerationTimer(stopwatch: () => sw)..start();

      sw.advance(const Duration(seconds: 1));
      timer.onChunk();
      expect(timer.finish().tokensPerSecond, isNull);
    });
  });
}
