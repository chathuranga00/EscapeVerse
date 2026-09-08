import 'package:flutter/material.dart';

/// EscapeVerse colour palette — dark jungle / temple adventure theme.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color deepJungle = Color(0xFF0D1F0F); // near-black dark green
  static const Color darkMoss = Color(0xFF1A3320); // forest shadow

  // Primary accents
  static const Color ancientGold = Color(0xFFD4A017); // temple gold
  static const Color fadedGold = Color(0xFFBF8B30); // weathered gold

  // Secondary / surface
  static const Color stoneBrown = Color(0xFF5C4A32); // carved stone
  static const Color lightStone = Color(0xFF8A7260); // lit stone surface

  // Text
  static const Color parchment = Color(0xFFF2E8C6); // aged parchment white
  static const Color mutedParchment = Color(0xFFBBAF94); // secondary text
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deepJungle,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.ancientGold,
        onPrimary: AppColors.deepJungle,
        secondary: AppColors.stoneBrown,
        onSecondary: AppColors.parchment,
        surface: AppColors.darkMoss,
        onSurface: AppColors.parchment,
        error: Color(0xFFCF6679),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkMoss,
        foregroundColor: AppColors.ancientGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.ancientGold,
          letterSpacing: 1.5,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.ancientGold,
          fontSize: 48,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        displayMedium: TextStyle(
          color: AppColors.ancientGold,
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.parchment,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.parchment,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AppColors.mutedParchment,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ancientGold,
          foregroundColor: AppColors.deepJungle,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkMoss,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.stoneBrown, width: 1.5),
        ),
        elevation: 4,
      ),
      useMaterial3: true,
    );
  }
}
