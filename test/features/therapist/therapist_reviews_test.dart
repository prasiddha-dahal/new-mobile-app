import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/profile_avatar.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_reviews_screen.dart';

import '../../l10n_harness.dart';

/// The Reviews screen was a hard-coded list: a 4.9 average, "182 reviews" and
/// three invented patients, identical for every therapist, with five gold stars
/// on every row whatever anyone had given. It now shows what the API says -- or
/// says plainly that there is nothing.
TherapistReviewDto _review(
  String id,
  String name, {
  int stars = 5,
  String text = 'Very thorough.',
  String? thumb,
}) => TherapistReviewDto(
  id: id,
  name: name,
  stars: stars,
  text: text,
  createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
  photoThumb: thumb,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<TherapistReviewsDto> Function() load, {
    Locale locale = const Locale('en'),
  }) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const TherapistReviewsScreen())],
    );
    addTearDown(router.dispose);
    await pumpLocalized(
      tester,
      InheritedGoRouter(goRouter: router, child: const TherapistReviewsScreen()),
      locale: locale,
      theme: AppTheme.light,
      size: const Size(390, 1600),
      overrides: [therapistReviewsProvider.overrideWith((_) => load())],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the reviews the API sent, not a script', (tester) async {
    await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [
          _review('1', 'Asha R.', text: 'Fixed my shoulder.'),
          _review('2', 'Maya T.', stars: 3, text: 'Good, a little late.'),
        ],
        total: 2,
        averageRating: 4.0,
      ),
    );

    expect(find.text('Asha R.'), findsOneWidget);
    expect(find.text('Fixed my shoulder.'), findsOneWidget);
    expect(find.text('Maya T.'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('2 reviews'), findsOneWidget);
  });

  testWidgets('nothing from the old prototype survives', (tester) async {
    await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [_review('1', 'Asha R.')],
        total: 1,
        averageRating: 5,
      ),
    );

    for (final invented in ['Pranita K.', 'Rajesh B.', 'Maya T.', '182 reviews', '4.9']) {
      expect(find.text(invented), findsNothing, reason: invented);
    }
  });

  testWidgets('each row shows the stars that were given', (tester) async {
    await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [_review('1', 'Asha R.', stars: 2)],
        total: 1,
        averageRating: 2,
      ),
    );

    // The header average and the one review are both two-star: four solid
    // stars in all, six hollow ones -- not ten gold ones.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(6));
  });

  testWidgets('a review with no comment shows no empty paragraph', (tester) async {
    await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [_review('1', 'Asha R.', text: '  ')],
        total: 1,
        averageRating: 5,
      ),
    );

    expect(find.text('Asha R.'), findsOneWidget);
    expect(find.text('  '), findsNothing);
  });

  testWidgets("the reviewer's photo is asked for as a thumbnail", (tester) async {
    await pump(
      tester,
      () async => TherapistReviewsDto(
        reviews: [
          _review('1', 'Asha R.', thumb: '/api/v1/uploads/patients/p/thumb-ab12.jpg'),
        ],
        total: 1,
        averageRating: 5,
      ),
    );

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.thumbUrl, contains('thumb-ab12'));
    expect(avatar.initials, 'AR');
  });

  testWidgets('with no reviews it says so, and shows no rating', (tester) async {
    await pump(tester, () async => const TherapistReviewsDto());

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.textContaining('rates a visit'), findsOneWidget);
    expect(find.text('0.0'), findsNothing, reason: 'an average of nothing is not 0.0');
  });

  testWidgets('a failed load can be retried', (tester) async {
    var calls = 0;
    await pump(tester, () async {
      calls++;
      throw const NetworkFailure();
    });

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('reads in Nepali with no English left over', (tester) async {
    await pump(
      tester,
      () async => const TherapistReviewsDto(),
      locale: const Locale('ne'),
    );

    expect(find.text('No reviews yet'), findsNothing);
    expect(find.text('अहिलेसम्म कुनै समीक्षा छैन'), findsOneWidget);
  });

  test('a review parses the way the API sends it', () {
    final dto = TherapistReviewsDto.fromJson({
      'reviews': [
        {
          'id': 'r1',
          'name': 'Asha R.',
          'stars': 4,
          'text': 'Good',
          'createdAt': '2026-10-01T09:30:00',
          'photo': null,
          'photoThumb': '/api/v1/uploads/patients/p/thumb-ab12.jpg',
        },
      ],
      'total': 1,
      'averageRating': 4,
    });

    expect(dto.averageRating, 4.0);
    expect(dto.reviews.single.created, DateTime(2026, 10, 1, 9, 30));
    expect(dto.reviews.single.photoThumb, contains('thumb-ab12'));
  });
}
