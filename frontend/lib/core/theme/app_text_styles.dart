import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static TextTheme textTheme([TextTheme? base]) {
    final notoTheme = GoogleFonts.notoSansKrTextTheme(base);

    return notoTheme
        .copyWith(
          displayLarge: _style(
            notoTheme.displayLarge,
            40,
            FontWeight.w700,
            1.25,
          ),
          displayMedium: _style(
            notoTheme.displayMedium,
            34,
            FontWeight.w700,
            1.25,
          ),
          displaySmall: _style(
            notoTheme.displaySmall,
            30,
            FontWeight.w700,
            1.3,
          ),
          headlineLarge: _style(
            notoTheme.headlineLarge,
            28,
            FontWeight.w700,
            1.3,
          ),
          headlineMedium: _style(
            notoTheme.headlineMedium,
            24,
            FontWeight.w700,
            1.35,
          ),
          headlineSmall: _style(
            notoTheme.headlineSmall,
            21,
            FontWeight.w700,
            1.35,
          ),
          titleLarge: _style(notoTheme.titleLarge, 20, FontWeight.w700, 1.4),
          titleMedium: _style(notoTheme.titleMedium, 17, FontWeight.w600, 1.45),
          titleSmall: _style(notoTheme.titleSmall, 15, FontWeight.w600, 1.45),
          bodyLarge: _style(notoTheme.bodyLarge, 16, FontWeight.w400, 1.55),
          bodyMedium: _style(notoTheme.bodyMedium, 14, FontWeight.w400, 1.5),
          bodySmall: _style(notoTheme.bodySmall, 12, FontWeight.w400, 1.45),
          labelLarge: _style(notoTheme.labelLarge, 15, FontWeight.w600, 1.35),
          labelMedium: _style(notoTheme.labelMedium, 13, FontWeight.w600, 1.35),
          labelSmall: _style(notoTheme.labelSmall, 11, FontWeight.w600, 1.3),
        )
        .apply(bodyColor: AppColors.mainText, displayColor: AppColors.mainText);
  }

  static TextStyle get heroTitle => GoogleFonts.notoSansKr(
    fontSize: 26,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AppColors.mainText,
  );

  static TextStyle get sectionTitle => GoogleFonts.notoSansKr(
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: AppColors.mainText,
  );

  static TextStyle get body => GoogleFonts.notoSansKr(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.mainText,
  );

  static TextStyle get caption => GoogleFonts.notoSansKr(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
  );

  static TextStyle _style(
    TextStyle? base,
    double fontSize,
    FontWeight fontWeight,
    double height,
  ) {
    return (base ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: -0.2,
    );
  }
}
