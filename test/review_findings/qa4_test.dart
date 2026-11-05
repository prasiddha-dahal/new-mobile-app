// Regression tests from the sub-agent review of feat/date-time-pickers (2026-10-08):
// each reproduced a bug the review found; they now pin the fixes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/slot_pickers.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/care_models.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_profile_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/review_prompt_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/booking_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/widgets/review_prompt_banner.dart';
import 'package:sahayatri_care_connect/features/rewards/presentation/providers/points_providers.dart';

import 'package:sahayatri_care_connect/features/rewards/data/models/points_models.dart';

import '../l10n_harness.dart';

void main() {
  for (final loc in [const Locale('en'), const Locale('ne')]) {
    for (final scale in [1.6, 2.0]) {
      testWidgets('QA10 booking 360dp $loc x$scale', (t) async {
        await pumpLocalized(
          t,
          const BookingScreen(
            therapistId: 't1',
            date: '2099-01-01',
            time: '10:00',
          ),
          locale: loc,
          size: const Size(360, 780),
          textScale: scale,
          theme: AppTheme.light,
          overrides: [
            therapistDetailProvider('t1').overrideWith(
              (_) async => const Therapist(
                id: 't1',
                userId: 'u1',
                name: 'Dr. Sushmita Shrestha Karki',
                specialty: 'Orthopaedic physiotherapy',
                city: 'Kathmandu',
                gender: 'F',
                rating: 0,
                reviewCount: 0,
                fee: 12500,
                experienceYears: 3,
                bio: '',
              ),
            ),
            platformFeePercentProvider.overrideWith((_) async => 12.5),
            patientProfileProvider.overrideWith(
              (_) async => const PatientProfileDto(
                address: 'House 12, Baneshwor, Kathmandu',
              ),
            ),
            currentUserProvider.overrideWith((_) => null),
            spendablePointsProvider.overrideWithValue(5000),
            pointBalanceProvider.overrideWith(
              (_) async => const PointBalanceDto(balance: 5000),
            ),
          ],
        );
        await t.pump();
        await t.pump();
        expect(t.takeException(), isNull);
      });
      testWidgets('QA11 slot fields + banner 320dp $loc x$scale', (t) async {
        final s = Session(
          id: 'a',
          therapistId: 't',
          therapistName: 'Dr. Sushmita Shrestha Karki',
          patientId: 'p',
          patientName: '',
          patientPhone: '',
          date: DateTime.now(),
          time: '09:00',
          type: 'HOME_VISIT',
          status: SessionStatus.completed,
          address: 'x',
          fee: 1,
        );
        await pumpLocalized(
          t,
          Scaffold(
            body: ListView(
              children: [
                const ReviewPromptBanner(),
                SlotPickerFields(
                  openTimes: const {
                    '2099-01-02': ['11:00', '12:00', '13:00', '14:00', '15:00'],
                  },
                  date: '2099-01-02',
                  time: '11:00',
                  onDate: (_) {},
                  onTime: (_) {},
                ),
              ],
            ),
          ),
          locale: loc,
          size: const Size(320, 700),
          textScale: scale,
          theme: AppTheme.light,
          overrides: [reviewPromptProvider.overrideWithValue(s)],
        );
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  }
}
