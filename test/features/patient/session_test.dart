import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/session_models.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';

void main() {
  group('SessionStatus', () {
    test('maps every backend value', () {
      expect(SessionStatus.fromWire('SCHEDULED'), SessionStatus.scheduled);
      expect(SessionStatus.fromWire('IN_PROGRESS'), SessionStatus.inProgress);
      expect(SessionStatus.fromWire('COMPLETED'), SessionStatus.completed);
      expect(SessionStatus.fromWire('CANCELLED'), SessionStatus.cancelled);
      expect(
        SessionStatus.fromWire('RESCHEDULE_REQUESTED'),
        SessionStatus.rescheduleRequested,
      );
      expect(
        SessionStatus.fromWire('DECLINE_REQUESTED'),
        SessionStatus.declineRequested,
      );
    });

    test('an unrecognised value degrades instead of throwing', () {
      expect(SessionStatus.fromWire('SOMETHING_NEW'), SessionStatus.unknown);
      expect(SessionStatus.fromWire(null), SessionStatus.unknown);
    });

    test('only a scheduled session can be moved or cancelled', () {
      expect(SessionStatus.scheduled.canReschedule, isTrue);
      expect(SessionStatus.scheduled.canCancel, isTrue);
      expect(SessionStatus.completed.canReschedule, isFalse);
      expect(SessionStatus.cancelled.canCancel, isFalse);
    });

    test('tab grouping is mutually exclusive', () {
      for (final status in SessionStatus.values) {
        final flags = [status.isUpcoming, status.isPast, status.isCancelled]
            .where((f) => f)
            .length;
        expect(flags, lessThanOrEqualTo(1), reason: '$status is in two tabs');
      }
    });
  });

  group('SessionDto', () {
    test('parses a session and fills the empty relation fields', () {
      final dto = SessionDto.fromJson({
        'id': 'ses_1',
        'therapistId': 'thp_1',
        'therapistName': '',
        'patientId': 'usr_1',
        'patientName': '',
        'patientPhone': '',
        'date': '2026-08-21T09:00:00+00:00',
        'time': '09:00',
        'type': 'HOME_VISIT',
        'status': 'SCHEDULED',
        'address': 'Kupondole, Lalitpur',
        'fee': 1500,
        'notes': null,
      });

      final session = dto.toEntity();
      expect(session.status, SessionStatus.scheduled);
      expect(session.isHomeVisit, isTrue);
      expect(session.fee, 1500.0);
      expect(session.dateKey, '2026-08-21');
    });

    test('accepts a date sent as a bare day string', () {
      final dto = SessionDto.fromJson({
        'id': 'ses_2',
        'therapistId': 'thp_1',
        'patientId': 'usr_1',
        'date': '2026-08-21',
        'time': '09:00',
        'type': 'CLINIC',
        'status': 'COMPLETED',
        'fee': 1200.5,
      });

      expect(dto.toEntity().dateKey, '2026-08-21');
      expect(dto.toEntity().isHomeVisit, isFalse);
    });
  });

  group('TherapistDto', () {
    test('maps price to fee and reviews to a count', () {
      final therapist = TherapistDto.fromJson({
        'id': 'thp_1',
        'userId': 'usr_9',
        'name': 'Dr. Anisha Shrestha',
        'specialty': 'Sports & post-surgery',
        'city': 'Lalitpur',
        'gender': 'Female',
        'rating': 4.9,
        'reviews': 182,
        'price': 1500,
        'experience': 6,
        'bio': 'BPT, IOM (2018).',
      }).toEntity();

      expect(therapist.fee, 1500.0);
      expect(therapist.reviewCount, 182);
      expect(therapist.isRated, isTrue);
      // The honorific is dropped so the avatar does not read "DA".
      expect(therapist.initials, 'AS');
    });

    test('an unrated therapist is flagged rather than shown as zero', () {
      final therapist = TherapistDto.fromJson({
        'id': 'thp_2',
        'userId': 'usr_10',
        'name': 'Prakash Lama',
        'specialty': 'Musculoskeletal',
        'city': 'Kathmandu',
        'gender': 'Male',
        'rating': 0,
        'reviews': 0,
        'price': 1300,
        'experience': 3,
        'bio': '',
      }).toEntity();

      expect(therapist.isRated, isFalse);
      expect(therapist.initials, 'PL');
    });
  });

  group('BookingPaymentRequestDto', () {
    test('sends camelCase keys and omits nulls', () {
      final json = BookingPaymentRequestDto(
        therapistId: 'thp_1',
        date: DateTime.utc(2026, 8, 21, 9),
        time: '09:00',
        address: 'Kupondole, Lalitpur',
        fee: 1500,
        paymentMethod: 'ESEWA',
      ).toJson();

      expect(json['therapistId'], 'thp_1');
      expect(json['paymentMethod'], 'ESEWA');
      expect(json.containsKey('notes'), isFalse);
      expect(json['date'], contains('2026-08-21'));
    });
  });

  group('SlotDto', () {
    test('only "open" counts as bookable', () {
      SlotDto slot(String status) => SlotDto.fromJson({
            'date': '2026-08-21',
            'time': '09:00',
            'status': status,
            'fee': 1500,
          });

      expect(slot('open').isOpen, isTrue);
      expect(slot('booked').isOpen, isFalse);
      expect(slot('off').isOpen, isFalse);
    });
  });

  group('tab grouping is date-aware, not status-only', () {
    Session at(DateTime date, SessionStatus status) => Session(
          id: 's',
          therapistId: 't',
          therapistName: 'Dr. Test',
          patientId: 'p',
          patientName: '',
          patientPhone: '',
          date: date,
          time: '09:00',
          type: 'HOME_VISIT',
          status: status,
          address: 'Lalitpur',
          fee: 1500,
        );

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final lastMonth = now.subtract(const Duration(days: 30));

    test('a future scheduled session is upcoming', () {
      final s = at(tomorrow, SessionStatus.scheduled);
      expect(s.isUpcoming, isTrue);
      expect(s.isPast, isFalse);
      expect(s.canReschedule, isTrue);
      expect(s.canCancel, isTrue);
    });

    test('a scheduled session whose date has passed is NOT upcoming', () {
      // The backend leaves these SCHEDULED forever; showing them under
      // "Upcoming" contradicted the dashboard, which counts by date.
      final s = at(lastMonth, SessionStatus.scheduled);
      expect(s.isUpcoming, isFalse);
      expect(s.isPast, isTrue);
    });

    test('an elapsed session offers no reschedule or cancel', () {
      // The API rejects rescheduling into the past, so offering the button
      // could only ever produce an error.
      final s = at(lastMonth, SessionStatus.scheduled);
      expect(s.canReschedule, isFalse);
      expect(s.canCancel, isFalse);
    });

    test("today's session still counts as upcoming", () {
      final s = at(DateTime(now.year, now.month, now.day), SessionStatus.scheduled);
      expect(s.isUpcoming, isTrue);
      expect(s.hasElapsed, isFalse);
    });

    test('a cancelled session stays cancelled whatever its date', () {
      expect(at(lastMonth, SessionStatus.cancelled).isCancelled, isTrue);
      expect(at(tomorrow, SessionStatus.cancelled).isCancelled, isTrue);
      expect(at(tomorrow, SessionStatus.cancelled).isUpcoming, isFalse);
    });

    test('every session lands in exactly one tab', () {
      for (final status in SessionStatus.values) {
        for (final date in [tomorrow, lastMonth]) {
          final s = at(date, status);
          final tabs = [s.isUpcoming, s.isPast, s.isCancelled].where((f) => f).length;
          expect(tabs, lessThanOrEqualTo(1),
              reason: '$status on $date appears in more than one tab');
        }
      }
    });
  });
}
