import 'package:dio/dio.dart';
import 'package:sahayatri_care_connect/features/notifications/data/datasources/notification_api.dart';
import 'package:sahayatri_care_connect/features/notifications/data/models/notification_models.dart';

/// A hand-rolled stand-in for the Retrofit client.
///
/// Three methods is a small enough surface that a fake beats a mock: it can
/// also record what was called, which is how the optimistic tests tell "the
/// UI moved and the request went out" from "the UI moved".
class FakeNotificationApi implements NotificationApi {
  FakeNotificationApi({
    NotificationListDto? feed,
    this.listError,
    this.writeError,
  }) : feed = feed ?? const NotificationListDto();

  /// What [list] answers. Reassignable, so a test can change what a refresh
  /// finds.
  NotificationListDto feed;

  /// Thrown by [list] when set.
  Object? listError;

  /// Thrown by [markRead] and [markAllRead] when set.
  Object? writeError;

  /// How long a write takes to answer.
  ///
  /// Zero would resolve inside the same microtask drain as the `pump()` that
  /// follows a tap, which is exactly the window an optimistic update lives
  /// in — a widget test could never see the row flipped *before* the server
  /// replied, only after. A delay makes that window observable.
  Duration writeDelay = Duration.zero;

  int listCalls = 0;
  final List<String> readCalls = [];
  int readAllCalls = 0;

  Future<void> _write() async {
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
    if (writeError != null) throw writeError!;
  }

  @override
  Future<NotificationListDto> list({int skip = 0, int limit = 50}) async {
    listCalls++;
    if (listError != null) throw listError!;
    return feed;
  }

  @override
  Future<void> markRead(String id) {
    readCalls.add(id);
    return _write();
  }

  @override
  Future<void> markAllRead() {
    readAllCalls++;
    return _write();
  }
}

/// One row, with sensible defaults so a test only states what it cares about.
NotificationDto notification({
  String id = 'n1',
  String type = 'SESSION_BOOKED',
  String title = 'Booking confirmed',
  String body = 'Anisha Shrestha will visit tomorrow at 9:00.',
  DateTime? readAt,
  String? refType,
  String? refId,
  DateTime? createdAt,
}) => NotificationDto(
  id: id,
  type: type,
  title: title,
  body: body,
  readAt: readAt,
  refType: refType,
  refId: refId,
  createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 2)),
);

/// A feed whose `unread` matches its rows, which is what the server sends.
NotificationListDto feedOf(List<NotificationDto> items) => NotificationListDto(
  notifications: items,
  total: items.length,
  unread: items.where((n) => n.isUnread).length,
);

/// A `DioException` shaped like a real failure response.
DioException httpError(int statusCode) {
  final options = RequestOptions(path: '/notifications');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: statusCode),
  );
}
