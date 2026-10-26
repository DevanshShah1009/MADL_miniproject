import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xFF0B1120), card = Color(0xFF151F32);
  static const blue = Color(0xFF4F8CFF), teal = Color(0xFF35C99A);
  static const amber = Color(0xFFFFB547), red = Color(0xFFFF647C);
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.blue,
    brightness: brightness,
    primary: dark ? Palette.blue : const Color(0xFF225FD2),
    secondary: Palette.teal,
    surface: dark ? Palette.card : Colors.white,
    error: Palette.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? Palette.background
        : const Color(0xFFF2F5FA),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Palette.background : const Color(0xFFF2F5FA),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: dark ? Palette.card : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.all(17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
