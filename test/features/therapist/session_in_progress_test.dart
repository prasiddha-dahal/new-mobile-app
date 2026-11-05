import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/session_in_progress.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_en.dart';

import '../../l10n_harness.dart';

// import 'therapist_dummy_data.dart';

class DummySessions {
  DummySessions._();

  static const String therapistId = 'cmv0or00i001vd49tg0ga052q';
  static const String therapistName = 'Dr.Lara';

  /// Patients. Their names are what the tests look for on screen.
  static const String mayaa = 'Mayaa';
  static const String rojem = 'Rojemmaharjan';

  static Session _make(
    String id, {
    required String patientName,
    required int dayOffset,
    required String time,
    required SessionStatus status,
    String type = 'HOME_VISIT',
    String address = '',
    double fee = 1001,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    return Session(
      id: id,
      therapistId: therapistId,
      therapistName: therapistName,
      patientId: 'p-${patientName.toLowerCase()}',
      patientName: patientName,
      patientPhone: patientName == mayaa ? '9898989898' : '',
      date: DateTime(today.year, today.month, today.day + dayOffset),
      time: time,
      type: type,
      status: status,
      address: address,
      fee: fee,
    );
  }

  static Session cancelledYesterday() => _make(
    'dummy-cancelled-yesterday',
    patientName: mayaa,
    dayOffset: -1,
    time: '14:45',
    status: SessionStatus.cancelled,
    address: 'Yapikhya Marg, Kaldhara, Kathmandu',
    fee: 850,
  );

  /// Marked SCHEDULED, but its day has gone: nobody closed it.
  static Session awaitingUpdate() => _make(
    'dummy-awaiting-update',
    patientName: rojem,
    dayOffset: -3,
    time: '10:00',
    status: SessionStatus.scheduled,
    address: 'Baluwatar, Kathmandu',
  );

  static Session completedMorning() => _make(
    'dummy-completed-0900',
    patientName: mayaa,
    dayOffset: 0,
    time: '09:00',
    status: SessionStatus.completed,
    address: 'Jhaukhel, Bhaktapur',
  );

  static Session completedAfternoon() => _make(
    'dummy-completed-1300',
    patientName: mayaa,
    dayOffset: 0,
    time: '13:00',
    status: SessionStatus.completed,
    address: 'Lalitpur,56',
  );

  static Session inProgressToday() => _make(
    'dummy-in-progress',
    patientName: rojem,
    dayOffset: 0,
    time: '11:00',
    status: SessionStatus.inProgress,
    address: 'New Baneshwor Road, Kathmandu',
  );

  static Session scheduledLateToday() => _make(
    'dummy-scheduled-late',
    patientName: mayaa,
    dayOffset: 0,
    time: '23:40',
    status: SessionStatus.scheduled,
    address: 'Chitwan',
  );

  static Session rescheduleRequestedTomorrow() => _make(
    'dummy-reschedule',
    patientName: rojem,
    dayOffset: 1,
    time: '10:00',
    status: SessionStatus.rescheduleRequested,
    address: 'Baluwatar, Kathmandu',
  );

  static Session scheduledTomorrow() => _make(
    'dummy-scheduled-tomorrow',
    patientName: mayaa,
    dayOffset: 1,
    time: '15:00',
    status: SessionStatus.scheduled,
    address: 'pokhara - 334',
    fee: 850,
  );

  static Session clinicVisit() => _make(
    'dummy-clinic',
    patientName: mayaa,
    dayOffset: 2,
    time: '08:30',
    status: SessionStatus.scheduled,
    type: 'CLINIC',
  );

  static Session cancelledFuture() => _make(
    'dummy-cancelled-future',
    patientName: mayaa,
    dayOffset: 18,
    time: '11:00',
    status: SessionStatus.cancelled,
    address: 'Chitwan',
  );

  static List<Session> all() => [
    cancelledYesterday(),
    awaitingUpdate(),
    completedMorning(),
    completedAfternoon(),
    inProgressToday(),
    scheduledLateToday(),
    rescheduleRequestedTomorrow(),
    scheduledTomorrow(),
    clinicVisit(),
    cancelledFuture(),
  ];
}

void main() {
  final en = AppLocalizationsEn();

  const titleInProgress = 'Session in progress';
  const titlePaused = 'Session paused';
  const notesHint = 'Write your session notes…';
  const completeLabel = 'Complete Session';
  const notFound = 'We could not find this session.';

  final running = DummySessions.inProgressToday();

  /// Pumps the screen for [sessionId] with the given sessions.
  Future<({_RecordingRouter router, _MockActions actions})> pump(
    WidgetTester tester, {
    List<Session>? sessions,
    Future<List<Session>> Function()? sessionsFuture,
    String? sessionId,
    DateTime? startedAt,
    _MockActions? actions,
    _RecordingRouter? router,
    Size size = const Size(393, 852),
  }) async {
    final fakeActions = actions ?? _MockActions();
    final fakeRouter = router ?? _RecordingRouter();
    await pumpLocalized(
      tester,
      InheritedGoRouter(
        goRouter: fakeRouter,
        child: SessionInProgressScreen(
          sessionId: sessionId ?? running.id,
          startedAt: startedAt,
        ),
      ),
      theme: AppTheme.light,
      size: size,
      overrides: [
        therapistSessionsProvider.overrideWith(
          (_) => (sessionsFuture ?? () async => sessions ?? [running])(),
        ),
        therapistActionsProvider.overrideWithValue(fakeActions),
      ],
    );
    await tester.pumpAndSettle();
    return (router: fakeRouter, actions: fakeActions);
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  String clock(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(SessionInProgressScreen.timerKey)).data!;

  DateTime startedAgo({required int seconds}) =>
      DateTime.now().subtract(Duration(seconds: seconds, milliseconds: 300));

  void stubSuccess(_MockActions a) {
    when(
      () => a.saveSessionNotes(
        sessionId: any(named: 'sessionId'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) async => Right<Failure, void>(null));
    when(
      () => a.endSession(any()),
    ).thenAnswer((_) async => Right<Failure, void>(null));
  }

  group('patient header', () {
    testWidgets('shows the patient, the visit type and the date line', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(DummySessions.rojem), findsOneWidget);
      expect(find.text('Home visit'), findsOneWidget);
      expect(find.textContaining('•'), findsOneWidget);
      expect(find.textContaining('–'), findsOneWidget);
    });

    testWidgets('a clinic visit says so instead of "Home visit"', (
      tester,
    ) async {
      final clinic = DummySessions.clinicVisit();
      await pump(tester, sessions: [clinic], sessionId: clinic.id);

      expect(find.text(en.sessionTypeAtClinic), findsOneWidget);
      expect(find.text('Home visit'), findsNothing);
    });

    testWidgets('shows the session in progress title and the notes heading', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(titleInProgress), findsOneWidget);
      expect(find.text('Session notes'), findsOneWidget);
      expect(find.text(completeLabel), findsOneWidget);
    });
  });

  group('timer', () {
    testWidgets('starts at 00:00 when nobody says when it began', (
      tester,
    ) async {
      await pump(tester);
      expect(clock(tester), '00:00');
    });

    testWidgets('starts from the time it was started', (tester) async {
      await pump(tester, startedAt: startedAgo(seconds: 750));
      expect(clock(tester), '12:30');
    });

    testWidgets('ticks once a second', (tester) async {
      await pump(tester, startedAt: startedAgo(seconds: 750));

      await tester.pump(const Duration(seconds: 3));

      expect(clock(tester), '12:33');
    });

    testWidgets('a start time in the future does not show a negative clock', (
      tester,
    ) async {
      await pump(
        tester,
        startedAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      expect(clock(tester), '00:00');
    });

    testWidgets('pause freezes it and resume carries on', (tester) async {
      await pump(tester, startedAt: startedAgo(seconds: 750));

      await tester.tap(find.byKey(SessionInProgressScreen.pauseKey));
      await tester.pump();
      expect(find.text(titlePaused), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(clock(tester), '12:30'); // did not age while paused

      await tester.tap(find.byKey(SessionInProgressScreen.pauseKey));
      await tester.pump();
      expect(find.text(titleInProgress), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(clock(tester), '12:32');
    });

    test('formatElapsed pads minutes and adds hours only when needed', () {
      expect(formatElapsed(Duration.zero), '00:00');
      expect(formatElapsed(const Duration(seconds: 65)), '01:05');
      expect(formatElapsed(const Duration(seconds: 3599)), '59:59');
      expect(formatElapsed(const Duration(hours: 1)), '1:00:00');
      expect(formatElapsed(const Duration(seconds: 3725)), '1:02:05');
      expect(formatElapsed(const Duration(seconds: -5)), '00:00');
    });
  });

  group('notes', () {
    testWidgets('what was typed survives the clock ticking', (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(SessionInProgressScreen.notesKey),
        'Pain 4/10',
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Pain 4/10'), findsOneWidget);
    });
  });

  group('Complete Session', () {
    testWidgets('saves the notes, ends the session, then goes home', (
      tester,
    ) async {
      final actions = _MockActions();
      stubSuccess(actions);
      final env = await pump(tester, actions: actions);

      await tester.enterText(
        find.byKey(SessionInProgressScreen.notesKey),
        '  Knee mobilisation done  ',
      );
      await tester.tap(find.byKey(SessionInProgressScreen.completeKey));
      await flush(tester);

      verifyInOrder([
        () => actions.saveSessionNotes(
          sessionId: running.id,
          notes: 'Knee mobilisation done', // trimmed
        ),
        () => actions.endSession(running.id),
      ]);
      expect(env.router.went, ['/therapist/home']);
    });

    testWidgets('blank notes are not saved, but the session still ends', (
      tester,
    ) async {
      final actions = _MockActions();
      stubSuccess(actions);
      final env = await pump(tester, actions: actions);

      await tester.enterText(
        find.byKey(SessionInProgressScreen.notesKey),
        '   ',
      );
      await tester.tap(find.byKey(SessionInProgressScreen.completeKey));
      await flush(tester);

      verifyNever(
        () => actions.saveSessionNotes(
          sessionId: any(named: 'sessionId'),
          notes: any(named: 'notes'),
        ),
      );
      verify(() => actions.endSession(running.id)).called(1);
      expect(env.router.went, ['/therapist/home']);
    });

    testWidgets('a failed save stops before ending and keeps the notes', (
      tester,
    ) async {
      final actions = _MockActions();
      when(
        () => actions.saveSessionNotes(
          sessionId: any(named: 'sessionId'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => Left<Failure, void>(UnknownFailure('boom')));
      final env = await pump(tester, actions: actions);

      await tester.enterText(
        find.byKey(SessionInProgressScreen.notesKey),
        'Important note',
      );
      await tester.tap(find.byKey(SessionInProgressScreen.completeKey));
      await flush(tester);

      verifyNever(() => actions.endSession(any()));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Important note'), findsOneWidget);
      expect(env.router.went, isEmpty);
    });

    testWidgets('a failed end shows the error and stays on the screen', (
      tester,
    ) async {
      final actions = _MockActions();
      when(
        () => actions.endSession(any()),
      ).thenAnswer((_) async => Left<Failure, void>(UnknownFailure('boom')));
      final env = await pump(tester, actions: actions);

      await tester.tap(find.byKey(SessionInProgressScreen.completeKey));
      await flush(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(env.router.went, isEmpty);
      final button = tester.widget<FilledButton>(
        find.byKey(SessionInProgressScreen.completeKey),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a second tap while ending does not end twice', (tester) async {
      final actions = _MockActions();
      final gate = Completer<Either<Failure, void>>();
      when(() => actions.endSession(any())).thenAnswer((_) => gate.future);
      final env = await pump(tester, actions: actions);

      await tester.tap(find.byKey(SessionInProgressScreen.completeKey));
      await tester.pump();
      await tester.tap(find.byKey(SessionInProgressScreen.completeKey));
      await tester.pump();

      verify(() => actions.endSession(running.id)).called(1);

      gate.complete(Right<Failure, void>(null));
      await flush(tester);
      expect(env.router.went, ['/therapist/home']);
    });
  });

  group('back and edge states', () {
    testWidgets('back goes home when there is nothing to pop to', (
      tester,
    ) async {
      final env = await pump(tester);

      await tester.tap(find.byKey(SessionInProgressScreen.backKey));
      await tester.pump();

      expect(env.router.went, ['/therapist/home']);
    });

    testWidgets('back pops when the screen was pushed', (tester) async {
      final router = _RecordingRouter()..canPopResult = true;
      final env = await pump(tester, router: router);

      await tester.tap(find.byKey(SessionInProgressScreen.backKey));
      await tester.pump();

      expect(env.router.popped, 1);
      expect(env.router.went, isEmpty);
    });

    testWidgets('an unknown session id says so, with a way back', (
      tester,
    ) async {
      await pump(tester, sessionId: 'does-not-exist');

      expect(find.text(notFound), findsOneWidget);
      expect(find.byKey(SessionInProgressScreen.backKey), findsOneWidget);
      expect(find.byKey(SessionInProgressScreen.completeKey), findsNothing);
    });

    testWidgets('a failed load says so instead of "not found"', (tester) async {
      await pump(
        tester,
        sessionsFuture: () async => throw Exception('offline'),
      );

      expect(find.text(en.therapistTodayLoadFailed), findsOneWidget);
      expect(find.text(notFound), findsNothing);
    });
  });

  group('screen sizes', () {
    for (final size in const [Size(320, 568), Size(393, 852), Size(430, 932)]) {
      testWidgets('lays out without overflow at ${size.width}x${size.height}', (
        tester,
      ) async {
        await pump(tester, size: size);

        expect(tester.takeException(), isNull);
        expect(find.byKey(SessionInProgressScreen.completeKey), findsOneWidget);
        expect(find.byKey(SessionInProgressScreen.timerKey), findsOneWidget);
      });
    }

    testWidgets('a short screen scrolls the notes instead of overflowing', (
      tester,
    ) async {
      await pump(tester, size: const Size(320, 480));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}

class _MockActions extends Mock implements TherapistActions {}

/// Records every place the screen asked to go.
class _RecordingRouter implements GoRouter {
  final pushed = <String>[];
  final went = <String>[];
  int popped = 0;
  bool canPopResult = false;

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushed.add(location);
    return null;
  }

  @override
  void go(String location, {Object? extra}) => went.add(location);

  @override
  bool canPop() => canPopResult;

  @override
  void pop<T extends Object?>([T? result]) => popped++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
