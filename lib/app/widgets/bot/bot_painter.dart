import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';

/// Colors of the bot, picked from the reference art (`design/`).
abstract final class BotColors {
  static const helmet = Color(0xFFE2E9F4);
  static const helmetLight = Color(0xFFEAEFF7);
  static const helmetShade = Color(0xFFC4CFE2);
  static const visor = Color(0xFF13213F);
  static const visorTop = Color(0xFF1C2D52);
  static const eye = Color(0xFF45E7F4);
  static const ear = Color(0xFF3B76F4);
  static const earShade = Color(0xFF2F5FD0);
  static const stem = Color(0xFF1F3054);
  static const neck = Color(0xFF314779);
}

/// Draws the bot on a 100 x 100 grid, scaled to fit the canvas.
///
/// [loop] (0 to 1, repeating) drives the mood's animation, [blink] (0 open,
/// 1 closed) closes the eyes, [pop] (0 to 1, once) is a small bounce when the
/// mood changes. With [showBody] false only the head is drawn, larger.
class BotPainter extends CustomPainter {
  BotPainter({
    required this.mood,
    required this.loop,
    required this.blink,
    required this.pop,
    this.showBody = true,
  }) : super(repaint: Listenable.merge([loop, blink, pop]));

  final BotMood mood;
  final Animation<double> loop;
  final Animation<double> blink;
  final Animation<double> pop;
  final bool showBody;

  // The part of the grid that is drawn.
  static const _full = Rect.fromLTRB(5, 5, 95, 95);
  static const _head = Rect.fromLTRB(12, 6, 88, 82);

  static const _leftEye = 40.5;
  static const _rightEye = 59.5;
  static const _eyeY = 51.0;

  @override
  void paint(Canvas canvas, Size size) {
    final view = showBody ? _full : _head;
    final scale = math.min(size.width, size.height) / view.width;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale * (1 + 0.07 * math.sin(math.pi * pop.value)))
      ..translate(-view.center.dx, -view.center.dy);

