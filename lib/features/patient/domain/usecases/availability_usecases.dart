import '../../../../core/error/failures.dart';
import '../entities/therapist.dart';
import '../repositories/availability_repository.dart';

/// Open slots for a set of therapists over one date range.
class GetTherapistAvailabilityUseCase {
  const GetTherapistAvailabilityUseCase(this._repository);
  final AvailabilityRepository _repository;

  Future<Map<String, AppResult<List<TherapistSlot>>>> call({
    required List<String> therapistIds,
    required String fromDate,
    required String toDate,
  }) => _repository.slotsForTherapists(
    therapistIds: therapistIds,
    fromDate: fromDate,
    toDate: toDate,
  );
}

/// Drops what has been cached, so a retry actually retries.
class ForgetTherapistAvailabilityUseCase {
  const ForgetTherapistAvailabilityUseCase(this._repository);
  final AvailabilityRepository _repository;

  void call([Iterable<String>? therapistIds]) =>
      _repository.invalidate(therapistIds);
}
