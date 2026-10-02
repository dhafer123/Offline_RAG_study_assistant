import 'package:flutter/material.dart';
import 'package:offline_study_assistant/app/branding.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_avatar.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';

/// A short animated splash over the first screen: Lumi pops in, then the
/// app's name and tagline, then everything fades into the app.
///
/// The app underneath starts at once (the model check runs meanwhile); the
/// splash only covers it. A tap skips it, and it's skipped entirely when the
/// phone's "remove animations" setting is on.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({required this.child, super.key});

  final Widget child;

  static const duration = Duration(milliseconds: 2000);

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _done = false;
  bool _started = false;

  // Phases of the 2 s timeline.
  late final CurvedAnimation _bot;
  late final CurvedAnimation _name;
  late final CurvedAnimation _tagline;
  late final CurvedAnimation _fadeOut;

  @override
  void initState() {
    super.initState();
    // Created here, not lazily: dispose() must not be the first to touch them.
    _controller = AnimationController(
      vsync: this,
      duration: SplashOverlay.duration,
    );
    CurvedAnimation phase(double begin, double end, Curve curve) =>
        CurvedAnimation(
          parent: _controller,
          curve: Interval(begin, end, curve: curve),
        );
    _bot = phase(0, 0.35, Curves.elasticOut);
    _name = phase(0.2, 0.5, Curves.easeOutCubic);
    _tagline = phase(0.35, 0.65, Curves.easeOutCubic);
    _fadeOut = phase(0.8, 1, Curves.easeIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _done = true;
      return;
    }
    _controller.forward().whenCompleteOrCancel(_finish);
  }

  void _finish() {
    if (mounted && !_done) setState(() => _done = true);
  }

  @override
  void dispose() {
    for (final phase in [_bot, _name, _tagline, _fadeOut]) {
      phase.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // The child keeps its place in the Stack after the splash, so the app's
    // state survives the splash going away.
    return Stack(
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _finish,
              child: FadeTransition(
                opacity: ReverseAnimation(_fadeOut),
                child: Material(
                  color: scheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.4,
                            end: 1,
                          ).animate(_bot),
                          child: const BotAvatar(
                            mood: BotMood.happy,
                            size: 152,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SlideIn(
                          animation: _name,
                          child: Text(
                            Branding.appName,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _SlideIn(
                          animation: _tagline,
                          child: Text(
                            Branding.tagline,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fades in while rising a few pixels.
class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
