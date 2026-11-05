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
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_ne.dart';

import '../../l10n_harness.dart';

/// A stand-in for the availability repository that records every batch it is
/// handed.
///
/// The counting is the point. The API has no "who is free at T" endpoint, so
/// the only thing standing between this feature and twenty requests on first
/// paint is the batching, the laziness and the cache above this seam — and
/// none of that is visible in a screenshot. These tests assert the request
/// shape directly so a later refactor cannot quietly undo it.
class _CountingRepository implements AvailabilityRepository {
  _CountingRepository({this.slotsById = const {}, this.failFor = const {}});

  final Map<String, List<TherapistSlot>> slotsById;
  final Set<String> failFor;

  /// One entry per call, each the list of ids that call carried.
  final batches = <List<String>>[];

  List<String> get requestedIds => [for (final b in batches) ...b];

  @override
  Future<Map<String, AppResult<List<TherapistSlot>>>> slotsForTherapists({
    required List<String> therapistIds,
    required String fromDate,
    required String toDate,
  }) async {
    batches.add(List.of(therapistIds));
    return {
      for (final id in therapistIds)
        id: failFor.contains(id)
            ? const Left(NetworkFailure())
            : Right(slotsById[id] ?? const <TherapistSlot>[]),
    };
  }

  @override
  void invalidate([Iterable<String>? therapistIds]) {}
}

TherapistSlot _slot(String date, String time) =>
    TherapistSlot(date: date, time: time, isOpen: true);

Therapist _therapist(String id, {String name = ''}) => Therapist(
  id: id,
  userId: 'u-$id',
  name: name.isEmpty ? 'Dr. $id' : name,
  specialty: 'Sports',
  city: 'Lalitpur',
  gender: 'Female',
  rating: 4.5,
  reviewCount: 10,
  fee: 1500,
  experienceYears: 5,
  bio: '',
);

