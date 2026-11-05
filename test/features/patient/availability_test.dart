import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/utils/formatters.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/availability.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/widgets/next_free_slot_line.dart';

TherapistSlot _slot(String date, String time) =>
    TherapistSlot(date: date, time: time, isOpen: true);

Therapist _therapist(
  String id, {
  ListingType listingType = ListingType.bookable,
}) => Therapist(
  id: id,
  userId: 'u-$id',
  name: 'Dr. $id',
  specialty: 'Sports',
  city: 'Lalitpur',
  gender: 'Female',
  rating: 4.5,
  reviewCount: 10,
  fee: 1500,
  experienceYears: 5,
  bio: '',
  listingType: listingType,
);

void main() {
  group('SlotWindow boundaries', () {
    const window = SlotWindow(fromMinutes: 14 * 60, toMinutes: 16 * 60);

    test('a slot exactly at the window start is in', () {
      expect(window.containsTime('14:00'), isTrue);
    });

    test('a slot exactly at the window end is in', () {
      // Both ends inclusive. Someone who asks "can anyone see me between 2
      // and 4" is being offered the 4 o'clock slot as an answer, not having
      // it withheld because the session would run past 4.
      expect(window.containsTime('16:00'), isTrue);
    });

    test('one minute either side is out', () {
      expect(window.containsTime('13:59'), isFalse);
      expect(window.containsTime('16:01'), isFalse);
    });

    test('any time covers the whole clock', () {
      expect(SlotWindow.anyTime.containsTime('00:00'), isTrue);
      expect(SlotWindow.anyTime.containsTime('23:59'), isTrue);
    });

    test('the presets abut rather than leaving a gap', () {
      // A 12:00 slot answers both "morning" and "afternoon". Overlapping is
      // the safe direction to be wrong in: a slot shown twice costs a glance,
      // a slot shown nowhere costs a booking.
      expect(SlotWindow.morning.containsTime('12:00'), isTrue);
      expect(SlotWindow.afternoon.containsTime('12:00'), isTrue);
      expect(SlotWindow.afternoon.containsTime('17:00'), isTrue);
      expect(SlotWindow.evening.containsTime('17:00'), isTrue);
    });

    test('a malformed time is never in a window', () {
      expect(SlotWindow.anyTime.containsTime(''), isFalse);
      expect(SlotWindow.anyTime.containsTime('noon'), isFalse);
      expect(SlotWindow.anyTime.containsTime('25:00'), isFalse);
    });
  });

  group('AvailabilityFilter', () {
    const filter = AvailabilityFilter(
      date: '2026-09-17',
      window: SlotWindow(fromMinutes: 14 * 60, toMinutes: 16 * 60),
    );

    test('matches a slot on the right day inside the window', () {
      expect(filter.isSatisfiedBy([_slot('2026-09-17', '15:00')]), isTrue);
    });

    test('matches on both boundaries', () {
      expect(filter.isSatisfiedBy([_slot('2026-09-17', '14:00')]), isTrue);
      expect(filter.isSatisfiedBy([_slot('2026-09-17', '16:00')]), isTrue);
    });

    test('rejects the right time on the wrong day', () {
      expect(filter.isSatisfiedBy([_slot('2026-09-18', '15:00')]), isFalse);
    });

    test('rejects the right day outside the window', () {
      expect(filter.isSatisfiedBy([_slot('2026-09-17', '09:00')]), isFalse);
    });

    test('an empty calendar satisfies nothing', () {
      expect(filter.isSatisfiedBy(const []), isFalse);
    });
  });

  group('nextFreeSlot', () {
    final now = DateTime(2026, 9, 12, 14, 30);

    test('picks the earliest slot still to come', () {
      final slot = nextFreeSlot([
        _slot('2026-09-14', '09:00'),
        _slot('2026-09-12', '16:00'),
        _slot('2026-09-13', '09:00'),
      ], now);
      expect(slot?.date, '2026-09-12');
      expect(slot?.time, '16:00');
    });

    test('skips slots that have already gone by today', () {
      // A card reading "Free today 9:00 AM" at half past two is worse than no
      // card: the API would refuse the booking anyway.
      final slot = nextFreeSlot([
        _slot('2026-09-12', '09:00'),
        _slot('2026-09-12', '15:00'),
      ], now);
      expect(slot?.time, '15:00');
    });

    test('a slot at exactly now still counts', () {
      final slot = nextFreeSlot([
        _slot('2026-09-12', '14:30'),
      ], now);
      expect(slot?.time, '14:30');
    });

    test('returns null when everything is in the past', () {
      expect(nextFreeSlot([_slot('2026-09-11', '09:00')], now), isNull);
    });

    test('returns null for an empty calendar', () {
      expect(nextFreeSlot(const [], now), isNull);
    });

    test('ignores a slot it cannot parse rather than throwing', () {
      final slot = nextFreeSlot([
        _slot('not-a-date', '09:00'),
        _slot('2026-09-13', 'noon'),
        _slot('2026-09-13', '11:00'),
      ], now);
      expect(slot?.time, '11:00');
    });
  });

  group('nextFreeSlotLabel', () {
    final l10n = englishL10n;
    final now = DateTime(2026, 9, 12, 8, 0); // a Saturday

    String labelFor(List<TherapistSlot> slots) =>
        nextFreeSlotLabel(SlotLookupLoaded(slots), l10n, now: now);

    test('today', () {
      expect(labelFor([_slot('2026-09-12', '14:00')]), 'Free today · 2:00 PM');
    });

    test('tomorrow', () {
      expect(
        labelFor([_slot('2026-09-13', '09:00')]),
        'Free tomorrow · 9:00 AM',
      );
    });

    test('later this week names the weekday', () {
      // 17 September 2026 is a Thursday, five days out.
      expect(labelFor([_slot('2026-09-17', '14:00')]), 'Free Thu · 2:00 PM');
    });

    test('further out names the date, because a weekday would be ambiguous', () {
      expect(labelFor([_slot('2026-09-24', '09:00')]), 'Free 24 Sep · 9:00 AM');
    });

    test('a checked but empty calendar says so, with the horizon', () {
      expect(
        labelFor(const []),
        'No free slots in the next $availabilityHorizonDays days',
      );
    });

    test('not yet asked reads as checking, never as unavailable', () {
      const checking = 'Checking availability…';
      expect(
        nextFreeSlotLabel(const SlotLookupUnknown(), l10n, now: now),
        checking,
      );
      expect(
        nextFreeSlotLabel(const SlotLookupPending(), l10n, now: now),
        checking,
      );
    });

    test('a failed lookup points at the profile rather than claiming busy', () {
      final label = nextFreeSlotLabel(
        const SlotLookupFailed(NetworkFailure()),
        l10n,
        now: now,
      );
      expect(label, 'Tap to see availability');
      // The distinction the whole feature rests on: an unknown calendar must
      // not render as the answer a known-empty one does.
      expect(label, isNot(labelFor(const [])));
    });
  });

  group('partitionByAvailability', () {
    const filter = AvailabilityFilter(
      date: '2026-09-17',
      window: SlotWindow.afternoon,
    );

    test('splits matched, still-asking and could-not-ask', () {
      final partition = partitionByAvailability(
        therapists: [
          _therapist('free'),
          _therapist('busy'),
          _therapist('pending'),
          _therapist('failed'),
          _therapist('untouched'),
        ],
        lookups: {
          'free': SlotLookupLoaded([_slot('2026-09-17', '14:00')]),
          'busy': SlotLookupLoaded([_slot('2026-09-17', '09:00')]),
          'pending': const SlotLookupPending(),
          'failed': const SlotLookupFailed(NetworkFailure()),
        },
        filter: filter,
      );

      expect(partition.matching.map((t) => t.id), ['free']);
      expect(partition.pending.map((t) => t.id), ['pending', 'untouched']);
      expect(partition.unchecked.map((t) => t.id), ['failed']);
      expect(partition.isSettled, isFalse);
      expect(partition.isDefinitelyEmpty, isFalse);
    });

    test('an information-only listing is dropped without being looked up', () {
      final partition = partitionByAvailability(
        therapists: [_therapist('clinic', listingType: ListingType.infoOnly)],
        lookups: const {},
        filter: filter,
      );
      expect(partition.matching, isEmpty);
      expect(partition.pending, isEmpty);
      expect(partition.unchecked, isEmpty);
      expect(partition.isDefinitelyEmpty, isTrue);
    });

    test('everyone checked and nobody free is a settled, definite empty', () {
      final partition = partitionByAvailability(
        therapists: [_therapist('a'), _therapist('b')],
        lookups: {
          'a': const SlotLookupLoaded([]),
          'b': SlotLookupLoaded([_slot('2026-09-17', '09:00')]),
        },
        filter: filter,
      );
      expect(partition.isDefinitelyEmpty, isTrue);
      expect(partition.isSettled, isTrue);
    });

    test('a failure is never a definite empty — we simply do not know', () {
      final partition = partitionByAvailability(
        therapists: [_therapist('a')],
        lookups: const {'a': SlotLookupFailed(NetworkFailure())},
        filter: filter,
      );
      expect(partition.matching, isEmpty);
      expect(partition.isDefinitelyEmpty, isFalse);
    });
  });

  group('formatSlotTime', () {
    final l10n = englishL10n;

    test('spells a 24-hour slot the way a reader says it', () {
      expect(formatSlotTime('09:00', l10n), '9:00 AM');
      expect(formatSlotTime('14:30', l10n), '2:30 PM');
      expect(formatSlotTime('00:00', l10n), '12:00 AM');
      expect(formatSlotTime('12:00', l10n), '12:00 PM');
    });

    test('passes anything it cannot parse straight through', () {
      expect(formatSlotTime('', l10n), '');
      expect(formatSlotTime('later', l10n), 'later');
      expect(formatSlotTime('25:00', l10n), '25:00');
    });
  });

  group('parseSlotMinutes', () {
    test('reads wall-clock strings with no timezone applied', () {
      // The API sends bare HH:MM with no offset and every other screen renders
      // it as it arrives. Nothing here may shift the hour.
      expect(parseSlotMinutes('00:00'), 0);
      expect(parseSlotMinutes('09:30'), 570);
      expect(parseSlotMinutes('23:59'), 1439);
    });

    test('rejects what is not a clock time', () {
      expect(parseSlotMinutes('24:00'), isNull);
      expect(parseSlotMinutes('09:60'), isNull);
      expect(parseSlotMinutes('9'), isNull);
      expect(parseSlotMinutes(''), isNull);
    });

    test('round-trips through formatSlotMinutes', () {
      for (final time in ['00:00', '09:00', '13:45', '23:59']) {
        expect(formatSlotMinutes(parseSlotMinutes(time)!), time);
      }
    });
  });
}
