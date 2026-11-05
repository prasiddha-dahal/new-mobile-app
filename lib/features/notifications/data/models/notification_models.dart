import 'package:json_annotation/json_annotation.dart';

part 'notification_models.g.dart';

/// One row of `GET /notifications`.
@JsonSerializable()
class NotificationDto {
  const NotificationDto({
    required this.id,
    this.type = '',
    this.title = '',
    this.body = '',
    this.readAt,
    this.refType,
    this.refId,
    this.createdAt,
  });

  final String id;

  /// Machine key the UI switches on for the icon, e.g. `SESSION_BOOKED`.
  final String type;
  final String title;
  final String body;

  /// Null until read — the API stores a timestamp, not a flag.
  final DateTime? readAt;

  /// What the notification points at, so a tap can deep-link.
  final String? refType;
  final String? refId;

  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  /// This row with [at] recorded as its read time.
  ///
  /// Used for the optimistic half of a tap: the row is flipped locally before
  /// `POST /notifications/{id}/read` is even sent, and the pre-flip copy is
  /// what gets put back if that call fails.
  NotificationDto markedRead(DateTime at) => NotificationDto(
    id: id,
    type: type,
    title: title,
    body: body,
    readAt: at,
    refType: refType,
    refId: refId,
    createdAt: createdAt,
  );

  factory NotificationDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationDtoFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationDtoToJson(this);
}

@JsonSerializable()
class NotificationListDto {
  const NotificationListDto({
    this.notifications = const [],
    this.total = 0,
    this.unread = 0,
  });

  final List<NotificationDto> notifications;
  final int total;

  /// Unread rows for this user across the whole feed, not just this page —
  /// so it is kept from the server rather than counted from [notifications].
  final int unread;

  /// The feed with [ids] flipped to read, **in the same order**.
  ///
  /// Order is load-bearing. Rebuilding or re-sorting the list when a row is
  /// marked read makes the feed jump under the finger that tapped it, and the
  /// thing the reader was aiming at moves somewhere else.
  NotificationListDto markingRead(Set<String> ids, DateTime at) {
    final next = <NotificationDto>[];
    var flipped = 0;
    for (final item in notifications) {
      if (item.isUnread && ids.contains(item.id)) {
        next.add(item.markedRead(at));
        flipped++;
      } else {
        next.add(item);
      }
    }
    return NotificationListDto(
      notifications: next,
      total: total,
      unread: (unread - flipped).clamp(0, unread),
    );
  }

  /// The feed with everything read.
  ///
  /// [unread] goes to zero rather than down by the number of rows flipped
  /// here: `POST /notifications/read-all` clears the user's whole feed, which
  /// may be longer than the page this list holds.
  NotificationListDto markingAllRead(DateTime at) => NotificationListDto(
    notifications: [
      for (final item in notifications)
        item.isUnread ? item.markedRead(at) : item,
    ],
    total: total,
    unread: 0,
  );

  factory NotificationListDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationListDtoToJson(this);
}