void main() {
  /// `YYYY-MM-DD` for a day relative to today, matching what the horizon
  /// provider will have asked the repository for.
  String dayKey(int offset) =>
      formatDateKey(DateTime.now().add(Duration(days: offset)));

  Future<ProviderContainer> pumpFind(
    WidgetTester tester, {
    required List<Therapist> therapists,
    required _CountingRepository repository,
    AvailabilityFilter? filter,
    // Wider than a phone on purpose. `flutter test` substitutes a font whose
    // every glyph is a full em square, so the card's fee-and-Book-now row
    // measures around 380px here against roughly 180px with the real faces —
    // it overflows a 390px viewport in the test and nowhere else. Height is
    // what decides how many cards get built, so the laziness this file
    // asserts is unaffected by widening it.
    Size size = const Size(560, 1400),
    Locale locale = const Locale('en'),
  }) async {
    final container = await pumpLocalized(
      tester,
      // The app's own theme rather than Material's default, so the card is
      // laid out the way it actually ships.
      Theme(data: AppTheme.light, child: const PatientFindScreen()),
      locale: locale,
      size: size,
      overrides: [
        therapistListProvider.overrideWith((_) async => therapists),
        availabilityRepositoryProvider.overrideWithValue(repository),
        if (filter != null)
          availabilityFilterProvider.overrideWith((_) => filter),
      ],
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('the next-free-slot line on a therapist card', () {
    testWidgets('says when each therapist is next free', (tester) async {
      final repository = _CountingRepository(
        slotsById: {
          'a': [_slot(dayKey(1), '09:00')],
          'b': [_slot(dayKey(3), '14:00')],
        },
      );

      await pumpFind(
        tester,
        therapists: [_therapist('a'), _therapist('b')],
        repository: repository,
      );

      expect(find.text('Free tomorrow · 9:00 AM'), findsOneWidget);
      expect(find.textContaining('Free ').at(1), findsOneWidget);
    });

    testWidgets('a checked, empty calendar is a real answer', (tester) async {
      final repository = _CountingRepository(slotsById: const {'a': []});

      await pumpFind(
        tester,
        therapists: [_therapist('a')],
        repository: repository,
      );

      expect(
        find.text('No free slots in the next $availabilityHorizonDays days'),
        findsOneWidget,
      );
    });

    testWidgets('a calendar that failed does not read as unavailable', (
      tester,
    ) async {
      final repository = _CountingRepository(failFor: {'a'});

      await pumpFind(
        tester,
        therapists: [_therapist('a')],
        repository: repository,
      );

      expect(find.text('Tap to see availability'), findsOneWidget);
      // The line that would be a lie: this therapist has told us nothing.
      expect(
        find.text('No free slots in the next $availabilityHorizonDays days'),
        findsNothing,
      );
    });
  });

  group('request shape — the N+1 guard', () {
    testWidgets('every visible card is one batched call, not one each', (
      tester,
    ) async {
      final repository = _CountingRepository(
        slotsById: {
          for (final id in ['a', 'b', 'c']) id: [_slot(dayKey(1), '09:00')],
        },
      );

      await pumpFind(
        tester,
        therapists: [_therapist('a'), _therapist('b'), _therapist('c')],
        repository: repository,
      );

      expect(repository.batches.length, 1);
      expect(repository.batches.single.toSet(), {'a', 'b', 'c'});
    });

    testWidgets('rebuilding the list asks for nothing new', (tester) async {
      final repository = _CountingRepository(
        slotsById: {'a': [_slot(dayKey(1), '09:00')]},
      );
      final container = await pumpFind(
        tester,
        therapists: [_therapist('a')],
        repository: repository,
      );

      final before = repository.batches.length;
      // A rebuild from any cause — a chip tap, a keystroke, a scroll back up.
      container.read(therapistAvailabilityProvider.notifier).request(['a']);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(repository.batches.length, before);
    });

    testWidgets('a long list does not fetch every therapist on first paint', (
      tester,
    ) async {
      final ids = [for (var i = 0; i < 20; i++) 't$i'];
      final repository = _CountingRepository(
        slotsById: {for (final id in ids) id: [_slot(dayKey(1), '09:00')]},
      );

      await pumpFind(
        tester,
        therapists: [for (final id in ids) _therapist(id)],
        repository: repository,
        // A phone's *height*, so only a handful of cards are built.
        size: const Size(560, 700),
      );

      expect(repository.requestedIds, isNotEmpty);
      // Three of twenty, in a single batch, at the time of writing — the exact
      // number follows the cache extent, so the assertion is "well under half"
      // rather than a magic constant it would be tempting to update.
      expect(
        repository.requestedIds.length,
        lessThan(ids.length ~/ 2),
        reason:
            'The list fetched ${repository.requestedIds.length} of '
            '${ids.length} therapists before the reader had scrolled to them, '
            'which is the N+1 this layer exists to avoid.',
      );
      expect(repository.batches.length, 1);

      // Scrolling reveals more, and asks only for what it revealed — no id is
      // ever fetched twice.
      await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(repository.requestedIds.length, greaterThan(3));
      expect(
        repository.requestedIds.length,
        repository.requestedIds.toSet().length,
        reason: 'A therapist was asked about more than once.',
      );
    });

    testWidgets('applying the filter reuses what the cards already fetched', (
      tester,
    ) async {
      final repository = _CountingRepository(
        slotsById: {
          'a': [_slot(dayKey(1), '09:00')],
          'b': [_slot(dayKey(1), '14:00')],
        },
      );
      final container = await pumpFind(
        tester,
        therapists: [_therapist('a'), _therapist('b')],
        repository: repository,
      );

      final before = repository.batches.length;
      container.read(availabilityFilterProvider.notifier).state =
          AvailabilityFilter(date: dayKey(1), window: SlotWindow.morning);
      await tester.pumpAndSettle();

      // The horizon the cards fetched already covers every day the filter can
      // ask about, so changing the date is free.
      expect(repository.batches.length, before);
      expect(find.text('Dr. a'), findsOneWidget);
      expect(find.text('Dr. b'), findsNothing);
    });
  });

  group('the availability filter', () {
    testWidgets('keeps only therapists open in the chosen window', (
      tester,
    ) async {
      final repository = _CountingRepository(
        slotsById: {
          'morning': [_slot(dayKey(2), '10:00')],
          'afternoon': [_slot(dayKey(2), '15:00')],
          'otherday': [_slot(dayKey(3), '10:00')],
        },
      );

      await pumpFind(
        tester,
        therapists: [
          _therapist('morning'),
          _therapist('afternoon'),
          _therapist('otherday'),
        ],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(2),
          window: SlotWindow.morning,
        ),
      );

      expect(find.text('Dr. morning'), findsOneWidget);
      expect(find.text('Dr. afternoon'), findsNothing);
      expect(find.text('Dr. otherday'), findsNothing);
    });

    testWidgets('keeps a slot sitting exactly on either boundary', (
      tester,
    ) async {
      const window = SlotWindow(fromMinutes: 14 * 60, toMinutes: 16 * 60);
      final repository = _CountingRepository(
        slotsById: {
          'atstart': [_slot(dayKey(2), '14:00')],
          'atend': [_slot(dayKey(2), '16:00')],
          'justbefore': [_slot(dayKey(2), '13:59')],
          'justafter': [_slot(dayKey(2), '16:01')],
        },
      );

      await pumpFind(
        tester,
        therapists: [
          _therapist('atstart'),
          _therapist('atend'),
          _therapist('justbefore'),
          _therapist('justafter'),
        ],
        repository: repository,
        filter: AvailabilityFilter(date: dayKey(2), window: window),
      );

      expect(find.text('Dr. atstart'), findsOneWidget);
      expect(find.text('Dr. atend'), findsOneWidget);
      expect(find.text('Dr. justbefore'), findsNothing);
      expect(find.text('Dr. justafter'), findsNothing);
    });

    testWidgets('nobody free is an answer, not an error', (tester) async {
      final repository = _CountingRepository(
        slotsById: {'a': [_slot(dayKey(2), '09:00')]},
      );

      await pumpFind(
        tester,
        therapists: [_therapist('a')],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(2),
          window: SlotWindow.evening,
        ),
      );

      expect(find.text('Nobody free then'), findsOneWidget);
      expect(
        find.text(
          'No therapist has a slot open in that window. Try another day, '
          'or a wider time.',
        ),
        findsOneWidget,
      );
      // Not the search-came-back-empty state, which means something else.
      expect(find.text('No therapists match that filter yet.'), findsNothing);
    });

    testWidgets('a therapist we could not check is reported, not hidden', (
      tester,
    ) async {
      final repository = _CountingRepository(
        slotsById: {'ok': [_slot(dayKey(2), '10:00')]},
        failFor: {'bad'},
      );

      await pumpFind(
        tester,
        therapists: [_therapist('ok'), _therapist('bad')],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(2),
          window: SlotWindow.morning,
        ),
      );

      expect(find.text('Dr. ok'), findsOneWidget);
      expect(find.text('Dr. bad'), findsNothing);
      // Left out of the list, but said out loud rather than silently dropped.
      expect(find.text('Could not check 1 therapist'), findsOneWidget);
    });

    testWidgets('the search empty state still wins over the filter one', (
      tester,
    ) async {
      final repository = _CountingRepository();

      await pumpFind(
        tester,
        therapists: const [],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(2),
          window: SlotWindow.morning,
        ),
      );

      expect(find.text('No therapists match that filter yet.'), findsOneWidget);
      expect(find.text('Nobody free then'), findsNothing);
    });
  });

  group('the filter sheet', () {
    testWidgets('opens from the pill and narrows the list on Show', (
      tester,
    ) async {
      final repository = _CountingRepository(
        slotsById: {
          'morning': [_slot(dayKey(0), '10:00')],
          'evening': [_slot(dayKey(0), '18:00')],
        },
      );

      await pumpFind(
        tester,
        therapists: [_therapist('morning'), _therapist('evening')],
        repository: repository,
      );

      // The pill reads "Any time" until something is picked.
      expect(find.text('Any time'), findsOneWidget);
      await tester.tap(find.text('Any time'));
      await tester.pumpAndSettle();

      expect(find.text('When are you free?'), findsOneWidget);
      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show therapists'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. morning'), findsOneWidget);
      expect(find.text('Dr. evening'), findsNothing);
      // And the pill now says what it is filtering on.
      expect(find.text('Today · Morning'), findsOneWidget);
    });

    testWidgets('Clear puts the whole list back', (tester) async {
      final repository = _CountingRepository(
        slotsById: {
          'morning': [_slot(dayKey(0), '10:00')],
          'evening': [_slot(dayKey(0), '18:00')],
        },
      );

      await pumpFind(
        tester,
        therapists: [_therapist('morning'), _therapist('evening')],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(0),
          window: SlotWindow.morning,
        ),
      );

      expect(find.text('Dr. evening'), findsNothing);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. morning'), findsOneWidget);
      expect(find.text('Dr. evening'), findsOneWidget);
      expect(find.text('Any time'), findsOneWidget);
    });

    testWidgets('dismissing the sheet leaves the filter alone', (tester) async {
      final repository = _CountingRepository(
        slotsById: {
          'morning': [_slot(dayKey(0), '10:00')],
          'evening': [_slot(dayKey(0), '18:00')],
        },
      );

      await pumpFind(
        tester,
        therapists: [_therapist('morning'), _therapist('evening')],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(0),
          window: SlotWindow.morning,
        ),
      );

      await tester.tap(find.text('Today · Morning'));
      await tester.pumpAndSettle();
      expect(find.text('When are you free?'), findsOneWidget);

      // Swiped away rather than answered.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Today · Morning'), findsOneWidget);
      expect(find.text('Dr. evening'), findsNothing);
    });
  });

  group('in Nepali', () {
    final ne = AppLocalizationsNe();

    testWidgets('the filter and the free-slot line read through the ARB', (
      tester,
    ) async {
      final repository = _CountingRepository(
        slotsById: {
          'a': [_slot(dayKey(1), '09:00')],
          'b': const [],
        },
        failFor: {'c'},
      );

      await pumpFind(
        tester,
        therapists: [_therapist('a'), _therapist('b'), _therapist('c')],
        repository: repository,
        locale: const Locale('ne'),
      );

      expectNoEnglish(tester, const [
        'Any time',
        'Checking availability…',
        'Tap to see availability',
      ]);
      expect(find.text(ne.findWindowAnyTime), findsOneWidget);
      expect(
        find.text(ne.findNoFreeSlots(availabilityHorizonDays)),
        findsOneWidget,
      );
      expect(find.text(ne.findAvailabilityUnknown), findsOneWidget);
    });

    testWidgets('so does the empty state when nobody is free', (tester) async {
      final repository = _CountingRepository(
        slotsById: {'a': [_slot(dayKey(2), '09:00')]},
      );

      await pumpFind(
        tester,
        therapists: [_therapist('a')],
        repository: repository,
        filter: AvailabilityFilter(
          date: dayKey(2),
          window: SlotWindow.evening,
        ),
        locale: const Locale('ne'),
      );

      expect(find.text(ne.findNoneFreeTitle), findsOneWidget);
      expectNoEnglish(tester, const ['Nobody free then']);
    });
  });
}
