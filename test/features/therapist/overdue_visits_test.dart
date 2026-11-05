import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_requests_screen.dart';

import '../../l10n_harness.dart';

/// QA DATA-02: a visit from July sat under Upcoming in October, still
/// offering Mark complete and Reschedule. A confirmed visit whose day has gone
/// is overdue: it belongs with the things that need the therapist's decision.

class _FakeActions implements TherapistActions {
  final calls = <(String, SessionStatus)>[];

  @override
  Future<AppResult<void>> setSessionStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    calls.add((sessionId, status));
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Session _visit(
  String id, {
  required int dayOffset,
  SessionStatus status = SessionStatus.scheduled,
  String patient = 'Ramesh Adhikari',
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
    time: '10:00',
    type: 'HOME_VISIT',
    status: status,
    address: 'Baluwatar, Kathmandu',
    fee: 1500,
  );
}

void main() {
  test('overdue is a past day, still confirmed or in progress', () {
    expect(isOverdue(_visit('a', dayOffset: -80)), isTrue);
    expect(
      isOverdue(_visit('b', dayOffset: -1, status: SessionStatus.inProgress)),
      isTrue,
    );
    expect(isOverdue(_visit('c', dayOffset: 0)), isFalse, reason: 'today');
    expect(isOverdue(_visit('d', dayOffset: 2)), isFalse);
    expect(
      isOverdue(_visit('e', dayOffset: -3, status: SessionStatus.completed)),
      isFalse,
    );
  });

  Future<_FakeActions> pump(WidgetTester tester, List<Session> sessions) async {
    final actions = _FakeActions();
    await pumpLocalized(
      tester,
      const Scaffold(body: TherapistRequestsScreen()),
      theme: AppTheme.light,
      overrides: [
        therapistSessionsProvider.overrideWith((_) async => sessions),
        therapistActionsProvider.overrideWithValue(actions),
      ],
    );
    await tester.pumpAndSettle();
    return actions;
  }

  testWidgets('a July visit is in Requests as overdue, not in Upcoming', (
    tester,
  ) async {
    await pump(tester, [
      _visit('old', dayOffset: -80, patient: 'Ramesh Adhikari'),
      _visit('soon', dayOffset: 2, patient: 'Sita Lama'),
    ]);

    // Requests is the first tab.
    expect(find.text('Ramesh Adhikari'), findsOneWidget);
    expect(find.text('OVERDUE'), findsOneWidget);
    expect(find.text("Didn't happen"), findsOneWidget);
    expect(find.text('Sita Lama'), findsNothing);

    await tester.tap(find.textContaining('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Sita Lama'), findsOneWidget);
    expect(find.text('Ramesh Adhikari'), findsNothing);
  });

  testWidgets('Mark complete closes it', (tester) async {
    final actions = await pump(tester, [_visit('old', dayOffset: -80)]);

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(actions.calls, [('old', SessionStatus.completed)]);
  });

  testWidgets("Didn't happen asks first, then cancels it", (tester) async {
    final actions = await pump(tester, [_visit('old', dayOffset: -80)]);

    await tester.tap(find.text("Didn't happen"));
    await tester.pumpAndSettle();
    expect(find.text('Record that this visit didn\'t happen?'), findsOneWidget);

    await tester.tap(find.text("Didn't happen").last);
    await tester.pumpAndSettle();

    expect(actions.calls, [('old', SessionStatus.cancelled)]);
  });
}
