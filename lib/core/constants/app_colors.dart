import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light theme
  static const Color softRose = Color(0xFFFF9AA2);
  static const Color lavender = Color(0xFFB5B9FF);
  static const Color peach = Color(0xFFFFD1B5);
  static const Color warmWhite = Color(0xFFFDF8F5);
  static const Color deepCharcoal = Color(0xFF2D4059);

  // Dark theme
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkCard = Color(0xFF1F2B47);
  static const Color darkText = Color(0xFFF5F5F5);

  // Functional
  static const Color error = Color(0xFFE74C3C);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);

  // Primary & Text aliases
  static const Color primary = softRose;
  static const Color textPrimaryLight = deepCharcoal;

  // Soft variants for backgrounds / containers
  static const Color softRoseLight = Color(0xFFFFE0E3);
  static const Color lavenderLight = Color(0xFFE0E3FF);
  static const Color peachLight = Color(0xFFFFE8D6);
}
