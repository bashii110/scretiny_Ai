import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9C95FF);
  static const Color primaryDark = Color(0xFF4A43D6);

  // Secondary palette
  static const Color secondary = Color(0xFF48CAE4);
  static const Color secondaryLight = Color(0xFF85DAEF);
  static const Color secondaryDark = Color(0xFF0E9AB8);

  // Stress level colors
  static const Color stressLow = Color(0xFF4CAF50);
  static const Color stressMedium = Color(0xFFFF9800);
  static const Color stressHigh = Color(0xFFF44336);
  static const Color stressCritical = Color(0xFF9C27B0);

  // Backgrounds
  static const Color background = Color(0xFFF8F9FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F0F8);

  // Text
  static const Color textDark = Color(0xFF2D3142);
  static const Color textMedium = Color(0xFF4A4E6B);
  static const Color textLight = Color(0xFF9094A6);

  // Borders
  static const Color border = Color(0xFFE8E8F0);
  static const Color divider = Color(0xFFF0F0F8);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Dark theme backgrounds
  static const Color darkBackground = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkSurfaceVariant = Color(0xFF374151);

  // Gradient stops
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient calmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEECFF), Color(0xFFE0F7FA)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FE)],
  );

  // Stress score color helper
  static Color stressColor(double score) {
    if (score <= 25) return stressLow;
    if (score <= 50) return stressMedium;
    if (score <= 75) return stressHigh;
    return stressCritical;
  }

  // Faith-based accent colors
  static const Map<String, Color> faithColors = {
    'islam': Color(0xFF1E8449),
    'christian': Color(0xFF2874A6),
    'hindu': Color(0xFFD35400),
    'buddhism': Color(0xFFF39C12),
    'secular': Color(0xFF6C63FF),
  };
}