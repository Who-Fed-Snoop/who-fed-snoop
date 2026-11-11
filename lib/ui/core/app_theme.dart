import 'package:flutter/material.dart';

/// Shared color tokens and Material 3 theme for "Who Fed Snoop?".
abstract final class AppTheme {
  // Hungry / Needs Meal palette (Warm Amber)
  static const Color hungryPrimary = Color(0xFFD97706);
  static const Color hungrySurface = Color(0xFFFFFBEB);
  static const Color hungryBorder = Color(0xFFFCD34D);

  // Fed / Happy Snoop palette (Vibrant Emerald)
  static const Color fedPrimary = Color(0xFF059669);
  static const Color fedSurface = Color(0xFFECFDF5);
  static const Color fedBorder = Color(0xFF6EE7B7);

  // Neutral ink & background
  static const Color inkDark = Color(0xFF1C1917);
  static const Color inkMuted = Color(0xFF57534E);
  static const Color pageBackground = Color(0xFFFAF8F5);

  // Snoop Mascot & Comic-Storybook tokens (90 lb Black Labradoodle)
  static const Color snoopCoatBlack = Color(0xFF1E1B18);
  static const Color snoopCurlHighlight = Color(0xFF3D3732);
  static const Color snoopTonguePink = Color(0xFFFF6B8B);
  static const Color snoopCollarGold = Color(0xFFFBBF24);
  static const Color snoopSkyAccent = Color(0xFF38BDF8);
  static const Color creamCard = Color(0xFFFFFDF8);

  /// Neo-brutalist comic card decoration with crisp dark border and solid offset shadow.
  static BoxDecoration comicCardDecoration({
    Color color = creamCard,
    Color borderColor = inkDark,
    double borderRadius = 24,
    double borderWidth = 2.5,
    double shadowOffset = 4,
    Color shadowColor = inkDark,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          offset: Offset(0, shadowOffset),
          blurRadius: 0,
        ),
      ],
    );
  }

  /// Rounded pill decoration with a crisp comic border.
  static BoxDecoration comicPillDecoration({
    required Color color,
    Color borderColor = inkDark,
    double borderWidth = 2,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: hungryPrimary,
      primary: hungryPrimary,
      secondary: fedPrimary,
      surface: creamCard,
      onSurface: inkDark,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pageBackground,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: pageBackground,
        foregroundColor: inkDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: hungryPrimary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: inkDark, width: 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: const BorderSide(color: inkDark, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamCard,
        selectedColor: snoopCollarGold.withValues(alpha: 0.35),
        labelStyle: const TextStyle(
          color: inkDark,
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: inkDark, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: inkMuted,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: inkDark, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hungryPrimary, width: 2.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: inkDark, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snoopCoatBlack,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: snoopCollarGold, width: 2),
        ),
      ),
    );
  }
}
