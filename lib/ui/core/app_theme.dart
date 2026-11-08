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

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: hungryPrimary,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pageBackground,
        foregroundColor: inkDark,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}

