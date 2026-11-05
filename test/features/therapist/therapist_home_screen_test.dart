import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_home_screen.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_en.dart';

import '../../l10n_harness.dart';

/// Widget tests for the therapist home screen's session logic.
void main() {
  final en = AppLocalizationsEn();

  const laterA = '23:40';
  const laterB = '23:50';
  // const earlier = '00:01';

  const therapist = User(
    id: 'u-t1',
    name: 'Dr. Jane Smith',
    email: 'jane@test.com',
    role: 'THERAPIST',
    status: 'APPROVED',
  );

  Session visit(
    String id, {
    required String patient,
    required String time,
    int dayOffset = 0,
    SessionStatus status = SessionStatus.scheduled,
  }) {
    final now = DateTime.now();
    return Session(
      id: id,
      therapistId: 't1',
      therapistName: 'Dr. Jane Smith',
      patientId: 'p-$id',
      patientName: patient,
      patientPhone: '',
      date: DateTime(now.year, now.month, now.day + dayOffset),
      time: time,
      type: 'HOME_VISIT',
      status: status,
      address: 'Baluwatar, Kathmandu',
      fee: 1500,
    );
  }

  TherapistDashboardDto dashboard() => TherapistDashboardDto.fromJson({
    'name': 'Dr. Jane Smith',
    'sessionsThisWeek': 6,
    'totalPatients': 4,
    'earningsThisMonth': 72000,
    'averageRating': 4.9,
  });

  Future<_RecordingRouter> pump(
    WidgetTester tester, {
    List<Session> sessions = const [],
    Future<List<Session>> Function()? sessionsFuture,
    User? user = therapist,
    Size size = const Size(390, 2200),
  }) async {
    final router = _RecordingRouter();
    await pumpLocalized(
      tester,
      InheritedGoRouter(goRouter: router, child: const TherapistHomeScreen()),
      theme: AppTheme.light,
      size: size,
      overrides: [
        currentUserProvider.overrideWith((_) => user),
        therapistDashboardProvider.overrideWith((_) async => dashboard()),
        therapistSessionsProvider.overrideWith(
          (_) => (sessionsFuture ?? () async => sessions)(),
        ),
        ownSlotsProvider.overrideWith((_) async => const <TherapistSlot>[]),
        therapistReviewsProvider.overrideWith(
          (_) async => const TherapistReviewsDto(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    return router;
  }

  // greeting

  testWidgets('the greeting counts what is still to come today', (
    tester,
  ) async {
    await pump(
      tester,
      sessions: [
        visit('a', patient: 'Ramesh Adhikari', time: laterA),
        visit('b', patient: 'Sita Lama', time: laterB),
      ],
    );

    expect(find.text(en.therapistSessionsScheduledToday(2)), findsOneWidget);
  });

  testWidgets('cancelled visits and tomorrow are not counted', (tester) async {
    await pump(
      tester,
      sessions: [
        visit('a', patient: 'Ramesh Adhikari', time: laterA),
        visit(
          'c',
          patient: 'Hari Gurung',
          time: laterB,
          status: SessionStatus.cancelled,
        ),
        visit('d', patient: 'Maya Thapa', time: laterA, dayOffset: 1),
      ],
    );

    expect(find.text(en.therapistSessionsScheduledToday(1)), findsOneWidget);
    expect(find.text(en.therapistSessionsScheduledToday(2)), findsNothing);
  });

  testWidgets('one visit reads "1 session", not "1 sessions"', (tester) async {
    await pump(
      tester,
      sessions: [visit('a', patient: 'Ramesh Adhikari', time: laterA)],
    );

    expect(find.text(en.therapistSessionsScheduledToday(1)), findsOneWidget);
    expect(find.textContaining('1 sessions'), findsNothing);
  });

  // Next Session card

  testWidgets('the card shows the earliest upcoming visit, and only that one', (
    tester,
  ) async {
    await pump(
      tester,
      sessions: [
        visit('b', patient: 'Sita Lama', time: laterB),
        visit('a', patient: 'Ramesh Adhikari', time: laterA), // earlier
        visit(
          'c',
          patient: 'Hari Gurung',
          time: laterA,
          status: SessionStatus.cancelled,
        ),
      ],
    );

    // Earliest wins the card
    expect(find.text('Ramesh Adhikari'), findsOneWidget);
    expect(find.text('Sita Lama'), findsNothing);
    expect(find.text('Hari Gurung'), findsNothing);
    expect(find.text(en.actionStartSession), findsOneWidget);
  });

  testWidgets('tomorrow\'s visit is the next one when today has none left', (
    tester,
  ) async {
    await pump(
      tester,
      sessions: [visit('d', patient: 'Maya Thapa', time: laterA, dayOffset: 1)],
    );

    expect(find.text('Maya Thapa'), findsOneWidget);

    expect(find.text(en.therapistNothingToday), findsOneWidget);
  });

  testWidgets('a completed visit today is not "scheduled today"', (
    tester,
  ) async {
    await pump(
      tester,
      sessions: [
        visit(
          'a',
          patient: 'Ramesh Adhikari',
          time: laterA,
          status: SessionStatus.completed,
        ),
      ],
    );

    expect(find.text(en.therapistSessionsScheduledToday(1)), findsNothing);
    expect(find.text(en.therapistNothingToday), findsOneWidget);
    expect(find.text(en.therapistNoUpcomingSessions), findsOneWidget);
    expect(find.text('Ramesh Adhikari'), findsNothing);
  });

  testWidgets('the count ignores a completed visit', (tester) async {
    await pump(
      tester,
      sessions: [
        visit(
          'a',
          patient: 'Ramesh Adhikari',
          time: laterA,
          status: SessionStatus.completed,
        ),
        visit('b', patient: 'Sita Lama', time: laterB),
      ],
    );

    expect(find.text(en.therapistSessionsScheduledToday(1)), findsOneWidget);
    expect(find.text(en.therapistSessionsScheduledToday(2)), findsNothing);
  });

  testWidgets('no visits at all shows the empty card', (tester) async {
    await pump(tester);

    expect(find.text(en.therapistNoUpcomingSessions), findsOneWidget);
    expect(find.text(en.therapistNothingToday), findsOneWidget);
    expect(find.textContaining('0 sessions'), findsNothing);
  });

  //  Failure

  testWidgets(
    'a failed load hides the sentence instead of saying "no sessions"',
    (tester) async {
      await pump(
        tester,
        sessionsFuture: () async => throw Exception('offline'),
      );

      expect(find.text(en.therapistNothingToday), findsNothing);
      expect(find.textContaining('scheduled today'), findsNothing);
      expect(find.text(en.therapistTodayLoadFailed), findsOneWidget);
    },
  );

  testWidgets('tapping the search bar opens the patient list', (tester) async {
    final router = await pump(tester);

    await tester.tap(find.text(en.therapistSearchHint));
    await tester.pump();

    expect(router.pushed, ['/therapist/patients']);
  });
}

/// Records every place the screen asked to go.
class _RecordingRouter implements GoRouter {
  final pushed = <String>[];

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushed.add(location);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
