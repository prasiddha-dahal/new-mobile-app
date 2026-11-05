import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.pine,
      onPrimary: Colors.white,
      primaryContainer: AppColors.pinePale,
      onPrimaryContainer: AppColors.pine,
      secondary: AppColors.amberBrand,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.amberPale,
      onSecondaryContainer: Color(0xFF8a5a14),
      tertiary: AppColors.mist,
      onTertiary: AppColors.inkMid,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.mist,
      onSurfaceVariant: AppColors.inkMute,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerPale,
      onErrorContainer: AppColors.danger,
      outline:  Color(0x1A000000),
      outlineVariant:  Color(0x0F000000),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: AppTypography.fontSans,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.titleMedium,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amberBrand,
          foregroundColor: AppColors.ink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pine,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pine,
          side: const BorderSide(color: AppColors.pine, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        // Validation messages name the field and the fix, so they run longer
        // than one line in a half-width field — the default of 1 clipped
        // "Re-enter your password." to "Re-enter your passwor…".
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: const BorderSide(color: AppColors.pine, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.fontMono,
          fontSize: 10,
          letterSpacing: 1.8,
          color: AppColors.inkMute,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.pine,
        unselectedItemColor: AppColors.inkMute,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.pine,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
