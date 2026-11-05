import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../patient/presentation/providers/availability_providers.dart'
    show forgetTherapistAvailabilityUseCaseProvider;
import '../../data/repositories/therapist_availability_repository_impl.dart';
import '../../domain/entities/working_hours.dart';
import '../../domain/repositories/therapist_availability_repository.dart';
import '../../domain/usecases/availability_usecases.dart';
import 'therapist_providers.dart';

final therapistAvailabilityRepositoryProvider =
    Provider<TherapistAvailabilityRepository>((ref) {
      return TherapistAvailabilityRepositoryImpl(
        ref.watch(therapistApiProvider),
      );
    });

final getWorkingHoursUseCaseProvider = Provider<GetWorkingHoursUseCase>(
  (ref) => GetWorkingHoursUseCase(
    ref.watch(therapistAvailabilityRepositoryProvider),
  ),
);

final saveWorkingHoursUseCaseProvider = Provider<SaveWorkingHoursUseCase>(
  (ref) => SaveWorkingHoursUseCase(
    ref.watch(therapistAvailabilityRepositoryProvider),
  ),
);

/// The weekly pattern the API currently holds.
///
/// Errors are surfaced rather than swallowed into a default. A screen that
/// opened on `WorkingHours.fallback` after a failed read would show Mon–Fri
/// 9–6 to a therapist who works weekends, which is the class of bug this
/// feature replaces.
final workingHoursProvider = FutureProvider<WorkingHours>((ref) async {
  final result = await ref.watch(getWorkingHoursUseCaseProvider).call();
  return result.fold((failure) => throw failure, (hours) => hours);
});

/// How many appointments in the write horizon are already sold.
///
/// Counted from [therapistSessionsProvider] rather than from the slot grid:
/// `TherapistSlot` carries only `isOpen`, which collapses "booked" and
/// "closed" into one, and those two mean opposite things here. A closed slot
/// is the therapist's own decision; a booked one is a patient with an
/// appointment, and it is the reason a save is safe to make.
///
/// Null while the sessions are still loading or if they failed — the count is
/// context, and rendering it as zero would tell the therapist nothing is
/// booked when in fact nobody has looked.
final bookedSlotsInHorizonProvider = Provider<int?>((ref) {
  final sessions = ref.watch(therapistSessionsProvider).valueOrNull;
  if (sessions == null) return null;

  final window = AvailabilityWindow.fromDate(DateTime.now());
  return sessions.where((session) {
    // Only live appointments. A cancelled or completed one is not something
    // a save could disturb, so counting it would overstate the risk.
    // `isUpcoming` is the app's own definition of live and includes a
    // decline the therapist has asked for but nobody has granted yet — still
    // a patient with a booking until it is.
    if (!session.status.isUpcoming) return false;
    final day = DateTime(
      session.date.year,
      session.date.month,
      session.date.day,
    );
    return !day.isBefore(window.from) && !day.isAfter(window.to);
  }).length;
});

final availabilityActionsProvider = Provider<AvailabilityActions>(
  AvailabilityActions.new,
);

class AvailabilityActions {
  AvailabilityActions(this._ref);
  final Ref _ref;

  /// Publishes [hours] and refreshes everything that reads a slot.
  ///
  /// Deliberately **not** optimistic. The whole point of the screen is that
  /// the therapist can trust what it says is stored, and the write is a long
  /// one that can genuinely fail halfway through the fortnight. So nothing
  /// moves until the server has answered, and on success the caches are
  /// dropped rather than patched — the next read comes from the API, which is
  /// the only thing that knows what actually landed.
  Future<AppResult<WorkingHoursSaved>> saveWorkingHours(
    WorkingHours hours, {
    DateTime? from,
  }) async {
    final result = await _ref
        .read(saveWorkingHoursUseCaseProvider)
        .call(hours, from: from ?? DateTime.now());

    result.match((_) {}, (_) {
      _ref.invalidate(workingHoursProvider);
      // The therapist's own calendar.
      _ref.invalidate(ownSlotsProvider);
      // And the patient side: discovery caches slots per (therapist, window),
      // so without this a therapist's own device could keep offering the
      // hours they just replaced.
      _ref.read(forgetTherapistAvailabilityUseCaseProvider).call();
    });

    return result;
  }
}
