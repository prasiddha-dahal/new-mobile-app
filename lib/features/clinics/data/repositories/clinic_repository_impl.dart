import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/clinic.dart';
import '../../domain/repositories/clinic_repository.dart';
import '../datasources/clinic_api.dart';

class ClinicRepositoryImpl implements ClinicRepository {
  ClinicRepositoryImpl(this._api);

  final ClinicApi _api;

  Future<AppResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<Clinic>>> findClinics({String? search, String? city}) =>
      _guard(() async {
        final response = await _api.listClinics(
          search: _blankToNull(search),
          city: _blankToNull(city),
        );
        return response.clinics.map((c) => c.toEntity()).toList();
      });

  @override
  Future<AppResult<Clinic>> getClinic(String id) =>
      _guard(() async => (await _api.getClinic(id)).toEntity());

  @override
  Future<AppResult<String>> bookVisit({
    required String clinicId,
    required String paymentMethod,
  }) async {
    // `Session` has no `clinicId` and there is no clinic slots endpoint, so a
    // clinic visit cannot be recorded against the clinic that hosts it. Booking
    // it as an ordinary home visit would put the patient's own address on a
    // session they were told to travel to — the flow stops here with a typed
    // failure the UI turns into an honest message instead.
    // TODO(api): clinic slots + `clinicId` on Session (A12 in docs/TODO_REGISTER.md).
    return const Left(
      NotImplementedFailure(
        'POST /sessions (clinicId)',
        'Clinic visits cannot be booked from the app until clinic scheduling '
            'is switched on.',
      ),
    );
  }

  /// An empty filter must be omitted, not sent as `""` — the backend treats a
  /// blank string as a real "contains" filter and returns nothing.
  static String? _blankToNull(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
