import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';

void main() {
  group('TherapistDashboardDto', () {
    test('reads the dashboard, including the oddly-named patient field', () {
      final dto = TherapistDashboardDto.fromJson({
        'name': 'Dr. Anisha Shrestha',
        'sessionsThisWeek': 6,
        'totalPatients': 4,
        'earningsThisMonth': 72000,
        'averageRating': 4.9,
        'todaySessions': [
          {
            'id': 'ses_1',
            'time': '10:00',
            // The field is `patient`, not `patientName`.
            'patient': 'Pranita K.',
            'patientId': 'usr_1',
            'address': 'Pulchowk',
            'type': 'HOME_VISIT',
            'status': 'SCHEDULED',
          },
        ],
        'referralCode': 'SAH-ANISHA-88',
      });

      expect(dto.totalPatients, 4);
      expect(dto.earningsThisMonth, 72000.0);
      expect(dto.todaySessions.single.patient, 'Pranita K.');
    });

    test('tolerates a sparse dashboard', () {
      final dto = TherapistDashboardDto.fromJson(const {});
      expect(dto.todaySessions, isEmpty);
      expect(dto.averageRating, 0);
    });
  });

  group('PayoutDto', () {
    test('status is title case, unlike every other status in the API', () {
      final paid = PayoutDto.fromJson({
        'id': 'payout-2026-07',
        'month': '2026-07',
        'earnings': 72000,
        'sessions': 48,
        'status': 'Completed',
      });
      final pending = PayoutDto.fromJson({
        'id': 'payout-2026-08',
        'month': '2026-08',
        'earnings': 18000,
        'sessions': 12,
        'status': 'Pending',
      });

      expect(paid.isPaid, isTrue);
      expect(pending.isPaid, isFalse);
    });
  });

  group('MyPatientDto', () {
    test('an empty last-visit string becomes null, not epoch zero', () {
      final never = MyPatientDto.fromJson({
        'id': 'usr_1',
        'name': 'Pranita K.',
        'phone': '',
        'condition': 'Lower back pain',
        'sessions': 4,
        'last': '',
      });
      final visited = MyPatientDto.fromJson({
        'id': 'usr_2',
        'name': 'Rajesh B.',
        'phone': '',
        'condition': '',
        'sessions': 7,
        'last': '2026-08-20T13:30:00+00:00',
      });

      expect(never.lastVisit, isNull);
      expect(visited.lastVisit?.year, 2026);
    });
  });

  group('TransactionDto', () {
    test('falls back sensibly when the payment row is missing', () {
      final dto = TransactionDto.fromJson({
        'id': 'ses_1',
        'patientName': 'Unknown',
        'date': '',
        'time': '',
        'type': 'HOME_VISIT',
        'fee': 1500,
        'status': 'COMPLETED',
        'paymentMethod': '',
        'paymentStatus': 'PENDING',
      });

      expect(dto.fee, 1500.0);
      expect(dto.paymentMethod, isEmpty);
      expect(dto.paymentStatus, 'PENDING');
    });
  });

  group('Request bodies', () {
    test('SessionUpdateDto omits nulls so a status change sends only status', () {
      final json = const SessionUpdateDto(status: 'COMPLETED').toJson();
      expect(json, {'status': 'COMPLETED'});
    });

    test('SlotUpdateDto sends the three required keys', () {
      final json = const SlotUpdateDto(
        date: '2026-08-21',
        time: '09:00',
        status: 'open',
      ).toJson();
      expect(json['date'], '2026-08-21');
      expect(json['status'], 'open');
    });

    test('RecurringPatternCreateDto sends Sunday-indexed days', () {
      final json = const RecurringPatternCreateDto(
        days: [0, 1, 2],
        sessions: ['Morning'],
      ).toJson();
      expect(json['days'], [0, 1, 2]);
      expect(json['sessions'], ['Morning']);
    });

    test('BlockRequestDto defaults reason and notify', () {
      final json = const BlockRequestDto(dateFrom: '2026-09-01').toJson();
      expect(json['reason'], 'Time off');
      expect(json['notify'], isTrue);
      expect(json.containsKey('dateTo'), isFalse);
    });
  });
}
