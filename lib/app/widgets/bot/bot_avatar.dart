import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_painter.dart';

/// The assistant bot, animated for its [mood].
///
/// Only animates while it has something to show: a looping mood, a blink
/// every few seconds, a short bounce when the mood changes. Still when the
/// phone's "remove animations" setting is on.
class BotAvatar extends StatefulWidget {
  const BotAvatar({
    required this.mood,
    this.size = 64,
    this.showBody = true,
    super.key,
  });

  final BotMood mood;
  final double size;

  /// False draws the head only, for small avatars.
  final bool showBody;

  @override
  State<BotAvatar> createState() => _BotAvatarState();
}

class _BotAvatarState extends State<BotAvatar> with TickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this);
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  final _random = math.Random();
  Timer? _nextBlink;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(BotAvatar old) {
    super.didUpdateWidget(old);
    if (old.mood == widget.mood) return;
    if (!_still) unawaited(_pop.forward(from: 0));
    _sync();
  }

  /// Starts or stops the animations the current mood needs.
  void _sync() {
    final loop = widget.mood.loop;
    if (_still || loop == null) {
      _loop
        ..stop()
        // A still pose that reads well for every mood.
        ..value = 0.25;
    } else if (_loop.duration != loop || !_loop.isAnimating) {
      _loop.duration = loop;
      unawaited(_loop.repeat());
    }

    _nextBlink?.cancel();
    _nextBlink = null;
    if (_still || !widget.mood.blinks) {
      _blink.value = 0;
    } else {
      _scheduleBlink();
    }
  }

  void _scheduleBlink() {
    final wait = Duration(milliseconds: 2500 + _random.nextInt(3500));
    _nextBlink = Timer(wait, () async {
      if (!mounted) return;
      await _blink.forward(from: 0);
      if (!mounted) return;
      await _blink.reverse();
      if (mounted && widget.mood.blinks && !_still) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _nextBlink?.cancel();
    _loop.dispose();
    _blink.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.mood.label,
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: BotPainter(
            mood: widget.mood,
            loop: _loop,
            blink: _blink,
            pop: _pop,
            showBody: widget.showBody,
          ),
        ),
      ),
    );
  }
}
