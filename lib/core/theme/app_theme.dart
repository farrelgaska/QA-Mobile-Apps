import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        titleLarge: GoogleFonts.inter(
          color: AppColors.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleMedium: GoogleFonts.inter(
          color: AppColors.textMain,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: GoogleFonts.inter(
          color: AppColors.textMain,
          fontSize: 14,
        ),
        bodyMedium: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelLarge: GoogleFonts.inter(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorderRadius,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorderRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorderRadius,
          borderSide: const BorderSide(color: AppColors.rejectedText, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textSoft, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
