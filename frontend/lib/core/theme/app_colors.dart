import 'package:flutter/material.dart';

/// OTFIT light theme palette.
///
/// Feature code should use these semantic colors instead of embedding color
/// literals so a future theme or brand refresh remains localized.
abstract final class AppColors {
  static const Color primaryNavy = Color(0xFF06113B);
  static const Color primaryPurple = Color(0xFF7550F8);
  static const Color primaryBlue = Color(0xFF456CFA);
  static const Color lightPurple = Color(0xFFEEE9FF);

  static const Color gradientStart = Color(0xFF7B4DFF);
  static const Color gradientEnd = Color(0xFF4774FF);

  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F3F8);
  static const Color mainText = Color(0xFF11162A);
  static const Color secondaryText = Color(0xFF72778A);
  static const Color divider = Color(0xFFE9EAF0);
  static const Color error = Color(0xFFE5484D);

  static const Color success = Color(0xFF218A62);
  static const Color warning = Color(0xFFF59E0B);
  static const Color disabled = Color(0xFFB6B9C5);
  static const Color shadow = Color(0x1406113B);
  static const Color overlay = Color(0x9906113B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: <Color>[Color(0xFFF1EDFF), Color(0xFFEAF0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
