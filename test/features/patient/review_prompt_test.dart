import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/navigation/tab_requests.dart';
import 'package:sahayatri_care_connect/core/storage/preferences_storage.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/review.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/repositories/patient_repository.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/review_prompt_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_sessions_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/widgets/review_prompt_banner.dart';

import '../../l10n_harness.dart';

Session _session(
  String id, {
  String therapist = 'Dr. Rai',
  int daysAgo = 3,
  SessionStatus status = SessionStatus.completed,
}) => Session(
  id: id,
  therapistId: 't-$therapist',
  therapistName: therapist,
  patientId: 'p',
  patientName: '',
  patientPhone: '',
  date: DateTime.now().subtract(Duration(days: daysAgo)),
  time: '09:00',
  type: 'HOME_VISIT',
  status: status,
  address: 'Lalitpur',
  fee: 1500,
);

class _Repo implements PatientRepository {
  _Repo(this.sessions, this.reviewable);
  final List<Session> sessions;
  Set<String> reviewable;
  final reviewed = <String>[];

  @override
  Future<AppResult<List<Session>>> getSessions() async => Right(sessions);

  @override
  Future<AppResult<Set<String>>> reviewableSessionIds() async =>
      Right(reviewable);

  @override
  Future<AppResult<List<MyReview>>> myReviews() async => const Right([]);

