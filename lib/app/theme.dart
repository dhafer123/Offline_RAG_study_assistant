import 'package:flutter/material.dart';

/// Colors of the app icon and the assistant bot (`design/`), the theme's
/// starting point.
abstract final class BrandColors {
  /// The bot's ear pieces: primary.
  static const blue = Color(0xFF2D6CF0);

  /// The bot's eyes and antenna: accents (tertiary).
  static const cyan = Color(0xFF45E7F4);

  /// The bot's visor: dark surfaces.
  static const navy = Color(0xFF13213F);

  /// The icon's background.
  static const deepNavy = Color(0xFF0B1E4A);

  /// The bot's helmet: light surfaces.
  static const helmet = Color(0xFFE2E9F4);
}

abstract final class AppTheme {
  static const Color seed = BrandColors.blue;

  static final ThemeData light = _build(_lightScheme());
  static final ThemeData dark = _build(_darkScheme());

  /// Blue keeps its full saturation (fidelity), cyan becomes the tertiary
  /// accent, surfaces are tinted like the bot's helmet.
  static ColorScheme _lightScheme() {
    final accent = ColorScheme.fromSeed(seedColor: BrandColors.cyan);
    return ColorScheme.fromSeed(
      seedColor: seed,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      tertiary: accent.primary,
      onTertiary: accent.onPrimary,
      tertiaryContainer: accent.primaryContainer,
      onTertiaryContainer: accent.onPrimaryContainer,
      surface: const Color(0xFFF7F9FD),
      surfaceDim: const Color(0xFFD8DFEB),
      surfaceBright: const Color(0xFFF7F9FD),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F4FA),
      surfaceContainer: const Color(0xFFE9EEF7),
      surfaceContainerHigh: BrandColors.helmet,
      surfaceContainerHighest: const Color(0xFFD9E1EE),
      onSurface: const Color(0xFF0E1A33),
      onSurfaceVariant: const Color(0xFF465169),
      outline: const Color(0xFF727D94),
      outlineVariant: const Color(0xFFC4CFE2),
    );
  }

  /// Navy surfaces from the bot's visor, cyan accents like its eyes.
  static ColorScheme _darkScheme() {
    final accent = ColorScheme.fromSeed(
      seedColor: BrandColors.cyan,
      brightness: Brightness.dark,
    );
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      tertiary: BrandColors.cyan,
      onTertiary: const Color(0xFF00363B),
      tertiaryContainer: accent.primaryContainer,
      onTertiaryContainer: accent.onPrimaryContainer,
      surface: const Color(0xFF0A1330),
      surfaceDim: const Color(0xFF0A1330),
      surfaceBright: const Color(0xFF2A3858),
      surfaceContainerLowest: const Color(0xFF060D22),
      surfaceContainerLow: const Color(0xFF0F1A38),
      surfaceContainer: BrandColors.navy,
      surfaceContainerHigh: const Color(0xFF1B2A4C),
      surfaceContainerHighest: const Color(0xFF253559),
      onSurface: BrandColors.helmet,
      onSurfaceVariant: const Color(0xFFA9B6CF),
      outline: const Color(0xFF6B7894),
      outlineVariant: const Color(0xFF2E3C5C),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme);
    final text = base.textTheme;
    const rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      // Bolder titles: friendlier, and easier to scan. Sizes come from
      // Material's typography, merged in when the theme is applied.
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: rounded,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(shape: rounded),
      // Main actions in the brand blue in both modes (dark mode's primary is
      // a pale tone, for text and icons on navy).
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
        ),
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}
