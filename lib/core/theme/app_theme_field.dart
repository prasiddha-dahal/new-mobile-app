import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// The soft sage used for field and outlined-button borders.
final Color appSageBorder = Color.alphaBlend(
  AppColors.pineLight.withAlpha(90),
  Colors.white,
);

/// Rounded, white, outlined text fields in the app's own type.
///
/// Wrap a form in `Theme(data: appFieldTheme(Theme.of(context)), ...)` and
/// every text field inside it (including the shared picker and autocomplete
/// widgets) takes on the look, with no per-field styling.
///
/// Signup, login and forgot-password each carry their own copy of this; they
/// can switch to this one whenever convenient.
ThemeData appFieldTheme(ThemeData base) {
  final body = AppTypography.textTheme.bodyMedium!;
  final small = AppTypography.textTheme.bodySmall!;

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: body.copyWith(color: AppColors.inkMid, letterSpacing: 0),
      labelStyle: body.copyWith(color: AppColors.inkMid, letterSpacing: 0),
      floatingLabelStyle: body.copyWith(
        color: AppColors.pine,
        letterSpacing: 0,
      ),
      helperStyle: small.copyWith(letterSpacing: 0),
      errorStyle: small.copyWith(color: AppColors.danger, letterSpacing: 0),
      // Validation messages can include the supported city list; keep them
      // readable instead of truncating the message with an ellipsis.
      errorMaxLines: 4,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIconColor: AppColors.inkMid,
      suffixIconColor: AppColors.inkMid,
      enabledBorder: border(appSageBorder),
      border: border(appSageBorder),
      focusedBorder: border(AppColors.pine, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
  );
}