/// Stand-ins for the availability layer, shared by the unit, widget and
/// golden tests.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/entities/working_hours.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/repositories/therapist_availability_repository.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/availability_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';

/// A repository whose answers the test dictates, and which records what it
/// was asked to save.
class FakeAvailabilityRepository implements TherapistAvailabilityRepository {
  FakeAvailabilityRepository({
    this.stored = WorkingHours.fallback,
    this.readFailure,
    this.saveFailure,
    this.openedSlots = 42,
  });

  /// What [getWorkingHours] answers.
  WorkingHours stored;

  /// When set, [getWorkingHours] fails with it instead.
  final Failure? readFailure;

  /// When set, [saveWorkingHours] fails with it instead.
  Failure? saveFailure;

  /// The `updated` count a successful save reports back.
  int openedSlots;

  /// Every pattern [saveWorkingHours] was handed, in order.
  final List<WorkingHours> saved = [];

  /// The `from` of the most recent save.
  DateTime? savedFrom;

  /// Completes the next save only when the test says so, so a widget test can
  /// look at the in-flight state.
  Completer<void>? gate;

  @override
  Future<AppResult<WorkingHours>> getWorkingHours() async {
    final failure = readFailure;
    if (failure != null) return Left(failure);
    return Right(stored);
  }

  @override
  Future<AppResult<WorkingHoursSaved>> saveWorkingHours(
    WorkingHours hours, {
    required DateTime from,
  }) async {
    saved.add(hours);
    savedFrom = from;
    await gate?.future;

    final failure = saveFailure;
    if (failure != null) return Left(failure);

    stored = hours;
    final window = AvailabilityWindow.fromDate(from);
    return Right(
      WorkingHoursSaved(
        openedSlots: openedSlots,
        fromDate: window.fromDate,
        toDate: window.toDate,
      ),
    );
  }
}

/// Overrides enough for [TherapistAvailabilityScreen] to render without a
/// network.
///
/// [therapistSessionsProvider] is included because the booked-appointment note
/// reads it; left alone it would reach for a real Dio and the screen would
/// render one line differently in tests than it does in the app.
List<Override> availabilityOverrides({
  required FakeAvailabilityRepository repository,
  List<Session> sessions = const [],
}) => [
  therapistAvailabilityRepositoryProvider.overrideWithValue(repository),
  therapistSessionsProvider.overrideWith((_) async => sessions),
];

/// A scheduled appointment on [date], for the booked-appointment note.
Session scheduledSession({required DateTime date, String time = '10:00'}) =>
    Session(
      id: 'ses-${date.toIso8601String()}-$time',
      therapistId: 'thr-1',
      therapistName: 'Dr. Jane Smith',
      patientId: 'pat-1',
      patientName: 'Ramesh A.',
      patientPhone: '9800000004',
      date: date,
      time: time,
      type: 'HOME_VISIT',
      status: SessionStatus.scheduled,
      address: 'Pulchowk',
      fee: 1500,
    );
