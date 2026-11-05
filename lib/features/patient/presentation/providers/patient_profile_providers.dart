import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/models/care_models.dart';
import 'patient_providers.dart';

/// The patient's care record — `GET /patients/me/profile`.
///
/// Separate from [authProvider]'s `User`: the two rows overlap on name, phone
/// and city, but home address, medical history, date of birth, gender and the
/// emergency contact exist only here. Edit profile used to read and write the
/// `User` row alone, which is why half its fields had nowhere to go.
///
/// Returns null rather than throwing on 404. A patient who signed up before
/// the profile table existed — or who has simply never saved one — has no row
/// until the first `PUT` upserts it, and that is not an error state to render.
final patientProfileProvider = FutureProvider<PatientProfileDto?>((ref) async {
  try {
    return await ref.watch(patientApiProvider).getMyProfile();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    throw mapDioErrorToFailure(e);
  }
});

final patientProfileActionsProvider = Provider<PatientProfileActions>(
  (ref) => PatientProfileActions(ref),
);

class PatientProfileActions {
  PatientProfileActions(this._ref);
  final Ref _ref;

  /// Writes the care fields. Upserts, so it works for a patient with no row.
  ///
  /// Date of birth and gender are deliberately absent: `PatientProfileUpdate`
  /// dropped them when they became admin-only, so sending either is a 422.
  Future<AppResult<PatientProfileDto>> save(
    PatientProfileUpdateDto body,
  ) async {
    try {
      final updated = await _ref.read(patientApiProvider).updateMyProfile(body);
      _ref.invalidate(patientProfileProvider);
      return Right(updated);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
