import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/working_hours.dart';
import '../repositories/therapist_availability_repository.dart';

class GetWorkingHoursUseCase {
  const GetWorkingHoursUseCase(this._repository);
  final TherapistAvailabilityRepository _repository;

  Future<AppResult<WorkingHours>> call() => _repository.getWorkingHours();
}

/// Publishes a weekly pattern.
///
/// Refuses locally anything [WorkingHours.problem] names, rather than sending
/// it. Each of those is a case the API accepts and then does something other
/// than what was asked — an empty day list closes the whole fortnight, an end
/// before the start writes nothing and answers `updated: 0` — so a caller that
/// sent one would be handed a success for a save that did not happen.
class SaveWorkingHoursUseCase {
  const SaveWorkingHoursUseCase(this._repository);
  final TherapistAvailabilityRepository _repository;

  Future<AppResult<WorkingHoursSaved>> call(
    WorkingHours hours, {
    required DateTime from,
  }) {
    final problem = hours.problem;
    if (problem != null) {
      return Future.value(
        Left(
          InvalidWorkingHoursFailure(problem.name, _describe(problem)),
        ),
      );
    }
    return _repository.saveWorkingHours(hours, from: from);
  }

  /// The English fallback, for the generic error surfaces. A caller that can
  /// translate should use [InvalidWorkingHoursProblem.problem] instead.
  static String _describe(WorkingHoursProblem problem) => switch (problem) {
    WorkingHoursProblem.noDays => 'Pick at least one working day.',
    WorkingHoursProblem.endNotAfterStart =>
      'The finishing time has to be after the starting time.',
    WorkingHoursProblem.sessionLongerThanDay =>
      'One session is longer than the whole working day.',
  };
}

/// Recovers the typed problem from the failure.
///
/// [InvalidWorkingHoursFailure] lives in `core/error` because [Failure] is
/// sealed, and core cannot import a feature's enum — so the reason travels as
/// its `name` and is turned back into a [WorkingHoursProblem] here, where the
/// enum is in scope.
extension InvalidWorkingHoursProblem on InvalidWorkingHoursFailure {
  WorkingHoursProblem? get problem {
    for (final value in WorkingHoursProblem.values) {
      if (value.name == reason) return value;
    }
    return null;
  }
}
