import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/clinic_models.dart';

part 'clinic_api.g.dart';

/// Clinic directory endpoints. Both are public — no bearer token required.
///
/// Booking is absent on purpose: there is no clinic slots endpoint and no
/// `clinicId` on `Session`, so there is nothing to call. See TODO(api) A12 in
/// docs/TODO_REGISTER.md.
@RestApi()
abstract class ClinicApi {
  factory ClinicApi(Dio dio, {String baseUrl}) = _ClinicApi;

  @GET('/clinics')
  Future<ClinicListDto> listClinics({
    @Query('search') String? search,
    @Query('city') String? city,
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  @GET('/clinics/{id}')
  Future<ClinicDto> getClinic(@Path('id') String id);
}
