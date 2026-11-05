import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/locale_provider.dart';
import 'package:sahayatri_care_connect/core/storage/preferences_storage.dart';

/// Reads an ARB straight off disk rather than through the generated class.
///
/// The generated class only contains what `gen-l10n` could reconcile, so
/// testing it would hide exactly the drift these tests exist to catch.
Map<String, dynamic> _arb(String name) {
  final file = File('lib/l10n/$name');
  if (!file.existsSync()) {
    throw StateError(
      '${file.path} is missing — l10n.yaml points arb-dir at lib/l10n',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Translatable keys: everything that is not `@@locale` or an `@key`
/// metadata entry.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// The only strings allowed to reach a Nepali reader in English.
///
/// Every one of these is a string with nothing in it to translate, and each
/// is asserted below to be byte-identical in the two files — so this cannot
/// become a place to park work that was not finished. A string that merely
/// *looks* English (a heading, a button, a sentence) does not belong here.
const untranslatedByDesign = {
  // The language toggle shows both scripts at once, so either reader can
  // find their own language without first parsing the other.
  'languageEnglish',
  'languageNepali',

  // Formats and example values. A placeholder showing the *shape* of an
  // input — an address, a code, a phone number — is not a sentence, and
  // translating it would describe a format the field does not accept.
  'fieldEmailHint',
  'fieldEmailHintShort',
  'fieldPasswordHint',
  'fieldPhoneHint',
  'fieldReferralHint',
  'fieldNmcLicenceHint',
  'otpCodeHint',
  'fieldDobHint',

  // Numerals typed on a Latin keypad. A Devanagari hint over a field that
  // only accepts Latin digits would be telling the user the wrong thing.
  'fieldYearsExperienceHint',
  'fieldRatePerSessionHint',

  // Place names. The existing reviewed Nepali corpus keeps all six city
  // names in Latin, and so does local signage, so this follows it rather
  // than inventing a second convention.
  'cityKathmandu',
  'cityLalitpur',
  'cityBhaktapur',
  'cityPokhara',
  'cityChitwan',
  'cityBiratnagar',
  'fieldCityAreaHint',
  'areaPatan',
  'areaJawalakhel',
  'areaPulchowk',
  'areaSanepa',
  'areaJhamsikhel',
  'areaKirtipur',
  'areaBudhanilkantha',
  'areaTokha',
  'areaGokarneshwor',

  // Brand names and one abbreviation that is written in Latin here too.
  'payoutEsewa',
  'payoutKhalti',
  'shareViaWhatsapp',
  'shareViaSms',
  'aboutEyebrow',

  // Pure composition: every word in these arrives through a placeholder that
  // is itself translated, and only the punctuation between them is literal.
  'sessionTabWithCount',
  'therapistRatingValue',
  'dayOffReasonDetail',
  'dayOffDateReason',
  'recordsConditionSessions',
  'earningsCredit',
  'packagesProgressPercent',
  'rewardsPointsGain',
  'rewardsPointsDelta',
  'findWindowRange',
  'findFilterSummary',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = _arb('app_en.arb');
  final ne = _arb('app_ne.arb');

  group('ARB files', () {
    test('English and Nepali carry exactly the same keys', () {
      final enKeys = _messageKeys(en);
      final neKeys = _messageKeys(ne);

      // Reported in both directions, because the two failures need different
      // fixes: one is an untranslated string shipping as English, the other
      // is a dead Nepali entry nothing renders.
      expect(
        enKeys.difference(neKeys),
        isEmpty,
        reason:
            'These keys exist in app_en.arb but not app_ne.arb, so Nepali '
            'readers would silently get English. Add them to app_ne.arb.',
      );
      expect(
        neKeys.difference(enKeys),
        isEmpty,
        reason:
            'These keys exist in app_ne.arb but not app_en.arb. English is '
            'the template, so they are unreachable — remove them, or add the '
            'English source.',
      );
    });

    test('every English key has a description', () {
      // The descriptions are what make the next iteration mechanical: whoever
      // translates the rest of the app should never have to open the screen
      // to work out what a string means.
      for (final key in _messageKeys(en)) {
        final meta = en['@$key'];
        expect(
          meta,
          isA<Map<String, dynamic>>(),
          reason: 'app_en.arb is missing the "@$key" metadata entry',
        );
        final description = (meta as Map<String, dynamic>)['description'];
        expect(
          description,
          isA<String>(),
          reason: '"@$key" has no description',
        );
        expect(
          (description as String).trim(),
          isNotEmpty,
          reason: '"@$key" has an empty description',
        );
      }
    });

    test('every Nepali string is genuinely Nepali, not an English placeholder',
        () {
      final devanagari = RegExp(r'[ऀ-ॿ]');

      for (final key in _messageKeys(ne)) {
        if (untranslatedByDesign.contains(key)) continue;
        expect(
          devanagari.hasMatch(ne[key] as String),
          isTrue,
          reason:
              '"$key" in app_ne.arb has no Devanagari. If the English is '
              'genuinely what a Nepali reader should see — a code, a format, '
              'a brand — add it to untranslatedByDesign in this test with a '
              'reason. Otherwise it is an untranslated string.',
        );
      }
    });

    test('and the exemption list cannot quietly grow', () {
      // The list above is the only way to ship an English string to a Nepali
      // reader, so it is asserted from both ends: everything on it really is
      // identical in the two files (an entry that has since been translated
      // is dead weight and hides the next one), and nothing that differs is
      // on it.
      for (final key in untranslatedByDesign) {
        expect(
          _messageKeys(en),
          contains(key),
          reason: '"$key" is exempted but no longer exists',
        );
        expect(
          ne[key],
          en[key],
          reason:
              '"$key" is on untranslatedByDesign but the two files disagree. '
              'If it has a real translation now, take it off the list.',
        );
      }
    });

    test('both files declare their locale', () {
      expect(en['@@locale'], 'en');
      expect(ne['@@locale'], 'ne');
    });

    test('the shipped locales match the ARB files on disk', () {
      final codes = supportedLocales.map((l) => l.languageCode).toSet();
      expect(codes, {'en', 'ne'});
    });
  });

  group('resolveSupportedLocale', () {
    test('keeps a locale we ship', () {
      expect(resolveSupportedLocale(const Locale('ne')), const Locale('ne'));
    });

    test('matches on language, ignoring the region', () {
      // A phone set to ne_NP should get Nepali, not English.
      expect(resolveSupportedLocale(const Locale('ne', 'NP')), const Locale('ne'));
    });

    test('falls back to English for a language we do not ship', () {
      expect(resolveSupportedLocale(const Locale('fr')), const Locale('en'));
      expect(resolveSupportedLocale(null), const Locale('en'));
    });
  });

  group('localeProvider', () {
    ProviderContainer containerWith(PreferencesStorage storage) {
      final container = ProviderContainer(
        overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('round-trips a choice through storage', () async {
      final storage = InMemoryPreferencesStorage();

      final first = containerWith(storage);
      await first.read(localeProvider.notifier).restored;
      await first.read(localeProvider.notifier).set(const Locale('ne'));
      expect(first.read(localeProvider), const Locale('ne'));

      // A second container is the next app launch: same storage, fresh state.
      final second = containerWith(storage);
      await second.read(localeProvider.notifier).restored;
      expect(second.read(localeProvider), const Locale('ne'));
    });

    test('an unsupported stored code degrades to English without erasing it',
        () async {
      final storage = InMemoryPreferencesStorage({
        PreferenceKeys.locale: 'fr',
      });

      final container = containerWith(storage);
      await container.read(localeProvider.notifier).restored;

      expect(container.read(localeProvider), const Locale('en'));
      // Still 'fr' on disk: if French ever ships, the choice is honoured
      // rather than having been quietly rewritten to English.
      expect(await storage.readString(PreferenceKeys.locale), 'fr');
    });

    test('setting an unsupported locale is coerced rather than applied',
        () async {
      final container = containerWith(InMemoryPreferencesStorage());
      await container.read(localeProvider.notifier).restored;

      await container.read(localeProvider.notifier).set(const Locale('fr'));

      expect(container.read(localeProvider), const Locale('en'));
    });

    test('reads the key the pre-l10n language toggle wrote', () async {
      // Upgrading must not reset someone who had already chosen Nepali.
      final container = containerWith(
        InMemoryPreferencesStorage({'app_language': 'ne'}),
      );
      await container.read(localeProvider.notifier).restored;

      expect(container.read(localeProvider), const Locale('ne'));
    });

    test('is the only place the language lives', () async {
      // There used to be a second store: an `AppLang` enum with its own
      // SharedPreferences key, feeding a pair of ported string tables. Two
      // stores for one choice is one too many, and the sweep that finished
      // the ARB migration deleted it. This pins that the survivor is the one
      // that persists — a reintroduced second store would drift from it.
      final storage = InMemoryPreferencesStorage();
      final container = containerWith(storage);
      await container.read(localeProvider.notifier).restored;

      await container.read(localeProvider.notifier).set(const Locale('ne'));

      expect(container.read(localeProvider), const Locale('ne'));
      expect(await storage.readString(PreferenceKeys.locale), 'ne');
    });
  });
}
