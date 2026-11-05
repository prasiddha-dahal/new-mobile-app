import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/profile_avatar.dart';
import 'package:sahayatri_care_connect/features/coverage/data/models/coverage_models.dart';
import 'package:sahayatri_care_connect/features/coverage/presentation/providers/coverage_providers.dart';
import 'package:sahayatri_care_connect/features/coverage/presentation/screens/coverage_map_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_earnings_screen.dart';

import '../../l10n_harness.dart';

/// Two lists that named a person and drew only their initials: the coverage
/// list (therapists a patient could book) and the earnings transactions (the
/// patients a therapist was paid for). The API now sends the photo for both.
void main() {
  Widget inRouter(Widget screen) {
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => screen)]);
    addTearDown(router.dispose);
    return InheritedGoRouter(goRouter: router, child: screen);
  }

  group('earnings transactions', () {
    Future<void> pump(WidgetTester tester, List<TransactionDto> rows) async {
      await pumpLocalized(
        tester,
        inRouter(const TherapistEarningsScreen()),
        theme: AppTheme.light,
        size: const Size(390, 2000),
        overrides: [
          therapistDashboardProvider.overrideWith((_) async => const TherapistDashboardDto()),
          transactionsProvider.overrideWith((_) async => rows),
          payoutsProvider.overrideWith((_) async => const <PayoutDto>[]),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('each row draws the patient, with their photo when they have one', (
      tester,
    ) async {
      await pump(tester, const [
        TransactionDto(
          id: 's1',
          patientName: 'Asha Rai',
          date: '2026-10-01',
          fee: 1500,
          patientPhotoThumb: '/api/v1/uploads/patients/p/thumb-ab12.jpg',
        ),
        TransactionDto(id: 's2', patientName: 'Maya Thapa', date: '2026-10-02', fee: 1500),
      ]);

      final avatars = tester
          .widgetList<ProfileAvatar>(find.byType(ProfileAvatar))
          .toList();
      expect(avatars, hasLength(2));
      expect(avatars[0].thumbUrl, contains('thumb-ab12'));
      expect(avatars[0].initials, 'AR');
      expect(avatars[1].thumbUrl, isNull, reason: 'no photo, so the initials stand in');
    });

    testWidgets('a transaction the server withheld the photo for shows initials', (
      tester,
    ) async {
      // A cancelled session: the API sends no photo, and the row must not
      // invent one.
      await pump(tester, const [
        TransactionDto(id: 's2', patientName: 'Maya Thapa', date: '2026-10-02'),
      ]);

      expect(find.text('MT'), findsOneWidget);
    });
  });

  group('the coverage list', () {
    testWidgets('draws each therapist with their public photo', (tester) async {
      await pumpLocalized(
        tester,
        inRouter(const CoverageMapScreen()),
        theme: AppTheme.light,
        size: const Size(390, 1800),
        overrides: [
          serviceAreasProvider.overrideWith(
            (_) async => const [ServiceAreaDto(id: 'a1', name: 'Patan')],
          ),
          coverageProvider.overrideWith(
            (_) async => const CoverageDto(
              therapists: [
                CoverageTherapistDto(
                  id: 't1',
                  name: 'Dr. Anil Shakya',
                  covers: true,
                  photoThumb: '/api/v1/uploads/therapists/t1/thumb-ab12.jpg',
                  photo: '/api/v1/uploads/therapists/t1/photo-ab12.jpg',
                ),
                CoverageTherapistDto(id: 't2', name: 'Dr. B Rai', covers: false),
              ],
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final avatars = tester
          .widgetList<ProfileAvatar>(find.byType(ProfileAvatar))
          .toList();
      expect(avatars, hasLength(2));
      expect(avatars[0].thumbUrl, contains('thumb-ab12'));
      expect(avatars[0].photoUrl, contains('photo-ab12'));
      expect(avatars[1].thumbUrl, isNull);
    });
  });

  test('the DTOs read the photo fields the API sends', () {
    expect(
      TransactionDto.fromJson({
        'id': 's1',
        'patientName': 'Asha',
        'patientPhoto': '/p/photo-1.jpg',
        'patientPhotoThumb': '/p/thumb-1.jpg',
      }).patientPhotoThumb,
      '/p/thumb-1.jpg',
    );
    expect(
      TodaySessionDto.fromJson({
        'id': 's1',
        'patient': 'Asha',
        'patientPhotoThumb': '/p/thumb-1.jpg',
      }).patientPhotoThumb,
      '/p/thumb-1.jpg',
    );
    expect(
      CoverageTherapistDto.fromJson({
        'id': 't1',
        'name': 'Dr. A',
        'photoThumb': '/t/thumb-2.jpg',
      }).photoThumb,
      '/t/thumb-2.jpg',
    );
  });
}
