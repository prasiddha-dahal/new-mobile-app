import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String fontSerif = 'Fraunces';
  static const String fontSans = 'Inter';
  static const String fontMono = 'IBM Plex Mono';

  static TextTheme get textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontSerif,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: fontSerif,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontSerif,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontSerif,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: fontSans,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: fontSans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: fontSans,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      labelLarge: TextStyle(
        fontFamily: fontMono,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
        color: AppColors.inkMute,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontSans,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontSans,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.inkMid,
      ),
      bodySmall: TextStyle(
        fontFamily: fontSans,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.inkMute,
      ),
      labelSmall: TextStyle(
        fontFamily: fontMono,
        fontSize: 10,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.inkMute,
      ),
    );
  }
}
