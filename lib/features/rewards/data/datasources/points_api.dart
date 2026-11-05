import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/points_models.dart';

part 'points_api.g.dart';

/// Points and referrals for the signed-in user. Role-agnostic: the same
/// routes serve patients and therapists, scoped by the bearer token.
@RestApi()
abstract class PointsApi {
  factory PointsApi(Dio dio, {String baseUrl}) = _PointsApi;

  @GET('/points/me')
  Future<PointBalanceDto> balance();

  @GET('/points/me/transactions')
  Future<PointTransactionListDto> transactions({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 50,
  });

  @GET('/points/me/referrals')
  Future<ReferralSummaryDto> referrals();

  @POST('/points/sessions/{id}/apply')
  Future<ApplyPointsResponseDto> applyToSession(
    @Path('id') String sessionId,
    @Body() ApplyPointsRequestDto body,
  );
}
