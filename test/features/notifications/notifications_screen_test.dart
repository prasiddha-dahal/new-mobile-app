import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahayatri_care_connect/core/navigation/tab_requests.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/widgets/app_header.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';
import 'package:sahayatri_care_connect/core/widgets/state_views.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/notifications/data/models/notification_models.dart';
import 'package:sahayatri_care_connect/features/notifications/presentation/providers/notification_providers.dart';
import 'package:sahayatri_care_connect/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:sahayatri_care_connect/features/notifications/presentation/widgets/notification_visuals.dart';

import '../../core/tab_shell_harness.dart';
import 'notification_fakes.dart';

/// The feed as it is actually mounted: inside the role's `TabShell`, under
/// the one `AppHeader`, with the bottom bar below it.
void main() {
  User userOf(String role) => User(
    id: 'u1',
    name: role == 'THERAPIST' ? 'Anisha Shrestha' : 'Aakar Sharma',
    email: 'test@example.com',
    role: role,
    status: 'APPROVED',
  );

  /// The real screen in the patient's Home branch, with the API faked.
  /// [detail] adds routes reachable by `push` from there.
  Future<(GoRouter, FakeNotificationApi)> pumpPatient(
    WidgetTester tester, {
    List<NotificationDto> items = const [],
    Object? listError,
    Object? writeError,
    Duration writeDelay = Duration.zero,
    Map<String, Widget> detail = const {},
  }) async {
    final api = FakeNotificationApi(
      feed: feedOf(items),
      listError: listError,
      writeError: writeError,
    )..writeDelay = writeDelay;
    final router = patientShellHarnessRouter(
      initialLocation: '/patient/notifications',
      detailRoutes: {
        0: {
          '/patient/notifications': const NotificationsScreen(),
          ...detail,
        },
      },
      screens: const [
        Scaffold(body: Text('home')),
        Scaffold(body: Text('sessions')),
        Scaffold(body: Text('recovery')),
        Scaffold(body: Text('account')),
      ],
    );

    await tester.pumpWidget(
      shellHarnessApp(
        router,
        overrides: [
          authProvider.overrideWith((_) => userOf('PATIENT')),
          notificationApiProvider.overrideWithValue(api),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return (router, api);
  }

  /// The same screen in the therapist shell. It lives in that shell's Account
  /// branch (index 3), exactly as `app_router.dart` declares it.
  Future<GoRouter> pumpTherapist(
    WidgetTester tester, {
    List<NotificationDto> items = const [],
    Map<String, Widget> detail = const {},
  }) async {
    final api = FakeNotificationApi(feed: feedOf(items));
    final router = therapistShellHarnessRouter(
      initialLocation: '/therapist/account',
      detailRoutes: {3: detail},
      screens: const [
        Scaffold(body: Text('home')),
        Scaffold(body: Text('schedule')),
        Scaffold(body: Text('requests')),
        NotificationsScreen(),
      ],
    );

    await tester.pumpWidget(
      shellHarnessApp(
        router,
        overrides: [
          authProvider.overrideWith((_) => userOf('THERAPIST')),
          notificationApiProvider.overrideWithValue(api),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// The fill of the card carrying [title].
  Color cardColour(WidgetTester tester, String title) {
    final card = find.ancestor(
      of: find.text(title),
      matching: find.byType(NotificationCard),
    );
    final box = tester.widget<Container>(
      find.descendant(of: card, matching: find.byType(Container)).first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  /// Whether the card carrying [title] shows the small amber unread dot.
  bool hasUnreadDot(WidgetTester tester, String title) {
    final card = find.ancestor(
      of: find.text(title),
      matching: find.byType(NotificationCard),
    );
    return tester
        .widgetList<Container>(
          find.descendant(of: card, matching: find.byType(Container)),
        )
        .any((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.shape == BoxShape.circle &&
              d.color == AppColors.amberBrand;
        });
  }

  group('the title block', () {
    testWidgets('is the design\'s eyebrow and title, not a second header', (
      tester,
    ) async {
      await pumpPatient(tester);

      expect(find.text('STAY UP TO DATE'), findsOneWidget);
      expect(find.text('All notifications'), findsOneWidget);

      // `TabShell` mounts the one header above this route. The old in-page
      // row — a back arrow and a centred "Notifications" — was a second
      // header under the real one, and its arrow pointed nowhere: this is a
      // tab root.
      expect(find.byType(AppHeader), findsOneWidget);
      // Scoped to the screen. The bottom bar draws its labels now, so its
      // "Notifications" tab is a second match for a bare `find.text` — and it
      // is supposed to be there. What must not come back is a title row
      // *inside the page*, which is what this pins.
      expect(
        find.descendant(
          of: find.byType(NotificationsScreen),
          matching: find.text('Notifications'),
        ),
        findsNothing,
      );
      // ...and the tab label is the one place the word is allowed, so say so
      // rather than leaving the scoping above looking like a concession.
      expect(
        find.descendant(
          of: find.byType(PatientNav),
          matching: find.text('Notifications'),
        ),
        findsOneWidget,
      );
      expect(find.byType(AppHeaderBackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('empty and error', () {
    testWidgets('an empty feed reads as caught up, not as broken', (
      tester,
    ) async {
      // The expected state for nearly everyone today: the producers that fill
      // this feed are on an unmerged API branch.
      await pumpPatient(tester);

      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.byType(NotificationCard), findsNothing);
      // Nothing is promised that the API does not send. The copy this
      // replaced advertised "session reminders", which nothing produces.
      expect(find.textContaining('reminder'), findsNothing);
      // Still pullable — an empty feed is exactly where someone tugs.
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('a failed load offers a retry that actually retries', (
      tester,
    ) async {
      final (_, api) = await pumpPatient(tester, listError: httpError(503));

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('Server unavailable'), findsOneWidget);
      expect(api.listCalls, 1);

      api.listError = null;
      api.feed = feedOf([notification(title: 'Booking confirmed')]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(api.listCalls, 2);
      expect(find.byType(ErrorStateView), findsNothing);
      expect(find.text('Booking confirmed'), findsOneWidget);
    });
  });

  group('rows', () {
    testWidgets('unread is a green card with an amber dot; read is white', (
      tester,
    ) async {
      await pumpPatient(
        tester,
        items: [
          notification(id: 'a', title: 'Booking confirmed'),
          notification(
            id: 'b',
            title: 'Payment received',
            type: 'PAYMENT_RECEIVED',
            readAt: DateTime.now(),
          ),
        ],
      );

      expect(cardColour(tester, 'Booking confirmed'), AppColors.pinePale);
      expect(hasUnreadDot(tester, 'Booking confirmed'), isTrue);

      expect(cardColour(tester, 'Payment received'), AppColors.card);
      expect(hasUnreadDot(tester, 'Payment received'), isFalse);
    });

    testWidgets('the pill stays visible on both card fills', (tester) async {
      await pumpPatient(
        tester,
        items: [
          notification(id: 'a', title: 'Booking confirmed'),
          notification(
            id: 'b',
            title: 'Payment received',
            type: 'PAYMENT_RECEIVED',
            readAt: DateTime.now(),
          ),
        ],
      );

      // Both rows carry a DONE pill, whose own fill is the unread row's fill.
      for (final title in ['Booking confirmed', 'Payment received']) {
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(NotificationCard),
        );
        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: find.descendant(
                  of: card,
                  matching: find.text(NotificationPill.done.label),
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (pill.decoration! as BoxDecoration).color,
          isNot(cardColour(tester, title)),
          reason: '$title: the badge disappeared into the card',
        );
      }
    });

    testWidgets('a narrow phone at a large text scale does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPatient(
        tester,
        items: [
          notification(
            id: 'a',
            type: 'SESSION_RESCHEDULE_REQUESTED',
            title: 'Reschedule requested by your therapist',
            body: 'Anisha Shrestha asked to move Tuesday 09:00 to 11:00.',
          ),
        ],
      );

      // The title block competes with "Mark all read" for one row, and the
      // control is sized by the text scale. pumpAndSettle rethrows a RenderFlex
      // overflow, so getting here is most of the assertion; what the checks
      // add is that neither side was squeezed out of existence.
      expect(find.text('STAY UP TO DATE'), findsOneWidget);
      expect(find.byKey(NotificationsScreen.markAllReadKey), findsOneWidget);
      expect(find.byType(NotificationCard), findsOneWidget);
    });

    testWidgets('every type in the registry renders, plus one nobody knows', (
      tester,
    ) async {
      await pumpPatient(
        tester,
        items: [
          for (var i = 0; i < notificationTypes.length; i++)
            notification(
              id: 'n$i',
              type: notificationTypes[i],
              title: notificationTypes[i],
              body: 'Body for ${notificationTypes[i]}',
            ),
          notification(
            id: 'future',
            type: 'INVENTED_BY_A_LATER_API',
            title: 'Something new',
            body: 'A key this build has never seen.',
            // Also the clock-skew case, in the same row: a createdAt in the
            // future must not print a negative duration.
            createdAt: DateTime.now().add(const Duration(hours: 3)),
          ),
        ],
      );

      // No exception, and the list built. The rest scroll off a 600px test
      // surface, so assert on what is on screen plus the one that matters.
      expect(tester.takeException(), isNull);
      expect(find.text('SESSION_BOOKED'), findsOneWidget);
      expect(find.text(NotificationPill.done.label), findsWidgets);

      await tester.scrollUntilVisible(find.text('Something new'), 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(unknownNotificationGlyph), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      expect(find.textContaining('-'), findsNothing);
    });
  });

  group('marking read', () {
    testWidgets('a tap flips the row without waiting for the server', (
      tester,
    ) async {
      final (_, api) = await pumpPatient(
        tester,
        items: [notification(id: 'a', title: 'Booking confirmed')],
        writeDelay: const Duration(milliseconds: 50),
      );

      expect(cardColour(tester, 'Booking confirmed'), AppColors.pinePale);

      await tester.tap(find.text('Booking confirmed'));
      await tester.pump();

      // The server has not answered yet — the row is read on screen anyway.
      expect(api.readCalls, ['a']);
      expect(cardColour(tester, 'Booking confirmed'), AppColors.card);
      expect(hasUnreadDot(tester, 'Booking confirmed'), isFalse);

      await tester.pumpAndSettle();
      expect(api.readCalls, ['a']);
      // Never re-fetched: a refresh here could hand back a differently
      // ordered list and move the row out from under the finger.
      expect(api.listCalls, 1);
    });

    testWidgets('and puts it back, with an explanation, when that fails', (
      tester,
    ) async {
      await pumpPatient(
        tester,
        items: [notification(id: 'a', title: 'Booking confirmed')],
        writeError: httpError(500),
        writeDelay: const Duration(milliseconds: 50),
      );

      await tester.tap(find.text('Booking confirmed'));
      await tester.pump();
      expect(cardColour(tester, 'Booking confirmed'), AppColors.card);

      await tester.pumpAndSettle();
      expect(cardColour(tester, 'Booking confirmed'), AppColors.pinePale);
      expect(hasUnreadDot(tester, 'Booking confirmed'), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('mark all read is offered only while it would do something', (
      tester,
    ) async {
      final (_, api) = await pumpPatient(
        tester,
        items: [
          notification(id: 'a', title: 'Booking confirmed'),
          notification(id: 'b', title: 'Payment received'),
        ],
        writeDelay: const Duration(milliseconds: 50),
      );

      // The design put this in the app bar, which the shell now owns. It sits
      // to the right of the section title instead — the only row with space
      // beside it, still above the list it acts on.
      final button = find.byKey(NotificationsScreen.markAllReadKey);
      expect(button, findsOneWidget);
      expect(
        tester.getRect(button).top,
        lessThan(tester.getRect(find.byType(NotificationCard).first).top),
      );

      await tester.tap(button);
      await tester.pump();

      expect(cardColour(tester, 'Booking confirmed'), AppColors.card);
      expect(cardColour(tester, 'Payment received'), AppColors.card);

      await tester.pumpAndSettle();
      expect(api.readAllCalls, 1);
      expect(find.byKey(NotificationsScreen.markAllReadKey), findsNothing);
    });

    testWidgets('and is absent when everything is already read', (
      tester,
    ) async {
      await pumpPatient(
        tester,
        items: [notification(id: 'a', readAt: DateTime.now())],
      );
      expect(find.byKey(NotificationsScreen.markAllReadKey), findsNothing);
    });
  });

  group('following the reference', () {
    testWidgets('a patient session row switches to the Sessions tab', (
      tester,
    ) async {
      await pumpPatient(
        tester,
        items: [
          notification(
            id: 'a',
            title: 'Booking confirmed',
            refType: 'SESSION',
            refId: 's1',
          ),
        ],
      );

      await tester.tap(find.text('Booking confirmed'));
      await tester.pumpAndSettle();

      expect(find.text('sessions'), findsOneWidget);
    });

    group('a "rate your visit" row', () {
      ProviderContainer containerOf(WidgetTester tester) =>
          ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

      testWidgets('asks the Sessions tab to open on Past', (tester) async {
        await pumpPatient(
          tester,
          items: [
            notification(
              id: 'a',
              type: 'SESSION_RATE_REQUEST',
              title: 'Rate your last session',
              refType: 'SESSION',
              refId: 's1',
            ),
          ],
        );

        await tester.tap(find.text('Rate your last session'));
        await tester.pumpAndSettle();

        expect(find.text('sessions'), findsOneWidget);
        expect(containerOf(tester).read(openPastSessionsProvider), isTrue);
      });

      testWidgets('an ordinary session row does not', (tester) async {
        await pumpPatient(
          tester,
          items: [
            notification(
              id: 'a',
              type: 'SESSION_BOOKED',
              title: 'Booking confirmed',
              refType: 'SESSION',
              refId: 's1',
            ),
          ],
        );

        await tester.tap(find.text('Booking confirmed'));
        await tester.pumpAndSettle();

        expect(find.text('sessions'), findsOneWidget);
        expect(containerOf(tester).read(openPastSessionsProvider), isFalse);
      });
    });

    testWidgets('the therapist\'s goes to their own list, not the patient\'s', (
      tester,
    ) async {
      // The bug: this used to be `context.go('/patient/sessions')` for
      // everyone, and the router bounced the therapist to /therapist/home.
      await pumpTherapist(
        tester,
        items: [
          notification(
            id: 'a',
            type: 'SESSION_NEW_BOOKING',
            title: 'New booking',
            refType: 'SESSION',
            refId: 's1',
          ),
        ],
      );

      await tester.tap(find.text('New booking'));
      await tester.pumpAndSettle();

      expect(find.text('requests'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('a report opens inside this tab, so Back returns to the feed', (
      tester,
    ) async {
      await pumpPatient(
        tester,
        items: [
          notification(
            id: 'a',
            type: 'REPORT_UPLOADED',
            title: 'New report',
            refType: 'REPORT',
            refId: 'r1',
          ),
        ],
        detail: {'/patient/reports': const Scaffold(body: Text('reports'))},
      );

      await tester.tap(find.text('New report'));
      await tester.pumpAndSettle();
      expect(find.text('reports'), findsOneWidget);

      // Pushed, not `go`ne to: the feed is still underneath.
      final context = tester.element(find.text('reports'));
      expect(GoRouter.of(context).canPop(), isTrue);
      GoRouter.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('All notifications'), findsOneWidget);
    });

    testWidgets('a row pointing nowhere marks read and stays put', (
      tester,
    ) async {
      // PAYMENT has no destination: there is no payment-history screen, and
      // the saved-cards screen is not one. Going nowhere beats going wrong.
      final (router, api) = await pumpPatient(
        tester,
        items: [
          notification(
            id: 'a',
            type: 'PAYMENT_RECEIVED',
            title: 'Payment received',
            refType: 'PAYMENT',
            refId: 'p1',
          ),
        ],
      );

      await tester.tap(find.text('Payment received'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/patient/notifications',
      );
      expect(find.text('All notifications'), findsOneWidget);
      expect(api.readCalls, ['a']);
      expect(cardColour(tester, 'Payment received'), AppColors.card);
    });
  });
}
