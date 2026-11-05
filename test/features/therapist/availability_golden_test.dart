import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/entities/working_hours.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_availability_screen.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_en.dart';

import '../../l10n_harness.dart';
import 'availability_fakes.dart';

/// Pictures of the availability editor.
///
/// Assertions on this project have repeatedly agreed that something was fine
/// while it was invisible or unreadable — a pill the same colour as the row it
/// sat on passed a colour check, a header that wrapped to one letter per line
/// passed an overflow check. Three things here are exactly that shape and no
/// assertion in `availability_screen_test.dart` can see them:
///
/// 1. **The saved / not-saved pill**, amber on cream. This shot has already
///    earned its keep: the pill started out in the trailing slot of a `Row`
///    with the intro sentence, where a non-flex child gets unbounded width —
///    159px off the right edge at 320dp / 1.6x in Nepali. Every assertion in
///    `availability_screen_test.dart` passed while it did that, and so did the
///    320dp Nepali overflow sweep, which runs at 1.0. Stacked now, so the
///    label wraps inside the pill.
/// 2. **The failed-save banner** is danger-pale with danger ink and the
///    server's own sentence under it. A banner that does not stand off the
///    page is the same bug as a save that says nothing.
/// 3. **The two clock buttons** are a `Wrap`, not a `Row`, precisely because
///    they do not fit side by side at 1.6x in Nepali. Only a shot proves the
///    stack actually happens rather than the row overflowing.
///
/// Each is taken at 390dp in English, the size the designs were drawn at, and
/// the worst case at **320dp with 1.6x text in Nepali** — the small Android
/// phone, the accessibility font size, and the longer script.
///
/// Regenerate with
/// `flutter test --update-goldens test/features/therapist/availability_golden_test.dart`
/// and *look at the diff* before accepting it. The test font draws glyphs as
/// filled boxes, so these pin geometry, colour and containment rather than
/// letterforms — which is what all three failures above were.
void main() {
  final en = AppLocalizationsEn();

  Future<void> pump(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
    required double textScale,
    FakeAvailabilityRepository? repository,
  }) async {
    await pumpLocalized(
      tester,
      // A real ground under the shot: a transparent body would make a
      // low-contrast control look fine against nothing.
      const ColoredBox(
        color: AppColors.cream,
        child: TherapistAvailabilityScreen(),
      ),
      locale: locale,
      size: size,
      textScale: textScale,
      theme: AppTheme.light,
      overrides: availabilityOverrides(
        repository: repository ?? FakeAvailabilityRepository(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the availability editor', () {
    testWidgets('as stored, 390dp, English', (tester) async {
      await pump(
        tester,
        locale: const Locale('en'),
        size: const Size(390, 844),
        textScale: 1.0,
      );

      await expectLater(
        find.byType(TherapistAvailabilityScreen),
        matchesGoldenFile('goldens/availability_390_en.png'),
      );
    });

    testWidgets('and at 320dp / 1.6x in Nepali, mid-edit', (tester) async {
      // Edited, so the amber "not saved yet" pill is the one in shot — the
      // longer of the two strings in both languages, and the one that
      // overflowed.
      await pump(
        tester,
        locale: const Locale('ne'),
        size: const Size(320, 900),
        textScale: 1.6,
      );
      await tester.tap(find.text('शनि'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TherapistAvailabilityScreen),
        matchesGoldenFile('goldens/availability_320_ne_1_6x.png'),
      );
    });
  });

  group('the failed-save banner', () {
    testWidgets('390dp, English', (tester) async {
      await pump(
        tester,
        locale: const Locale('en'),
        size: const Size(390, 844),
        textScale: 1.0,
        repository: FakeAvailabilityRepository(
          saveFailure: const ServerUnavailableFailure(),
        ),
      );

      await tester.tap(find.text(en.dayShortSat));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      // Past the snackbar, so the shot is of the banner that stays rather
      // than the toast that goes.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TherapistAvailabilityScreen),
        matchesGoldenFile('goldens/availability_error_390_en.png'),
      );
    });
  });

  group('the refusal', () {
    testWidgets('an empty week at 320dp / 1.6x in Nepali', (tester) async {
      // The longest of the three refusal sentences, in the longer script, on
      // the narrowest phone: an amber block that has to hold two lines of
      // Devanagari without clipping and without pushing Save off the page.
      await pump(
        tester,
        locale: const Locale('ne'),
        size: const Size(320, 900),
        textScale: 1.6,
        repository: FakeAvailabilityRepository(
          stored: const WorkingHours(
            days: {Weekday.monday},
            startMinutes: 9 * 60,
            endMinutes: 18 * 60,
            sessionMinutes: 60,
          ),
        ),
      );

      await tester.tap(find.text('सोम'));
      await tester.pumpAndSettle();
      // The banner sits above Save, which is a long way below the fold at
      // this size — an unscrolled shot would pin the chips and miss the
      // thing being tested.
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TherapistAvailabilityScreen),
        matchesGoldenFile('goldens/availability_refusal_320_ne_1_6x.png'),
      );
    });
  });
}