    if (showBody) _body(canvas);
    // The confused head tilts; everything above the neck turns with it.
    if (mood == BotMood.confused) {
      canvas
        ..translate(50, 50)
        ..rotate(-0.12)
        ..translate(-50, -50);
    }
    _antenna(canvas);
    _ears(canvas);
    _helmet(canvas);
    _visor(canvas);
    _face(canvas);
    canvas.restore();
  }

  void _body(Canvas canvas) {
    final shoulders = Path()
      ..moveTo(24, 89)
      ..cubicTo(24, 80, 36, 74.5, 50, 74.5)
      ..cubicTo(64, 74.5, 76, 80, 76, 89)
      ..close();
    canvas
      ..drawPath(shoulders, Paint()..color = BotColors.helmet)
      ..drawRRect(
        RRect.fromLTRBR(39, 69, 61, 80, const Radius.circular(7)),
        Paint()..color = BotColors.neck,
      );
  }

  void _antenna(Canvas canvas) {
    final thinking = mood == BotMood.thinking;
    final pulse = thinking ? (1 + math.sin(2 * math.pi * loop.value)) / 2 : 0;
    canvas.drawPath(
      Path()
        ..moveTo(48.6, 25)
        ..lineTo(49.2, 18.5)
        ..lineTo(50.8, 18.5)
        ..lineTo(51.4, 25)
        ..close(),
      Paint()..color = BotColors.stem,
    );
    const ball = Offset(50, 14.5);
    _glow(canvas, ball, 6.5 + 4 * pulse, 0.35 + 0.35 * pulse);
    canvas.drawCircle(ball, 4.4, Paint()..color = BotColors.eye);
  }

  void _ears(Canvas canvas) {
    for (final x in [20.5, 79.5]) {
      final ear = Rect.fromCenter(center: Offset(x, 52), width: 11, height: 21);
      canvas
        ..drawOval(ear, Paint()..color = BotColors.ear)
        ..drawOval(
          ear.translate(x < 50 ? 0.8 : -0.8, 1.5).deflate(1.5),
          Paint()..color = BotColors.earShade.withValues(alpha: 0.35),
        );
    }
  }

  void _helmet(Canvas canvas) {
    const shape = Rect.fromLTRB(21.5, 24, 78.5, 73);
    canvas
      ..drawRRect(
        RRect.fromRectXY(shape, 27, 24),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              BotColors.helmetLight,
              BotColors.helmet,
              BotColors.helmetShade,
            ],
            stops: [0, 0.7, 1],
          ).createShader(shape),
      )
      // Shine on the top left.
      ..save()
      ..translate(35, 29.5)
      ..rotate(-0.35)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: 10, height: 4),
        Paint()..color = const Color(0xCCFFFFFF),
      )
      ..restore();
  }

  void _visor(Canvas canvas) {
    const shape = Rect.fromLTRB(25.5, 34, 74.5, 68.5);
    canvas
      ..drawRRect(
        RRect.fromRectXY(shape, 17, 15),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BotColors.visorTop, BotColors.visor],
          ).createShader(shape),
      )
      // Glass reflection along the top left edge.
      ..drawPath(
        Path()
          ..moveTo(30, 50)
          ..quadraticBezierTo(29.5, 38, 46, 37.2)
          ..quadraticBezierTo(33, 40, 31.5, 50.5)
          ..close(),
        Paint()..color = const Color(0x24FFFFFF),
      );
  }

  void _face(Canvas canvas) {
    final t = loop.value;
    switch (mood) {
      case BotMood.idle:
        _barEyes(canvas, blink: blink.value);
      case BotMood.happy:
        for (final x in [_leftEye, _rightEye]) {
          _stroke(
            canvas,
            Path()
              ..moveTo(x - 4.2, _eyeY + 2)
              ..quadraticBezierTo(x, _eyeY - 6, x + 4.2, _eyeY + 2),
          );
        }
        _stroke(
          canvas,
          Path()
            ..moveTo(45.5, 59.5)
            ..quadraticBezierTo(50, 64, 54.5, 59.5),
        );
      case BotMood.thinking:
        // Pupils looking up, drifting slowly from side to side.
        final drift = Offset(1.3 * math.sin(2 * math.pi * t), -2.2);
        for (final x in [_leftEye, _rightEye]) {
          final center = Offset(x, _eyeY);
          _glow(canvas, center, 9, 0.35);
          canvas
            ..drawCircle(center, 5.3, Paint()..color = BotColors.eye)
            ..drawCircle(center + drift, 2.4, Paint()..color = BotColors.visor);
        }
      case BotMood.reading:
        // Left to right along a line, then a quick return.
        final p = t < 0.85 ? t / 0.85 : 1 - (t - 0.85) / 0.15;
        _barEyes(
          canvas,
          height: 8,
          look: Offset(-3 + 6 * p, 3),
          blink: blink.value,
        );
      case BotMood.searching:
        _barEyes(
          canvas,
          look: Offset(
            3.5 * math.sin(2 * math.pi * t),
            -1.2 * math.cos(4 * math.pi * t),
          ),
          blink: blink.value,
        );
      case BotMood.talking:
        _barEyes(canvas, height: 10.5, look: const Offset(0, -1.5));
        final open = math.sin(math.pi * t).abs();
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(50, 61.5),
              width: 6.5 - 1.5 * open,
              height: 1.6 + 3.2 * open,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = BotColors.eye,
        );
      case BotMood.confused:
        _barEyes(canvas, width: 7, height: 10.5, only: _leftEye);
        _stroke(
          canvas,
          Path()
            ..moveTo(_rightEye - 4, _eyeY + 1.5)
            ..lineTo(_rightEye + 4, _eyeY - 2),
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(46.5, 61.5)
            ..quadraticBezierTo(50, 59, 53.5, 60.5),
        );
      case BotMood.sad:
        for (final (x, side) in [(_leftEye, -1.0), (_rightEye, 1.0)]) {
          _stroke(
            canvas,
            Path()
              ..moveTo(x + 4.3 * side, _eyeY + 2.5)
              ..quadraticBezierTo(x, _eyeY - 4.5, x - 4.3 * side, _eyeY),
          );
        }
        _stroke(
          canvas,
          Path()
            ..moveTo(45.5, 62.5)
            ..quadraticBezierTo(50, 58, 54.5, 62.5),
        );
      case BotMood.surprised:
        for (final x in [_leftEye, _rightEye]) {
          _glow(canvas, Offset(x, _eyeY), 9, 0.3);
          canvas.drawCircle(
            Offset(x, _eyeY),
            4.4,
            Paint()
              ..color = BotColors.eye
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.3,
          );
        }
        canvas.drawCircle(
          const Offset(50, 61.5),
          1.9,
          Paint()..color = BotColors.eye,
        );
    }
  }

  /// The default eyes: rounded bars, with a soft glow.
  void _barEyes(
    Canvas canvas, {
    double width = 7.5,
    double height = 12,
    Offset look = Offset.zero,
    double blink = 0,
    double? only,
  }) {
    final h = math.max(1.8, height * (1 - blink));
    for (final x in only != null ? [only] : [_leftEye, _rightEye]) {
      final center = Offset(x, _eyeY) + look;
      _glow(canvas, center, 9, 0.35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: width, height: h),
          Radius.circular(math.min(width, h) / 2),
        ),
        Paint()..color = BotColors.eye,
      );
    }
  }

  void _stroke(Canvas canvas, Path path) => canvas.drawPath(
    path,
    Paint()
      ..color = BotColors.eye
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  /// A soft cyan halo. A radial gradient, not a blur: cheap to repaint every
  /// frame while the model is running on the CPU.
  void _glow(Canvas canvas, Offset center, double radius, double opacity) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            BotColors.eye.withValues(alpha: opacity),
            BotColors.eye.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(BotPainter old) =>
      old.mood != mood || old.showBody != showBody;
}
