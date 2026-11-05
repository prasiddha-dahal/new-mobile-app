import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color pine = Color(0xFF2F5D50);
  static const Color pineLight = Color(0xFF3F7965);
  static const Color pinePale = Color(0xFFD1E8DF);
  static const Color mist = Color(0xFFEEF1ED);
  static const Color amberBrand = Color(0xFFE2962F);
  static const Color amberPale = Color(0xFFFBEFD9);
  static const Color cream = Color(0xFFFBFBF8);

  // Text
  static const Color ink = Color(0xFF1E2A2E);
  static const Color inkMid = Color(0xFF4A5854);
  static const Color inkMute = Color(0xFF8FA8A0);

  // Status
  static const Color danger = Color(0xFFC84B4B);
  static const Color dangerPale = Color(0xFFFCE8E8);
  static const Color success = Color(0xFF7AE2A1);

  // Surfaces
  static const Color background = Color(0xFFEEF1ED);
  static const Color card = Colors.white;
  static const Color border = Color(0x0F000000);

  // Placeholder / not-yet-available states. Deliberately neutral and slightly
  // hatched-looking so an unfinished asset never reads as finished design.
  static const Color placeholderFill = Color(0xFFE4E8E4);
  static const Color placeholderBorder = Color(0xFFCBD3CD);
  static const Color placeholderInk = Color(0xFF8A968F);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double page = 20;
}

/// Corner radii, taken from the spec's own scale
/// (`docs/LOVABLE_DESIGN_SPEC.md` → Design system → Radius scale).
///
/// The names are the spec's rather than a t-shirt ladder, because the scale
/// is semantic there — "cards (the default)", "small tiles", "bottom-sheet
/// detail rows" — and the ladder that used to be here was not the same scale:
/// it offered `4 / 8 / 12 / 16 / 24 / 32` against the spec's
/// `8 / 10 / 14 / 18 / 22`, with no 18 in it at all. So `AppCard` drew the
/// app's default card at `lg` = 16 while nineteen call sites reached past the
/// token file and wrote the 18 by hand — the spec value the tokens did not
/// offer. Both radii shipped, often on the same screen.
///
/// Two spec values are deliberately absent. The account header's
/// `0 0 28px 28px` is asymmetric and belongs to one widget, and the avatar
/// circle is a `BoxShape.circle`, not a radius.
class AppRadii {
  AppRadii._();

  /// Schedule-grid cells.
  static const double cell = 8;

  /// Bottom-sheet detail rows.
  static const double row = 10;

  /// Small tiles, time-slot buttons, icon squares, date chips.
  static const double tile = 14;

  /// **Cards — the default.** Also textareas, dropzones, radio rows and
  /// share buttons. What [AppCard] draws, and the one value anything
  /// card-shaped should be reading.
  static const double card = 18;

  /// Hero card, bottom nav bar, bottom-sheet top corners.
  static const double sheet = 22;

  /// Buttons, chips, badges, inputs, pills.
  static const double full = 999;
}


