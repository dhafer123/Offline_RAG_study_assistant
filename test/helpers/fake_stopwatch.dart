/// [Stopwatch] whose time only moves when a test calls [advance].
class FakeStopwatch implements Stopwatch {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  void advance(Duration by) {
    if (_running) _elapsed += by;
  }

  @override
  Duration get elapsed => _elapsed;

  @override
  int get elapsedMicroseconds => _elapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => _elapsed.inMilliseconds;

  @override
  int get elapsedTicks => _elapsed.inMicroseconds;

  @override
  int get frequency => Duration.microsecondsPerSecond;

  @override
  bool get isRunning => _running;

  @override
  void reset() => _elapsed = Duration.zero;

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;
}
