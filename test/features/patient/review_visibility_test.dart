import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/review.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/repositories/patient_repository.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_sessions_screen.dart';

import '../../l10n_harness.dart';

/// "Leave a review" was offered on every completed session.
///
/// It only checked the session's status, so a session that had already been
/// reviewed -- and every other session with a therapist the patient had
/// already reviewed, which the server also refuses -- kept showing the button.
/// Using it earned a 409. The button now follows the server's own list of what
/// it will still accept (`GET /reviews/therapists-to-rate`).
class _FakeRepository implements PatientRepository {
  _FakeRepository({
    required this.sessions,
    required this.reviewable,
    this.lookupFails = false,
    List<MyReview> reviews = const [],
  }) : reviews = [...reviews];

  final List<Session> sessions;
  Set<String> reviewable;
  final bool lookupFails;
  final List<MyReview> reviews;

  final reviewed = <String>[];
  int lookups = 0;

  @override
  Future<AppResult<List<Session>>> getSessions() async => Right(sessions);

  @override
  Future<AppResult<Set<String>>> reviewableSessionIds() async {
    lookups++;
    if (lookupFails) return const Left(NetworkFailure());
    return Right(reviewable);
  }

  @override
  Future<AppResult<List<MyReview>>> myReviews() async => Right([...reviews]);

  @override
  Future<AppResult<void>> reviewSession({
    required String sessionId,
    required int rating,
    String? comment,
  }) async {
    reviewed.add(sessionId);
    // The server now has a review for it, and for that therapist.
    reviewable = {...reviewable}..remove(sessionId);
    final session = sessions.firstWhere((s) => s.id == sessionId);
    reviews.add(
      MyReview(
        id: 'r-$sessionId',
        sessionId: sessionId,
        therapistId: session.therapistId,
        rating: rating,
        comment: comment,
      ),
    );
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Session _completed(String id, {String therapist = 'Dr. Rai'}) => Session(
  id: id,
  therapistId: 't-$therapist',
  therapistName: therapist,
  patientId: 'p',
  patientName: '',
  patientPhone: '',
  date: DateTime.now().subtract(const Duration(days: 3)),
  time: '09:00',
  type: 'HOME_VISIT',
  status: SessionStatus.completed,
  address: 'Lalitpur',
  fee: 1500,
);

void main() {
  Future<_FakeRepository> pumpSessions(
    WidgetTester tester, {
    required List<Session> sessions,
    required Set<String> reviewable,
    bool lookupFails = false,
    List<MyReview> reviews = const [],
    Locale locale = const Locale('en'),
  }) async {
    final repo = _FakeRepository(
      sessions: sessions,
      reviewable: reviewable,
      lookupFails: lookupFails,
      reviews: reviews,
    );
    await pumpLocalized(
      tester,
      const Scaffold(body: PatientSessionsScreen()),
      locale: locale,
      theme: AppTheme.light,
      overrides: [patientRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();
    // Reviewable sessions live under History.
    await tester.tap(
      find.textContaining(locale.languageCode == 'ne' ? 'पुराना' : 'Past'),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('only a session the server will accept a review for offers one', (
    tester,
  ) async {
    await pumpSessions(
      tester,
      sessions: [
        _completed('open'),
        _completed('already-reviewed'),
        // Nothing written against this one, but its therapist was reviewed
        // from another session -- the server refuses it, so offering it would
        // be offering a guaranteed failure.
        _completed('same-therapist', therapist: 'Dr. Karki'),
      ],
      reviewable: {'open'},
    );

    expect(find.text('Leave a review'), findsOneWidget);
  });

  testWidgets('a session that has been reviewed shows no button at all', (
    tester,
  ) async {
    await pumpSessions(
      tester,
      sessions: [_completed('already-reviewed')],
      reviewable: const {},
    );

    expect(find.text('Leave a review'), findsNothing);
  });

  testWidgets('every unreviewed session offers it', (tester) async {
    await pumpSessions(
      tester,
      sessions: [
        _completed('a', therapist: 'Dr. A'),
        _completed('b', therapist: 'Dr. B'),
      ],
      reviewable: {'a', 'b'},
    );

    expect(find.text('Leave a review'), findsNWidgets(2));
  });

  testWidgets('submitting a review takes its button away', (tester) async {
    final repo = await pumpSessions(
      tester,
      sessions: [_completed('open')],
      reviewable: {'open'},
    );
    expect(find.text('Leave a review'), findsOneWidget);

    await tester.tap(find.text('Leave a review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();

    expect(repo.reviewed, ['open']);
    expect(
      find.text('Leave a review'),
      findsNothing,
      reason: 'a reviewed session must not invite a second review',
    );
    // ...and the card says what the patient gave, rather than going quiet.
    expect(find.text('You rated this visit'), findsOneWidget);
  });

  testWidgets('a reviewed session says what it was rated', (tester) async {
    await pumpSessions(
      tester,
      sessions: [_completed('done')],
      reviewable: const {},
      reviews: const [
        MyReview(
          id: 'r1',
          sessionId: 'done',
          therapistId: 't-Dr. Rai',
          rating: 4,
        ),
      ],
    );

    expect(find.text('You rated this visit'), findsOneWidget);
    expect(find.text('Leave a review'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets(
    'a second visit with a therapist already reviewed explains the missing button',
    (tester) async {
      await pumpSessions(
        tester,
        sessions: [_completed('first'), _completed('second')],
        reviewable: const {},
        reviews: const [
          MyReview(
            id: 'r1',
            sessionId: 'first',
            therapistId: 't-Dr. Rai',
            rating: 5,
          ),
        ],
      );

      expect(find.text('You rated this visit'), findsOneWidget);
      expect(find.text("You've already reviewed Dr. Rai"), findsOneWidget);
      expect(find.text('Leave a review'), findsNothing);
    },
  );

  testWidgets('the rated line is in Nepali under the Nepali locale', (
    tester,
  ) async {
    await pumpSessions(
      tester,
      sessions: [_completed('done')],
      reviewable: const {},
      reviews: const [
        MyReview(
          id: 'r1',
          sessionId: 'done',
          therapistId: 't-Dr. Rai',
          rating: 5,
        ),
      ],
      locale: const Locale('ne'),
    );

    expect(find.text('You rated this visit'), findsNothing);
    expect(find.text('तपाईंले यो भेटलाई मूल्याङ्कन गर्नुभयो'), findsOneWidget);
  });

  testWidgets('if the lookup fails the button is offered, not removed', (
    tester,
  ) async {
    // Withholding it would take the feature away over a flaky connection, and
    // the server still refuses a duplicate.
    await pumpSessions(
      tester,
      sessions: [_completed('open')],
      reviewable: const {},
      lookupFails: true,
    );

    expect(find.text('Leave a review'), findsOneWidget);
  });

  testWidgets('a session that is not completed never offers one', (
    tester,
  ) async {
    final scheduled = Session(
      id: 'future',
      therapistId: 't',
      therapistName: 'Dr. Rai',
      patientId: 'p',
      patientName: '',
      patientPhone: '',
      date: DateTime.now().add(const Duration(days: 2)),
      time: '09:00',
      type: 'HOME_VISIT',
      status: SessionStatus.scheduled,
      address: 'Lalitpur',
      fee: 1500,
    );
    final repo = _FakeRepository(
      sessions: [scheduled],
      // Even if the server listed it, the status gate comes first.
      reviewable: {'future'},
    );
    await pumpLocalized(
      tester,
      const Scaffold(body: PatientSessionsScreen()),
      theme: AppTheme.light,
      overrides: [patientRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave a review'), findsNothing);
  });
}
