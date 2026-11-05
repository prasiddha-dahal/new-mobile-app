import '../../../../core/error/failures.dart';
import '../entities/clinic.dart';

abstract class ClinicRepository {
  /// Clinic directory, optionally narrowed by free text and city.
  Future<AppResult<List<Clinic>>> findClinics({String? search, String? city});

  Future<AppResult<Clinic>> getClinic(String id);

  /// Books a visit at a clinic, returning the booking reference.
  ///
  /// Always fails with [NotImplementedFailure] today — `Session` has no
  /// `clinicId`, so a visit cannot be recorded against the clinic that hosts it.
  /// Kept in the interface so the UI flow is complete and switching it on is a
  /// one-line change in the implementation.
  Future<AppResult<String>> bookVisit({
    required String clinicId,
    required String paymentMethod,
  });
}
