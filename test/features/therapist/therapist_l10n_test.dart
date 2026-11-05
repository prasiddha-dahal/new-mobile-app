import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_availability_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_payout_methods_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_performance_screen.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_ne.dart';

import '../../l10n_harness.dart';
import 'availability_fakes.dart';

/// Therapist screens swept for hardcoded English.
///
/// Between them they cover the two patterns the sweep leaned on most: a
/// `const` list of option values with a separate label lookup (availability),
/// and a `const` list of tuples that had to become a builder because its
/// labels now need a context (performance).
///
/// The availability screen reads its pattern from the API now, so it comes
/// with a fake repository. Everything it renders is still decided by the
/// language, which is what these tests are about.
void main() {
  final ne = AppLocalizationsNe();

  testWidgets('the availability chips change language, values and all', (
    tester,
  ) async {
    final container = await pumpLocalized(
      tester,
      const TherapistAvailabilityScreen(),
      overrides: availabilityOverrides(
        repository: FakeAvailabilityRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Starts'), findsOneWidget);

    await switchTo(tester, container, const Locale('ne'));
    await tester.pumpAndSettle();

    expectNoEnglish(tester, const [
      'Manage availability',
      // `SectionHeader` upper-cases its title, so the headings have to be
      // listed as they are actually rendered — spelled in title case they
      // would match nothing and the check would have no teeth.
      'WORKING DAYS',
      'WORKING HOURS',
      'SESSION LENGTH',
      'Starts',
      'Ends',
      'Saved',
      'Save availability',
      'Taking time off? Request a day off',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ]);
    expect(find.text(ne.dayShortMon), findsOneWidget);
    expect(find.text(ne.availabilityStartLabel), findsOneWidget);
    expect(
      find.text(ne.availabilityHoursHeading.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('the performance KPIs do too', (tester) async {
    // The labels used to be a `const` list of tuples; they cannot be const
    // any more, and this is what catches it if someone puts them back.
    final container = await pumpLocalized(
      tester,
      const TherapistPerformanceScreen(),
    );
    await switchTo(tester, container, const Locale('ne'));

    expectNoEnglish(tester, const [
      'Performance',
      'Total completed',
      'This month',
      'Booking rate',
      'Sessions overview',
    ]);
  });

  testWidgets('and the payout methods screen', (tester) async {
    final container = await pumpLocalized(
      tester,
      const TherapistPayoutMethodsScreen(),
    );
    await switchTo(tester, container, const Locale('ne'));

    expectNoEnglish(tester, const [
      'Payout methods',
      'Primary method',
      'No payout method yet',
      'Other methods',
      'Bank transfer',
      'Add',
      'Add new payout method',
    ]);

    // The primary slot used to show a fabricated eSewa wallet -- account
    // 98XXXXXXXX21, a green verified tick and "Auto-payout every Friday" --
    // and this test asserted the brand survived translation. There is no
    // payout store behind the screen, so nothing is configured and the brand
    // has no business appearing as a method on file. The brand-survives-
    // translation property it was really guarding is held centrally instead:
    // payoutEsewa and payoutKhalti are on untranslatedByDesign, and
    // localization_test asserts every key there is identical in both files.
    expect(
      renderedText(tester).any((s) => s.contains('98XXXXXXXX21')),
      isFalse,
      reason: 'no account number may be shown while none is stored',
    );
  });

  testWidgets('therapist screens fit a small phone in Nepali', (tester) async {
    // Not the performance screen: its KPI grid has a fixed childAspectRatio
    // that already overflows on a 320pt viewport in English, so it would fail
    // here for a reason this pass did not cause. Noted in
    // docs/localization.md rather than fixed, because widening the grid is a
    // layout change.
    for (final screen in const [
      TherapistAvailabilityScreen(),
      TherapistPayoutMethodsScreen(),
    ]) {
      await pumpLocalized(
        tester,
        screen,
        locale: const Locale('ne'),
        size: const Size(320, 640),
        overrides: availabilityOverrides(
          repository: FakeAvailabilityRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$screen');
    }
  });
}
