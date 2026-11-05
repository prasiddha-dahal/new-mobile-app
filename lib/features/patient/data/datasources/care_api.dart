import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/care_models.dart';

part 'care_api.g.dart';

/// Reports, complaints and referral — the "care extras" surface.
@RestApi()
abstract class CareApi {
  factory CareApi(Dio dio, {String baseUrl}) = _CareApi;

  /// Returns a bare array, not a `{items, total}` wrapper. For a PATIENT the
  /// `patient_id` query param is ignored — the backend scopes to the caller.
  @GET('/reports')
  Future<List<ReportDto>> listReports({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  /// Lives under `/admin` but accepts any bearer token.
  @POST('/admin/complaints')
  Future<ComplaintDto> createComplaint(@Body() ComplaintCreateDto body);

  @GET('/patients/me/referral')
  Future<ReferralDto> getReferral();
}
