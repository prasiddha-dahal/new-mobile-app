import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/entities/working_hours.dart';

void main() {
  group('Weekday', () {
    test('spells days the way the API does, Sunday first', () {
      expect(Weekday.values.map((d) => d.wireValue), [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ]);
      expect(Weekday.sunday.sundayIndex, 0);
      expect(Weekday.saturday.sundayIndex, 6);
    });

    test('maps a date the same way the server does', () {
      // The server does `isoweekday() % 7`, which puts Sunday at 0 while
      // Dart's `DateTime.weekday` puts Monday at 1. Getting this backwards
      // would shift every day off by one, which is the sort of thing that
      // looks fine in a test on a Wednesday.
      expect(Weekday.ofDate(DateTime(2026, 9, 13)), Weekday.sunday);
      expect(Weekday.ofDate(DateTime(2026, 9, 14)), Weekday.monday);
      expect(Weekday.ofDate(DateTime(2026, 9, 19)), Weekday.saturday);
    });

    test('an unknown wire value is dropped, not guessed at', () {
      expect(Weekday.fromWire('Mon'), Weekday.monday);
      expect(Weekday.fromWire('Monday'), isNull);
      expect(Weekday.fromWire(''), isNull);
    });
  });

  group('AvailabilityWindow', () {
    test('covers exactly the range the readers ask about', () {
      // `availabilityHorizonProvider` and `ownSlotsProvider` both send
      // `to_date = today + 14`, inclusive — fifteen dates. Writing fourteen
      // would leave the last column of the patient's calendar showing the
      // pattern that was just replaced.
      final window = AvailabilityWindow.fromDate(DateTime(2026, 9, 12));
      expect(window.fromDate, '2026-09-12');
      expect(window.toDate, '2026-09-26');
      expect(window.dates, hasLength(availabilityWriteHorizonDays + 1));
    });

    test('rolls over a month end', () {
      final window = AvailabilityWindow.fromDate(DateTime(2026, 12, 28));
      expect(window.toDate, '2027-01-11');
    });

    test('drops the time of day', () {
      final window = AvailabilityWindow.fromDate(
        DateTime(2026, 9, 12, 23, 59, 59),
      );
      expect(window.from, DateTime(2026, 9, 12));
    });
  });

  group('WorkingHours slot generation', () {
    test('steps by session + break, exactly like the server', () {
      // `_generate_time_slots` in app/services/availability.py is
      // `range(start, end, sessionDuration + breakDuration)` — the end is
      // exclusive, so 09:00–18:00 at 60 minutes is nine slots ending at 17:00.
      const hours = WorkingHours(
        days: {Weekday.monday},
        startMinutes: 9 * 60,
        endMinutes: 18 * 60,
        sessionMinutes: 60,
      );
      expect(hours.slotTimes, [
        '09:00',
        '10:00',
        '11:00',
        '12:00',
        '13:00',
        '14:00',
        '15:00',
        '16:00',
        '17:00',
      ]);
      expect(hours.slotsPerDay, 9);
    });

    test('a break widens the step and thins the day', () {
      const hours = WorkingHours(
        days: {Weekday.monday},
        startMinutes: 9 * 60,
        endMinutes: 12 * 60,
        sessionMinutes: 45,
        breakMinutes: 15,
      );
      expect(hours.slotTimes, ['09:00', '10:00', '11:00']);
    });

    test('counts a week, not just a day', () {
      const hours = WorkingHours(
        days: {Weekday.monday, Weekday.wednesday, Weekday.friday},
        startMinutes: 10 * 60,
        endMinutes: 14 * 60,
        sessionMinutes: 60,
      );
      expect(hours.slotsPerDay, 4);
      expect(hours.slotsPerWeek, 12);
    });
  });

  group('WorkingHours refuses what the API would silently mangle', () {
    const base = WorkingHours(
      days: {Weekday.monday},
      startMinutes: 9 * 60,
      endMinutes: 17 * 60,
      sessionMinutes: 60,
    );

    test('no days at all', () {
      // The API takes it and writes `off` across the whole fortnight. That is
      // a real thing to want, but not one anybody expresses by clearing every
      // chip, so it is refused and the leave flow is offered instead.
      expect(
        base.copyWith(days: const <Weekday>{}).problem,
        WorkingHoursProblem.noDays,
      );
    });

    test('end at or before start', () {
      expect(
        base.copyWith(endMinutes: 9 * 60).problem,
        WorkingHoursProblem.endNotAfterStart,
      );
      expect(
        base.copyWith(endMinutes: 8 * 60).problem,
        WorkingHoursProblem.endNotAfterStart,
      );
    });

    test('a session longer than the working day', () {
      // `range(540, 600, 90)` is `[540]` server-side: one slot, published at
      // 09:00, running to 10:30 — half an hour past the finishing time the
      // therapist just set.
      expect(
        base.copyWith(endMinutes: 10 * 60, sessionMinutes: 90).problem,
        WorkingHoursProblem.sessionLongerThanDay,
      );
    });

    test('and an unsavable pattern publishes no slot times at all', () {
      expect(base.copyWith(endMinutes: 9 * 60).slotTimes, isEmpty);
    });

    test('a session exactly as long as the day is fine', () {
      final exact = base.copyWith(endMinutes: 10 * 60, sessionMinutes: 60);
      expect(exact.problem, isNull);
      expect(exact.slotTimes, ['09:00']);
    });
  });

  group('WorkingHours.fromWire', () {
    test('reads what GET /availability/working-hours returns', () {
      final hours = WorkingHours.fromWire(
        start: '09:00',
        end: '18:00',
        sessionMinutes: 60,
        breakMinutes: 0,
        daysOfWeek: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      );
      expect(hours, WorkingHours.fallback);
    });

    test('one malformed field does not discard the rest of the record', () {
      final hours = WorkingHours.fromWire(
        start: 'half past nine',
        end: '14:00',
        sessionMinutes: 45,
        breakMinutes: 0,
        daysOfWeek: const ['Sat', 'Sun'],
      );
      expect(hours.startMinutes, WorkingHours.fallback.startMinutes);
      expect(hours.endMinutes, 14 * 60);
      expect(hours.sessionMinutes, 45);
      expect(hours.days, {Weekday.saturday, Weekday.sunday});
    });

    test('an unusable day list falls back rather than closing every day', () {
      // An empty or unrecognised `daysOfWeek` taken literally would show the
      // therapist a week with nothing selected and, if saved, close it.
      final hours = WorkingHours.fromWire(
        start: '09:00',
        end: '18:00',
        sessionMinutes: 60,
        breakMinutes: 0,
        daysOfWeek: const ['Lunes', 'Martes'],
      );
      expect(hours.days, WorkingHours.fallback.days);
    });
  });

  group('equality', () {
    test('is by value, and ignores the order days were added in', () {
      const a = WorkingHours(
        days: {Weekday.monday, Weekday.friday},
        startMinutes: 540,
        endMinutes: 1020,
        sessionMinutes: 60,
      );
      const b = WorkingHours(
        days: {Weekday.friday, Weekday.monday},
        startMinutes: 540,
        endMinutes: 1020,
        sessionMinutes: 60,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // The saved/unsaved pill is driven straight off this, so a difference
      // that did not register would leave the therapist reading "Saved" over
      // a pattern the server has never seen.
      expect(a == b.copyWith(sessionMinutes: 45), isFalse);
      expect(a == b.withDay(Weekday.sunday, true), isFalse);
    });
  });

  group('withDay', () {
    test('adds and removes without mutating the original', () {
      const start = WorkingHours(
        days: {Weekday.monday},
        startMinutes: 540,
        endMinutes: 1020,
        sessionMinutes: 60,
      );
      final added = start.withDay(Weekday.sunday, true);
      expect(added.days, {Weekday.monday, Weekday.sunday});
      expect(start.days, {Weekday.monday});
      expect(added.withDay(Weekday.monday, false).days, {Weekday.sunday});
    });
  });
}
