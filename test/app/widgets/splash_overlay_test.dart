import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/widgets/splash_overlay.dart';

/// Counts its builds, to check the app underneath isn't rebuilt from scratch.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  static int created = 0;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) => const Text('app');
}

void main() {
  Future<void> pumpSplash(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    _CounterState.created = 0;
    // MaterialApp reads the setting from the platform.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SplashOverlay(child: child!),
        home: const _Counter(),
      ),
    );
  }

  testWidgets('shows the name and tagline, then reveals the app', (
    tester,
  ) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.text('PageWise'), findsOne);
    expect(find.text('Your offline study assistant'), findsOne);

    await tester.pumpAndSettle();

    expect(find.text('PageWise'), findsNothing);
    expect(find.text('app'), findsOne);
    // The app underneath was built once, not again when the splash left.
    expect(_CounterState.created, 1);
  });

  testWidgets('a tap skips it', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(SplashOverlay));
    await tester.pump();

    expect(find.text('PageWise'), findsNothing);
    expect(find.text('app'), findsOne);
  });

  testWidgets('is skipped when animations are turned off', (tester) async {
    await pumpSplash(tester, disableAnimations: true);

    expect(find.text('PageWise'), findsNothing);
    expect(find.text('app'), findsOne);
  });
}
