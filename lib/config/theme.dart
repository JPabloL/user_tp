import 'package:flutter/material.dart';

class AppTheme {
  static const Color navyPrimary = Color(0xFF0B101E);
  static const Color navySurface = Color(0xFF131B2F);
  static const Color navyElevated = Color(0xFF1A2642);

  static const Color brandTeal = Color(0xFF32D4B6);
  static const Color brandYellow = Color(0xFFFFDE00);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  static TextStyle _oswald({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: 'Oswald',
      fontFamilyFallback: const ['sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
    );
  }

  static TextStyle _outfit({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontFamily: 'Outfit',
      fontFamilyFallback: const ['sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navyPrimary,
      primaryColor: brandTeal,
      colorScheme: const ColorScheme.dark(
        primary: brandTeal,
        secondary: brandYellow,
        surface: navySurface,
        background: navyPrimary,
        error: error,
      ),
      textTheme: TextTheme(
        displayLarge: _oswald(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
        displayMedium: _oswald(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
        displaySmall: _oswald(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
        headlineMedium: _oswald(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
        titleLarge: _outfit(
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: _outfit(fontSize: 16),
        bodyMedium: _outfit(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandTeal,
          foregroundColor: navyPrimary,
          textStyle: _oswald(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: brandTeal.withValues(alpha: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navySurface,
        hintStyle: _outfit(fontSize: 14, color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navyPrimary,
        selectedItemColor: brandTeal,
        unselectedItemColor: textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
