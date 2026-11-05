import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/profile_avatar.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_home_screen.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';

import '../../l10n_harness.dart';

/// The home screen's Reviews card said individual reviews were "not available
/// in the app yet", with a TODO for the endpoint that has now been written.
/// It shows the latest two and a way to the rest -- and says nothing alarming
/// when there is nothing to show.
void main() {
  Future<_RecordingRouter> pump(
    WidgetTester tester,
    Future<TherapistReviewsDto> Function() reviews,
  ) async {
    final router = _RecordingRouter();
    await pumpLocalized(
      tester,
      InheritedGoRouter(goRouter: router, child: const TherapistHomeScreen()),
      theme: AppTheme.light,
      size: const Size(390, 2200),
      overrides: [
        therapistDashboardProvider.overrideWith(
          (_) async => const TherapistDashboardDto(name: 'Dr. A', averageRating: 4.5),
        ),
        therapistSessionsProvider.overrideWith((_) async => const <Session>[]),
        ownSlotsProvider.overrideWith((_) async => const <TherapistSlot>[]),
        therapistReviewsProvider.overrideWith((_) => reviews()),
      ],
    );
    await tester.pumpAndSettle();
    return router;
  }

  TherapistReviewDto review(String id, String name, int stars, String text) =>
      TherapistReviewDto(id: id, name: name, stars: stars, text: text);

  testWidgets('shows the latest two reviews, not the "not available" notice', (
    tester,
  ) async {
    await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [
          review('1', 'Asha R.', 5, 'Fixed my shoulder.'),
          review('2', 'Maya T.', 3, 'Good, a little late.'),
          review('3', 'Ram K.', 4, 'This one is third, so it is not here.'),
        ],
        total: 3,
        averageRating: 4.5,
      ),
    );

    expect(find.textContaining('Asha R.'), findsOneWidget);
    expect(find.text('Fixed my shoulder.'), findsOneWidget);
    expect(find.textContaining('Maya T.'), findsOneWidget);
    expect(find.textContaining('Ram K.'), findsNothing);
    expect(find.textContaining('not available in the app yet'), findsNothing);
  });

  testWidgets('draws the reviewer with their photo link, as a thumbnail', (
    tester,
  ) async {
    await pump(
      tester,
      () async => const TherapistReviewsDto(
        reviews: [
          TherapistReviewDto(
            id: '1',
            name: 'Asha R.',
            stars: 5,
            text: 'Great',
            photoThumb: '/api/v1/uploads/patients/p/thumb-ab12.jpg',
          ),
        ],
        total: 1,
        averageRating: 5,
      ),
    );

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first);
    expect(avatar.thumbUrl, contains('thumb-ab12'));
  });

  testWidgets('See all opens the full reviews screen', (tester) async {
    final router = await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [review('1', 'Asha R.', 5, 'Great')],
        total: 1,
        averageRating: 5,
      ),
    );

    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pump();

    expect(router.pushed, '/therapist/reviews');
  });

  testWidgets('no reviews says so quietly', (tester) async {
    await pump(tester, () async => const TherapistReviewsDto());

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('a failed load leaves the card as the average alone', (tester) async {
    await pump(tester, () async => throw Exception('offline'));

    expect(find.text('See all'), findsNothing);
    expect(find.text('No reviews yet'), findsNothing);
    expect(find.textContaining('4.5'), findsWidgets, reason: 'the average still stands');
  });
}

/// Records where the screen asked to go. Pumping the screen directly, outside a
/// `MaterialApp.router`, leaves a real router with nothing to navigate.
class _RecordingRouter implements GoRouter {
  String? pushed;

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushed = location;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
