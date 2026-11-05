// Regression tests from the sub-agent review of feat/date-time-pickers (2026-10-08):
// each reproduced a bug the review found; they now pin the fixes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/navigation/tab_requests.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/review.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/repositories/patient_repository.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/review_prompt_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_sessions_screen.dart';

import '../l10n_harness.dart';

Session _s(String id, SessionStatus status, int daysAgo) => Session(
  id: id,
  therapistId: 't1',
  therapistName: 'Dr. Rai',
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
  List<Session> sessions = [_s('a', SessionStatus.scheduled, 0)];
  Set<String> reviewable = {};
  @override
  Future<AppResult<List<Session>>> getSessions() async => Right(sessions);
  @override
  Future<AppResult<Set<String>>> reviewableSessionIds() async =>
      Right(reviewable);
  @override
  Future<AppResult<List<MyReview>>> myReviews() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  testWidgets('QA6 flag set while Sessions is mounted switches to Past', (
    t,
  ) async {
    final repo = _Repo()
      ..sessions = [_s('a', SessionStatus.completed, 2)]
      ..reviewable = {'a'};
    final c = await pumpLocalized(
      t,
      const Scaffold(body: PatientSessionsScreen()),
      theme: AppTheme.light,
      overrides: [patientRepositoryProvider.overrideWithValue(repo)],
    );
    await t.pumpAndSettle();
    expect(find.text('Leave a review'), findsNothing);
    c.read(openPastSessionsProvider.notifier).state = true;
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Leave a review'), findsOneWidget);
    expect(c.read(openPastSessionsProvider), isFalse);
  });

  testWidgets('QA7 rate-request tap after Home loaded shows no review button', (
    t,
  ) async {
    final repo = _Repo();
    final show = ValueNotifier(false);
    final c = await pumpLocalized(
      t,
      Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, v, _) =>
              v ? const PatientSessionsScreen() : const SizedBox(),
        ),
      ),
      theme: AppTheme.light,
      overrides: [patientRepositoryProvider.overrideWithValue(repo)],
    );
    // Home's banner keeps these alive from app start.
    final sub = c.listen(reviewPromptProvider, (_, _) {});
    await t.pumpAndSettle();
    expect(c.read(patientSessionsProvider).hasValue, isTrue);

    // The therapist marks today's visit complete; the server sends the rate request.
    repo.sessions = [_s('a', SessionStatus.completed, 0)];
    repo.reviewable = {'a'};

    // Notification tap: the flag, then the tab.
    c.read(openPastSessionsProvider.notifier).state = true;
    show.value = true;
    await t.pumpAndSettle();
    sub.close();
    // Fails: Past is empty / no button -- the cached lists are from before.
    expect(find.text('Leave a review'), findsOneWidget);
  });
}
