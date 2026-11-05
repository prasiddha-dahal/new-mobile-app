import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/features/notifications/data/models/notification_models.dart';
import 'package:sahayatri_care_connect/features/notifications/presentation/providers/notification_providers.dart';

import 'notification_fakes.dart';

/// Marking a notification read is **optimistic**: the row flips the instant it
/// is tapped, the request follows, and a refusal puts the feed back the way it
/// was. That is three moments a test has to be able to stand in, which is what
/// the fake's `writeDelay` is for.
void main() {
  group('optimistic read state', () {
    /// A container with the API faked out and the feed already loaded.
    Future<(ProviderContainer, FakeNotificationApi)> loaded(
      List<NotificationDto> items, {
      Object? writeError,
    }) async {
      final api = FakeNotificationApi(
        feed: feedOf(items),
        writeError: writeError,
      );
      final container = ProviderContainer(
        overrides: [notificationApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      await container.read(notificationFeedProvider.future);
      return (container, api);
    }

    NotificationListDto current(ProviderContainer c) =>
        c.read(notificationFeedProvider).requireValue;

    test('the row flips before the request is even awaited', () async {
      final (container, api) = await loaded([
        notification(id: 'a'),
        notification(id: 'b'),
      ]);

      // Deliberately not awaited: the screen navigates on the next line, so
      // everything the reader sees has to already be true here.
      final pending = container
          .read(notificationFeedProvider.notifier)
          .markRead('a');

      expect(current(container).notifications.first.isUnread, isFalse);
      expect(current(container).unread, 1);

      await pending;
      expect(api.readCalls, ['a']);
    });

    test('and the list keeps its order and its length', () async {
      final (container, _) = await loaded([
        notification(id: 'a'),
        notification(id: 'b'),
        notification(id: 'c'),
      ]);

      await container.read(notificationFeedProvider.notifier).markRead('b');

      // No re-sort, no re-fetch: the row the finger was on must not move.
      expect(current(container).notifications.map((n) => n.id), [
        'a',
        'b',
        'c',
      ]);
      expect(current(container).notifications[1].isUnread, isFalse);
      expect(current(container).notifications[0].isUnread, isTrue);
    });

    test('a failed write puts the whole feed back', () async {
      final (container, _) = await loaded([
        notification(id: 'a'),
        notification(id: 'b'),
      ], writeError: httpError(500));

      final result = await container
          .read(notificationFeedProvider.notifier)
          .markRead('a');

      expect(result.isLeft(), isTrue);
      result.match((f) => expect(f, isA<ServerFailure>()), (_) => fail('ok?'));
      expect(current(container).notifications.first.isUnread, isTrue);
      expect(current(container).unread, 2);
    });

    test('marking an already-read row spends no request', () async {
      final (container, api) = await loaded([
        notification(id: 'a', readAt: DateTime.now()),
      ]);

      final result = await container
          .read(notificationFeedProvider.notifier)
          .markRead('a');

      expect(result.isRight(), isTrue);
      expect(api.readCalls, isEmpty);
    });

    test('mark-all clears the count, not just the rows on this page', () async {
      final (container, api) = await loaded([notification(id: 'a')]);
      // The page holds one row; the user has more unread further down the
      // feed than this page fetched.
      container.read(notificationFeedProvider.notifier).state = AsyncData(
        NotificationListDto(
          notifications: current(container).notifications,
          total: 40,
          unread: 12,
        ),
      );

      await container.read(notificationFeedProvider.notifier).markAllRead();

      expect(current(container).unread, 0);
      expect(current(container).notifications.single.isUnread, isFalse);
      expect(api.readAllCalls, 1);
    });

    test('a failed mark-all rolls every row back', () async {
      final (container, _) = await loaded([
        notification(id: 'a'),
        notification(id: 'b'),
      ], writeError: httpError(503));

      final result = await container
          .read(notificationFeedProvider.notifier)
          .markAllRead();

      expect(result.isLeft(), isTrue);
      expect(current(container).notifications.every((n) => n.isUnread), isTrue);
      expect(current(container).unread, 2);
    });

    test(
      'a refresh that lands mid-write is not undone by the rollback',
      () async {
        final api = FakeNotificationApi(
          feed: feedOf([notification(id: 'a')]),
          writeError: httpError(500),
        );
        final container = ProviderContainer(
          overrides: [notificationApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        await container.read(notificationFeedProvider.future);

        final notifier = container.read(notificationFeedProvider.notifier);
        final pending = notifier.markRead('a');

        // The server answers the refresh first and says the row is read — it
        // was read on another device. Reverting to the pre-tap snapshot now
        // would undo the truth to restore a guess.
        final readOnServer = notification(id: 'a', readAt: DateTime.now());
        api.feed = feedOf([readOnServer]);
        await notifier.refresh();

        await pending;
        expect(current(container).notifications.single.isUnread, isFalse);
      },
    );

    test(
      'the unread count provider follows the feed and is 0 on error',
      () async {
        final (container, _) = await loaded([
          notification(id: 'a'),
          notification(id: 'b', readAt: DateTime.now()),
        ]);
        expect(container.read(unreadCountProvider), 1);

        await container.read(notificationFeedProvider.notifier).markRead('a');
        expect(container.read(unreadCountProvider), 0);
      },
    );

    test(
      'a failed load surfaces a typed Failure, not a raw DioException',
      () async {
        final api = FakeNotificationApi(listError: httpError(503));
        final container = ProviderContainer(
          overrides: [notificationApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(notificationFeedProvider.future),
          throwsA(isA<ServerUnavailableFailure>()),
        );
        expect(container.read(unreadCountProvider), 0);
      },
    );
  });
}
