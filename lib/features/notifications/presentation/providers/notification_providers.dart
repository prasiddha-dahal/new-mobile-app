import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/notification_api.dart';
import '../../data/models/notification_models.dart';

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.watch(dioProvider));
});

/// The signed-in user's feed, newest first, and the two writes against it.
///
/// A notifier rather than a `FutureProvider` because marking read is
/// **optimistic**: the row has to flip the instant it is tapped and roll back
/// if the server refuses, which needs state this side of the network. The
/// version this replaced invalidated the provider after every write, so each
/// tap cost a full round trip before anything moved and then re-fetched the
/// list — which can come back in a different shape and shift the row out from
/// under the finger that tapped it.
final notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeedNotifier, NotificationListDto>(
      NotificationFeedNotifier.new,
    );

class NotificationFeedNotifier extends AsyncNotifier<NotificationListDto> {
  @override
  Future<NotificationListDto> build() => _fetch();

  NotificationApi get _api => ref.read(notificationApiProvider);

  Future<NotificationListDto> _fetch() async {
    try {
      return await _api.list();
    } on DioException catch (e) {
      throw mapDioErrorToFailure(e);
    } catch (e) {
      throw UnknownFailure(e.toString());
    }
  }

  /// Re-reads the feed. Backs pull-to-refresh and the error state's retry.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// `POST /notifications/{id}/read`, optimistically.
  ///
  /// The row is flipped before the call is made — synchronously, so a caller
  /// that does not await this still sees the list updated by the time it
  /// returns — and the whole pre-flip feed is put back if the call fails.
  /// Already-read rows and rows not in the list are a no-op: `Right`, no
  /// request, so a second tap does not spend a request saying what the server
  /// already knows.
  Future<AppResult<void>> markRead(String id) {
    final before = state.valueOrNull;
    final unread =
        before != null &&
        before.notifications.any((n) => n.id == id && n.isUnread);
    if (before == null || !unread) {
      return Future.value(const Right<Failure, void>(null));
    }

    state = AsyncValue.data(before.markingRead({id}, DateTime.now()));
    return _write(() => _api.markRead(id), rollbackTo: before);
  }

  /// `POST /notifications/read-all`, on the same terms.
  Future<AppResult<void>> markAllRead() {
    final before = state.valueOrNull;
    if (before == null || before.unread == 0) {
      return Future.value(const Right<Failure, void>(null));
    }

    state = AsyncValue.data(before.markingAllRead(DateTime.now()));
    return _write(_api.markAllRead, rollbackTo: before);
  }

  /// Runs a write that has already been applied locally, restoring
  /// [rollbackTo] if it fails.
  ///
  /// The rollback is the whole feed, not the one row: it is the value that
  /// was on screen before the optimistic edit, so putting it back cannot
  /// leave a half-applied list behind. A refresh that landed while the write
  /// was in flight wins — reverting to a snapshot older than fresh server
  /// data would undo the truth to restore a guess.
  Future<AppResult<void>> _write(
    Future<void> Function() call, {
    required NotificationListDto rollbackTo,
  }) async {
    final optimistic = state.valueOrNull;
    try {
      await call();
      return const Right(null);
    } on DioException catch (e) {
      if (identical(state.valueOrNull, optimistic)) {
        state = AsyncValue.data(rollbackTo);
      }
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      if (identical(state.valueOrNull, optimistic)) {
        state = AsyncValue.data(rollbackTo);
      }
      return Left(UnknownFailure(e.toString()));
    }
  }
}

/// Unread count for the feed; 0 while loading or on error, so a transient
/// failure never paints a count that isn't there.
///
/// Drives the "Mark all read" control on the notifications screen — it is
/// only offered when it would do something. Nothing else reads it: the bottom
/// bar's Notifications tab draws an icon and nothing else, and adding a badge
/// mechanism to it was not this branch's to invent.
final unreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationFeedProvider)
      .maybeWhen(data: (feed) => feed.unread, orElse: () => 0);
});