  @override
  Future<AppResult<void>> reviewSession({
    required String sessionId,
    required int rating,
    String? comment,
  }) async {
    reviewed.add(sessionId);
    reviewable = {...reviewable}..remove(sessionId);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  group('reviewStateFor', () {
    const review = MyReview(
      id: 'r',
      sessionId: 'done',
      therapistId: 't-Dr. Rai',
      rating: 4,
    );

    test('anything not completed says nothing', () {
      final s = _session('x', status: SessionStatus.scheduled);
      expect(
        reviewStateFor(s, reviewable: {'x'}, reviews: const []),
        isA<ReviewNone>(),
      );
    });

    test('the session that was reviewed shows its own rating', () {
      final state = reviewStateFor(
        _session('done'),
        reviewable: const {},
        reviews: const [review],
      );
      expect(state, isA<ReviewDone>());
      expect((state as ReviewDone).review.rating, 4);
    });

    test('another visit with a reviewed therapist is explained, not offered',
        () {
      final state = reviewStateFor(
        _session('other'),
        reviewable: const {},
        reviews: const [review],
      );
      expect(state, isA<ReviewDoneForTherapist>());
    });

    test('a reviewable session is open', () {
      expect(
        reviewStateFor(_session('x'), reviewable: {'x'}, reviews: const []),
        isA<ReviewOpen>(),
      );
    });

    test('while either lookup loads, nothing is shown', () {
      expect(
        reviewStateFor(_session('x'), reviewable: null, reviews: null),
        isA<ReviewNone>(),
      );
    });

    test('a failed reviewable lookup offers the button', () {
      expect(
        reviewStateFor(
          _session('x'),
          reviewable: null,
          reviews: const [],
          reviewableFailed: true,
        ),
        isA<ReviewOpen>(),
      );
    });
  });

  group('pickReviewPrompt', () {
    final now = DateTime.now();

    test('takes the most recent reviewable completed visit', () {
      final picked = pickReviewPrompt(
        [_session('old', daysAgo: 9), _session('new', daysAgo: 2)],
        reviewable: {'old', 'new'},
        dismissed: const {},
        now: now,
      );
      expect(picked?.id, 'new');
    });

    test('skips dismissed, unreviewable, stale and unfinished visits', () {
      final picked = pickReviewPrompt(
        [
          _session('dismissed', daysAgo: 1),
          _session('closed', daysAgo: 2),
          _session('stale', daysAgo: 30),
          _session('future', daysAgo: 1, status: SessionStatus.scheduled),
        ],
        reviewable: {'dismissed', 'stale', 'future'},
        dismissed: {'dismissed'},
        now: now,
      );
      expect(picked, isNull);
    });
  });

  group('DismissedReviewPrompts', () {
    test('persists, and a fresh instance reads it back', () async {
      final storage = InMemoryPreferencesStorage();
      final first = DismissedReviewPrompts(storage);
      await first.dismiss('a');
      await first.dismiss('b');

      final second = DismissedReviewPrompts(storage);
      await Future<void>.delayed(Duration.zero);
      expect(second.state, {'a', 'b'});
      expect(second.loaded, isTrue);
    });

    test('keeps only the newest 50 so the key cannot grow forever', () async {
      final storage = InMemoryPreferencesStorage();
      final notifier = DismissedReviewPrompts(storage);
      for (var i = 0; i < 60; i++) {
        await notifier.dismiss('s$i');
      }
      expect(notifier.state.length, 50);
      expect(notifier.state.contains('s0'), isFalse);
      expect(notifier.state.contains('s59'), isTrue);
    });
  });

  group('the Home banner', () {
    Future<(_Repo, InMemoryPreferencesStorage)> pumpBanner(
      WidgetTester tester, {
      required List<Session> sessions,
      required Set<String> reviewable,
      Map<String, String>? seed,
      Locale locale = const Locale('en'),
    }) async {
      final repo = _Repo(sessions, reviewable);
      final storage = InMemoryPreferencesStorage(seed);
      await pumpLocalized(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: ReviewPromptBanner()),
        ),
        locale: locale,
        theme: AppTheme.light,
        overrides: [
          patientRepositoryProvider.overrideWithValue(repo),
          preferencesStorageProvider.overrideWithValue(storage),
        ],
      );
      await tester.pumpAndSettle();
      return (repo, storage);
    }

    testWidgets('asks about the latest unreviewed visit', (tester) async {
      await pumpBanner(tester, sessions: [_session('a')], reviewable: {'a'});
      expect(find.text('How was your visit with Dr. Rai?'), findsOneWidget);
      expect(find.text('Rate your visit'), findsOneWidget);
    });

    testWidgets('is in Nepali under the Nepali locale', (tester) async {
      await pumpBanner(
        tester,
        sessions: [_session('a')],
        reviewable: {'a'},
        locale: const Locale('ne'),
      );
      expect(find.text('Rate your visit'), findsNothing);
      expect(find.text('अहिले होइन'), findsOneWidget);
    });

    testWidgets('takes no space when there is nothing to ask', (tester) async {
      await pumpBanner(tester, sessions: [_session('a')], reviewable: const {});
      expect(find.text('Rate your visit'), findsNothing);
      expect(tester.getSize(find.byType(ReviewPromptBanner)).height, 0);
    });

    testWidgets('stays away from a visit that was dismissed last launch', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        sessions: [_session('a')],
        reviewable: {'a'},
        seed: {PreferenceKeys.dismissedReviewPrompts: 'a'},
      );
      expect(find.text('Rate your visit'), findsNothing);
    });

    testWidgets('Not now hides it and remembers', (tester) async {
      final (_, storage) = await pumpBanner(
        tester,
        sessions: [_session('a')],
        reviewable: {'a'},
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Rate your visit'), findsNothing);
      expect(
        await storage.readString(PreferenceKeys.dismissedReviewPrompts),
        'a',
      );
    });

    testWidgets('rating from it submits and removes the banner', (
      tester,
    ) async {
      final (repo, _) = await pumpBanner(
        tester,
        sessions: [_session('a')],
        reviewable: {'a'},
      );

      await tester.tap(find.text('Rate your visit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();

      expect(repo.reviewed, ['a']);
      expect(find.text('Rate your visit'), findsNothing);
      expect(find.text('Thanks for the review.'), findsOneWidget);
    });
  });

  group('opening the Sessions tab from a notification', () {
    testWidgets('lands on Past when the request is already set', (
      tester,
    ) async {
      final repo = _Repo([_session('a')], {'a'});
      await pumpLocalized(
        tester,
        const Scaffold(body: PatientSessionsScreen()),
        theme: AppTheme.light,
        overrides: [
          patientRepositoryProvider.overrideWithValue(repo),
          openPastSessionsProvider.overrideWith((_) => true),
        ],
      );
      await tester.pumpAndSettle();

      // No tap on the Past tab: the review button is already there.
      expect(find.text('Leave a review'), findsOneWidget);
    });
  });
}
