import 'package:flutter/material.dart';

// Centralized app theme using Material 3 expressive defaults.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  // Primary palette derived from a single seed color (indigo‑toned).
  colorSchemeSeed: const Color(0xFF6750A4),
  // Text styles following the expressive spec.
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      height: 1.4,
    ),
  ),
  // ElevatedButton that harmonizes with the seed palette.
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF6750A4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  ),
);
