import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/entities/working_hours.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_availability_screen.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_en.dart';

import '../../l10n_harness.dart';
import 'availability_fakes.dart';

void main() {
  final en = AppLocalizationsEn();

  Future<FakeAvailabilityRepository> pumpScreen(
    WidgetTester tester, {
    FakeAvailabilityRepository? repository,
    List<dynamic> sessions = const [],
    Size size = const Size(390, 844),
  }) async {
    final repo = repository ?? FakeAvailabilityRepository();
    await pumpLocalized(
      tester,
      const TherapistAvailabilityScreen(),
      size: size,
      overrides: availabilityOverrides(
        repository: repo,
        sessions: sessions.cast(),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  /// Taps Save, scrolling it into view first.
  ///
  /// The error banner makes the page taller, so on a 390x844 viewport the
  /// button can end up below the fold after a failed attempt — and a tap that
  /// lands outside the viewport is silently a no-op.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  /// The chip is a plain container; its fill is what says "selected".
  bool chipIsOn(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    return decoration.color != const Color(0xFFFFFFFF);
  }

  group('what the screen opens on', () {
    testWidgets('the pattern the server holds, not an invented one', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        repository: FakeAvailabilityRepository(
          stored: const WorkingHours(
            days: {Weekday.saturday, Weekday.sunday},
            startMinutes: 14 * 60,
            endMinutes: 18 * 60,
            sessionMinutes: 45,
          ),
        ),
      );

      // A weekend therapist sees their weekend, not the Mon–Fri default the
      // prototype hardcoded.
      expect(chipIsOn(tester, en.dayShortSat), isTrue);
      expect(chipIsOn(tester, en.dayShortSun), isTrue);
      expect(chipIsOn(tester, en.dayShortMon), isFalse);
      expect(find.text('2:00 PM'), findsOneWidget);
      expect(find.text('6:00 PM'), findsOneWidget);
      expect(chipIsOn(tester, en.availabilitySessionMinutes(45)), isTrue);
    });

    testWidgets('and says so — Saved, until something is touched', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text(en.availabilityStatusSaved), findsOneWidget);
      expect(find.text(en.availabilityStatusUnsaved), findsNothing);

      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();

      expect(find.text(en.availabilityStatusUnsaved), findsOneWidget);
    });

    testWidgets('a failed read is an error state, not a silent default', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        repository: FakeAvailabilityRepository(
          readFailure: const ServerFailure('Server error'),
        ),
      );

      expect(find.text(en.errorTitleGeneric), findsOneWidget);
      expect(find.text(en.availabilitySave), findsNothing);
    });
  });

  group('the chips are actually tappable', () {
    testWidgets('which the prototype\'s were not', (tester) async {
      // `_selectedDays` used to be a `static const` set and the chips were
      // bare Containers with no gesture handler at all.
      final repo = await pumpScreen(tester);

      expect(chipIsOn(tester, en.dayShortSat), isFalse);
      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();
      expect(chipIsOn(tester, en.dayShortSat), isTrue);

      await tester.tap(find.text(en.dayShortMon));
      await tester.pump();
      expect(chipIsOn(tester, en.dayShortMon), isFalse);

      await tester.tap(find.text(en.availabilitySessionMinutes(30)));
      await tester.pump();

      await tapSave(tester);

      final sent = repo.saved.single;
      expect(sent.days, {
        Weekday.tuesday,
        Weekday.wednesday,
        Weekday.thursday,
        Weekday.friday,
        Weekday.saturday,
      });
      expect(sent.sessionMinutes, 30);
    });
  });

  group('saving', () {
    testWidgets('is off until something has changed', (tester) async {
      await pumpScreen(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNull,
        reason: 'nothing has been edited, so there is nothing to save',
      );

      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('says so, with the count the server reported', (tester) async {
      final repo = await pumpScreen(
        tester,
        repository: FakeAvailabilityRepository(openedSlots: 45),
      );

      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();
      await tapSave(tester);

      expect(repo.saved, hasLength(1));
      expect(find.text(en.availabilitySaveSuccess(45)), findsOneWidget);
      // And the pill agrees: it flipped only after the server answered.
      expect(find.text(en.availabilityStatusSaved), findsOneWidget);
    });

    testWidgets('waits for the server rather than pretending', (tester) async {
      // No optimistic update. While the write is in flight the pill still
      // reads "not saved yet", because at that moment it is not.
      final gate = Completer<void>();
      final repo = FakeAvailabilityRepository()..gate = gate;
      await pumpScreen(tester, repository: repo);

      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();
      await tester.tap(find.text(en.availabilitySave));
      await tester.pump();

      expect(find.text(en.availabilitySaving), findsOneWidget);
      expect(find.text(en.availabilitySavingNote), findsOneWidget);
      expect(find.text(en.availabilityStatusUnsaved), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(en.availabilityStatusSaved), findsOneWidget);
    });
  });

  group('a failed save', () {
    testWidgets('leaves every edit on screen, ready to retry', (tester) async {
      final repo = FakeAvailabilityRepository(
        saveFailure: const ServerUnavailableFailure(),
      );
      await pumpScreen(tester, repository: repo);

      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();
      await tester.tap(find.text(en.dayShortMon));
      await tester.pump();
      await tester.tap(find.text(en.availabilitySessionMinutes(90)));
      await tester.pump();

      await tapSave(tester);

      // Said out loud, twice — a banner that stays and a snackbar.
      expect(find.text(en.availabilitySaveFailed), findsWidgets);
      expect(find.text('Cannot reach the server right now.'), findsOneWidget);

      // And every edit survived. This is the whole point: a therapist who
      // retoggled five chips must not have to do it again.
      expect(chipIsOn(tester, en.dayShortSat), isTrue);
      expect(chipIsOn(tester, en.dayShortMon), isFalse);
      expect(chipIsOn(tester, en.availabilitySessionMinutes(90)), isTrue);
      expect(find.text(en.availabilityStatusUnsaved), findsOneWidget);

      // Retry is live again, and a second attempt sends the same pattern.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      // Let the error snackbar time out first — it sits over the bottom of
      // the screen, which is where the button is.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      repo.saveFailure = null;
      await tapSave(tester);

      expect(repo.saved, hasLength(2));
      expect(repo.saved.first, repo.saved.last);
      expect(find.text(en.availabilityStatusSaved), findsOneWidget);
    });

    testWidgets('and the banner clears as soon as the pattern changes', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        repository: FakeAvailabilityRepository(
          saveFailure: const ServerFailure('Server error'),
        ),
      );

      await tester.tap(find.text(en.dayShortSat));
      await tester.pump();
      await tapSave(tester);
      expect(find.text(en.availabilitySaveFailed), findsWidgets);

      // The banner describes the attempt that failed, not the pattern now on
      // screen, so editing retires it.
      await tester.tap(find.text(en.dayShortSun));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(en.availabilitySaveFailed),
        ),
        findsNothing,
      );
    });
  });

  group('what the screen refuses to send', () {
    testWidgets('an empty week, with the leave flow offered instead', (
      tester,
    ) async {
      final repo = await pumpScreen(tester);

      for (final day in [
        en.dayShortMon,
        en.dayShortTue,
        en.dayShortWed,
        en.dayShortThu,
        en.dayShortFri,
      ]) {
        await tester.tap(find.text(day));
        await tester.pump();
      }

      expect(find.text(en.availabilityProblemNoDays), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repo.saved, isEmpty);
      // The alternative is on screen, not just implied by the refusal.
      expect(find.text(en.availabilityDayOffLink), findsOneWidget);
    });

    testWidgets('a session longer than the working day', (tester) async {
      final repo = await pumpScreen(
        tester,
        repository: FakeAvailabilityRepository(
          stored: const WorkingHours(
            days: {Weekday.monday},
            startMinutes: 9 * 60,
            endMinutes: 10 * 60,
            sessionMinutes: 60,
          ),
        ),
      );

      await tester.tap(find.text(en.availabilitySessionMinutes(90)));
      await tester.pump();

      expect(find.text(en.availabilityProblemSessionTooLong), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repo.saved, isEmpty);
    });
  });

  group('context the therapist needs before tapping save', () {
    testWidgets('how many appointments a day now holds', (tester) async {
      await pumpScreen(tester);
      // 09:00–18:00 at 60 minutes.
      expect(find.text(en.availabilitySlotsPerDay(9)), findsOneWidget);

      await tester.tap(find.text(en.availabilitySessionMinutes(30)));
      await tester.pump();
      expect(find.text(en.availabilitySlotsPerDay(18)), findsOneWidget);
    });

    testWidgets('how far ahead a save reaches', (tester) async {
      await pumpScreen(tester);
      expect(
        find.text(en.availabilityHorizonNote(availabilityWriteHorizonDays)),
        findsOneWidget,
      );
    });

    testWidgets('and that booked appointments are not disturbed', (
      tester,
    ) async {
      final today = DateTime.now();
      await pumpScreen(
        tester,
        sessions: [
          scheduledSession(date: today.add(const Duration(days: 2))),
          scheduledSession(date: today.add(const Duration(days: 5))),
          // Outside the window a save rewrites, so not counted.
          scheduledSession(date: today.add(const Duration(days: 40))),
        ],
      );

      expect(find.text(en.availabilityBookedKept(2)), findsOneWidget);
    });

    testWidgets('the line is absent rather than zero when nothing is booked', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text(en.availabilityBookedKept(0)), findsNothing);
    });
  });
}
