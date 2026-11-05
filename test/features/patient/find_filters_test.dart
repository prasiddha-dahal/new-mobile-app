import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/availability.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/domain/repositories/availability_repository.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/availability_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_find_screen.dart';

import '../../l10n_harness.dart';

/// Two controls on the Find screen that were not doing their job.
///
/// The specialism row was six chips in a horizontal scroll: on a phone the
/// last two were off the edge, with nothing to say the row scrolled. And the
/// "When are you free?" sheet offered a fortnight of day pills but no calendar,
/// so anyone who wanted "the 9th" had to scroll a strip to find it.
class _NoSlots implements AvailabilityRepository {
  @override
  Future<Map<String, AppResult<List<TherapistSlot>>>> slotsForTherapists({
    required List<String> therapistIds,
    required String fromDate,
    required String toDate,
  }) async => {
    for (final id in therapistIds) id: const Right(<TherapistSlot>[]),
  };

  @override
  void invalidate([Iterable<String>? therapistIds]) {}
}

Therapist _therapist(String id, String specialty) => Therapist(
  id: id,
  userId: 'u-$id',
  name: 'Dr. $id',
  specialty: specialty,
  city: 'Lalitpur',
  gender: 'Female',
  rating: 4.5,
  reviewCount: 10,
  fee: 1500,
  experienceYears: 5,
  bio: '',
);

void main() {
  Future<ProviderContainer> pumpFind(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Size size = const Size(560, 1400),
    double textScale = 1.0,
    List<Therapist>? therapists,
  }) async {
    final container = await pumpLocalized(
      tester,
      Theme(data: AppTheme.light, child: const PatientFindScreen()),
      locale: locale,
      size: size,
      textScale: textScale,
      overrides: [
        therapistListProvider.overrideWith(
          (_) async =>
              therapists ??
              [
                _therapist('sports', 'Sports & post-surgery'),
                _therapist('neuro', 'Neuro rehab'),
                _therapist('kids', 'Pediatric physio'),
              ],
        ),
        availabilityRepositoryProvider.overrideWithValue(_NoSlots()),
      ],
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The dropdown pill, whatever it currently reads.
  final dropdown = find.byType(PopupMenuButton<String>);

  /// One entry of the open menu. Matched inside the menu because the selected
  /// value is also printed on the pill, so its text alone is ambiguous.
  Finder menuItem(String label) => find.descendant(
    of: find.byType(PopupMenuItem<String>),
    matching: find.text(label),
  );

  group('the specialism dropdown', () {
    testWidgets('replaces the chip row, and starts on "All specialties"', (
      tester,
    ) async {
      await pumpFind(tester);

      expect(find.text('All specialties'), findsOneWidget);
      // The chips are gone: none of the options is on screen until the menu
      // opens.
      expect(find.text('Geriatric'), findsNothing);
      expect(find.text('Post-op'), findsNothing);
    });

    testWidgets('lists every specialism when opened', (tester) async {
      await pumpFind(tester);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Every option, including the two that used to sit off the right edge.
      for (final label in [
        'All specialties',
        'Sports',
        'Neuro',
        'Pediatric',
        'Geriatric',
        'Post-op',
      ]) {
        expect(menuItem(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('choosing one narrows the list and names itself', (
      tester,
    ) async {
      await pumpFind(tester);
      expect(find.text('Dr. sports'), findsOneWidget);
      expect(find.text('Dr. neuro'), findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Neuro'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. neuro'), findsOneWidget);
      expect(find.text('Dr. sports'), findsNothing);
      expect(find.text('Dr. kids'), findsNothing);
      // The pill now says what it is narrowing on.
      expect(find.text('Neuro'), findsOneWidget);
      expect(find.text('All specialties'), findsNothing);
    });

    testWidgets('and "All specialties" puts the list back', (tester) async {
      await pumpFind(tester);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Pediatric'));
      await tester.pumpAndSettle();
      expect(find.text('Dr. sports'), findsNothing);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(menuItem('All specialties'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. sports'), findsOneWidget);
      expect(find.text('Dr. neuro'), findsOneWidget);
      expect(find.text('Dr. kids'), findsOneWidget);
    });

    testWidgets('reads in Nepali', (tester) async {
      await pumpFind(tester, locale: const Locale('ne'));

      expect(find.text('All specialties'), findsNothing);
      expect(find.text('सबै विशेषज्ञता'), findsOneWidget);
    });

    testWidgets('fits a 320dp phone at 1.6x text without overflowing', (
      tester,
    ) async {
      await pumpFind(
        tester,
        locale: const Locale('ne'),
        size: const Size(320, 640),
        textScale: 1.6,
        therapists: const <Therapist>[],
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('the calendar on the availability sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Any time'));
      await tester.pumpAndSettle();
    }

    testWidgets('is a field showing the chosen day, today by default', (
      tester,
    ) async {
      await pumpFind(tester);
      await openSheet(tester);

      expect(find.text('Pick a date'), findsOneWidget);
      expect(
        find.textContaining('${DateTime.now().year}'),
        findsWidgets,
        reason: 'the field shows a full date, year included',
      );
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('says why the dates stop where they do', (tester) async {
      await pumpFind(tester);
      await openSheet(tester);

      expect(
        find.text(
          'Open slots are shown for the next $availabilityHorizonDays days.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens a calendar, and a date picked there is applied', (
      tester,
    ) async {
      final container = await pumpFind(tester);
      await openSheet(tester);

      await tester.tap(find.text('Pick a date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The calendar opens on today; choose a later day inside the window.
      final target = DateTime.now().add(const Duration(days: 2));
      await tester.tap(find.text('${target.day}').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show therapists'));
      await tester.pumpAndSettle();

      final filter = container.read(availabilityFilterProvider);
      expect(filter, isNotNull);
      expect(filter!.date, formatDateKey(target));
    });

    testWidgets('cannot reach past the days that were fetched', (tester) async {
      await pumpFind(tester);
      await openSheet(tester);

      await tester.tap(find.text('Pick a date'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(picker.firstDate, today);
      expect(
        picker.lastDate,
        today.add(const Duration(days: availabilityHorizonDays - 1)),
        reason: 'a day beyond the cache would answer "nobody free" falsely',
      );
    });

    testWidgets('cancelling the calendar leaves the day alone', (tester) async {
      final container = await pumpFind(tester);
      await openSheet(tester);

      await tester.tap(find.text('Pick a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show therapists'));
      await tester.pumpAndSettle();

      expect(
        container.read(availabilityFilterProvider)!.date,
        formatDateKey(DateTime.now()),
      );
    });
  });
}
