import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_en.dart';

/// One import for everything localisation-related.
///
/// The generated classes live under `lib/l10n/generated/`, which is gitignored
/// and rebuilt by `flutter pub get`. Importing them through here means the
/// rest of the app never spells that path, so moving the output is one edit.
export '../../l10n/generated/app_localizations.dart';

/// The English strings, for code that has no `BuildContext`.
///
/// A test asserting on a validator's wording, a pure function called off the
/// widget tree, a log line. Not a fallback for UI code: a screen that reaches
/// for this instead of `context.l10n` renders English to a Nepali reader.
AppLocalizations get englishL10n => AppLocalizationsEn();

extension L10nX on BuildContext {
  /// The localised strings for this context.
  ///
  /// Never null. `AppLocalizations.of` returns null whenever the delegates
  /// are not installed above this widget — a bare `MaterialApp` in a widget
  /// test, a widget pumped on its own, a route built outside the app root —
  /// and a shared widget should degrade to English there rather than throw.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? AppLocalizationsEn();
}
