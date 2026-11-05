import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/notification_models.dart';

part 'notification_api.g.dart';

/// The signed-in user's own feed. Every route is scoped to the bearer token
/// server-side, so there is no user id in any path.
@RestApi()
abstract class NotificationApi {
  factory NotificationApi(Dio dio, {String baseUrl}) = _NotificationApi;

  @GET('/notifications')
  Future<NotificationListDto> list({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 50,
  });

  @POST('/notifications/{id}/read')
  Future<void> markRead(@Path('id') String id);

  @POST('/notifications/read-all')
  Future<void> markAllRead();
}
