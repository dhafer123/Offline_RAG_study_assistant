import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/theme.dart';

/// WCAG contrast ratio between two opaque colors (1 to 21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('$name theme', () {
      final s = theme.colorScheme;

      // Text on every surface the screens use, and on filled components:
      // WCAG AA for body text (4.5:1).
      final pairs = {
        'onSurface / surface': (s.onSurface, s.surface),
        'onSurface / surfaceContainerHigh': (
          s.onSurface,
          s.surfaceContainerHigh,
        ),
        'onSurfaceVariant / surface': (s.onSurfaceVariant, s.surface),
        'onSurfaceVariant / surfaceContainerHigh': (
          s.onSurfaceVariant,
          s.surfaceContainerHigh,
        ),
        'onPrimary / primary': (s.onPrimary, s.primary),
        'onPrimaryContainer / primaryContainer': (
          s.onPrimaryContainer,
          s.primaryContainer,
        ),
        'onSecondaryContainer / secondaryContainer': (
          s.onSecondaryContainer,
          s.secondaryContainer,
        ),
        'onTertiary / tertiary': (s.onTertiary, s.tertiary),
        'onTertiaryContainer / tertiaryContainer': (
          s.onTertiaryContainer,
          s.tertiaryContainer,
        ),
        'error / surface': (s.error, s.surface),
      };
      for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
        test('$label is readable', () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }

      test('primary stands out from the surface (3:1 for icons)', () {
        expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(3));
      });

      test('has the expected brightness', () {
        expect(
          s.brightness,
          name == 'dark' ? Brightness.dark : Brightness.light,
        );
      });
    });
  }
}
