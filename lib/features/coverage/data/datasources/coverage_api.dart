import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/coverage_models.dart';

part 'coverage_api.g.dart';

/// Service-area coverage. Public: choosing where you live is how the screen
/// is used, and gating it behind a session would hide the product from the
/// people deciding whether to sign up.
@RestApi()
abstract class CoverageApi {
  factory CoverageApi(Dio dio, {String baseUrl}) = _CoverageApi;

  @GET('/coverage/areas')
  Future<ServiceAreaListDto> areas();

  @GET('/coverage/therapists')
  Future<CoverageDto> coverage({@Query('areaId') String? areaId});
}
