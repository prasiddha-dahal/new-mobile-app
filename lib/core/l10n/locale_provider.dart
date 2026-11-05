import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_storage.dart';
import 'l10n.dart';

/// The locales the app actually ships strings for.
///
/// Sourced from the generated `AppLocalizations` rather than hand-listed, so
/// dropping a new `app_<code>.arb` into `lib/l10n/` is the only step needed to
/// add a language — nothing here has to be remembered.
List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

/// English, the language every key is guaranteed to have.
const Locale fallbackLocale = Locale('en');

/// Resolves an arbitrary locale to one we ship.
///
/// Matches on language code only: `ne_NP`, `ne_IN` and bare `ne` are all the
/// same set of strings to us, and a user whose device is set to a Nepali
/// region variant should get Nepali, not English.
Locale resolveSupportedLocale(Locale? candidate) {
  if (candidate == null) return fallbackLocale;
  for (final locale in supportedLocales) {
    if (locale.languageCode == candidate.languageCode) return locale;
  }
  return fallbackLocale;
}

/// The locale the device asks for, resolved to something we ship.
///
/// Falls back to English if the platform cannot be asked — which is the case
/// in a plain `dart test` with no binding.
Locale deviceLocale() {
  try {
    return resolveSupportedLocale(PlatformDispatcher.instance.locale);
  } catch (_) {
    return fallbackLocale;
  }
}

/// The app's selected locale.
///
/// Starts at the device locale (when we support it, else English) so the very
/// first frame is already in the right language, then resolves whatever the
/// user chose on a previous launch. An explicit choice always outranks the
/// device: someone on an English phone who picked Nepali meant it.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage, {Locale? initial})
    : super(resolveSupportedLocale(initial ?? deviceLocale())) {
    restored = _restore();
  }

  final PreferencesStorage _storage;

  /// Completes once the stored choice (if any) has been applied. Await this in
  /// tests; production code does not need to — the UI simply rebuilds.
  late final Future<void> restored;

  Future<void> _restore() async {
    final stored = await _storage.readString(PreferenceKeys.locale);
    if (stored == null || stored.isEmpty) return;
    if (!mounted) return;

    final resolved = resolveSupportedLocale(Locale(stored));
    // A stored code we no longer ship resolves to English. Don't write that
    // back — if support returns, the original choice is still there.
    if (resolved != state) state = resolved;
  }

  /// Selects [locale] and remembers it. A locale we do not ship is coerced to
  /// one we do rather than leaving the UI with no strings.
  Future<void> set(Locale locale) async {
    final resolved = resolveSupportedLocale(locale);
    if (mounted) state = resolved;
    await _storage.writeString(PreferenceKeys.locale, resolved.languageCode);
  }
}

/// The single source of truth for the app's language.
///
/// Nothing else holds language state. There used to be a second store — an
/// `AppLang` enum with its own SharedPreferences key, feeding a pair of
/// ported string tables — and the sweep that finished the ARB migration
/// deleted it. Do not reintroduce one.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref.watch(preferencesStorageProvider)),
);
