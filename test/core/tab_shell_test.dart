import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';

import 'tab_shell_harness.dart';

/// The bottom bar used to be four `context.go()` calls and ten separate
/// `bottomNavigationBar:` mounts. That cost us three things at once:
///
///  * `go()` rebuilds the destination, so every tab tap replayed a page
///    transition and threw away the scroll position;
///  * `go()` replaces the stack, so Back on a tab root popped the only route
///    and closed the app;
///  * ten independent mounts drifted, and `/notifications` had no bar at all.
///
/// These tests pin the `StatefulShellRoute.indexedStack` behaviour that fixed
/// all three.
void main() {
  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    String initialLocation = '/patient/home',
    Map<int, Map<String, Widget>> detailRoutes = const {},
  }) async {
    final router = patientShellHarnessRouter(
      initialLocation: initialLocation,
      detailRoutes: detailRoutes,
      screens: const [
        ScrollableProbe(name: 'home'),
        ScrollableProbe(name: 'sessions'),
        ScrollableProbe(name: 'recovery'),
        ScrollableProbe(name: 'account'),
      ],
    );
    await tester.pumpWidget(shellHarnessApp(router));
    await tester.pumpAndSettle();
    return router;
  }

  /// Taps a tab by the semantics label the bar gives it.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  /// Whether the shell lets a system back bubble past it (i.e. out of the app).
  bool shellLetsPopThrough(WidgetTester tester) {
    final scope =
        tester.widgetList(find.byWidgetPredicate((w) => w is PopScope)).first
            as PopScope;
    return scope.canPop;
  }

  /// How far the list on the [name] tab has been scrolled.
  double offsetOf(WidgetTester tester, String name) => tester
      .widget<Scrollable>(
        find.descendant(
          of: find.byKey(PageStorageKey<String>(name)),
          matching: find.byType(Scrollable),
        ),
      )
      .controller!
      .offset;

  group('tab switching', () {
    testWidgets(
      'therapist Account returns to its root after leaving Notifications',
      (tester) async {
        final router = therapistShellHarnessRouter(
          initialLocation: '/therapist/account',
          detailRoutes: {
            3: {
              '/therapist/notifications': const Text('notifications'),
            },
          },
          screens: const [
            ScrollableProbe(name: 'therapist-home'),
            ScrollableProbe(name: 'therapist-schedule'),
            ScrollableProbe(name: 'therapist-requests'),
            ScrollableProbe(name: 'therapist-account'),
          ],
        );
        await tester.pumpWidget(shellHarnessApp(router));
        await tester.pumpAndSettle();

        router.go('/therapist/notifications');
        await tester.pumpAndSettle();
        expect(find.text('notifications'), findsOneWidget);

        await tapTab(tester, 'Requests');
        expect(find.text('therapist-requests-0'), findsOneWidget);

        await tapTab(tester, 'Account');
        expect(find.text('therapist-account-0'), findsOneWidget);
        expect(find.text('notifications'), findsNothing);
      },
    );

    testWidgets('keeps the previous tab\'s scroll offset', (tester) async {
      await pumpShell(tester);

      // Scroll the Home tab well down its list.
      await tester.drag(find.text('home-1'), const Offset(0, -600));
      await tester.pumpAndSettle();
      final scrolled = offsetOf(tester, 'home');
      expect(scrolled, greaterThan(0), reason: 'the drag should have scrolled');

      await tapTab(tester, 'Account');
      expect(find.text('account-0'), findsOneWidget);

      await tapTab(tester, 'Home');

      // The whole point of an IndexedStack shell: Home was never torn down,
      // so it comes back exactly where it was left.
      expect(offsetOf(tester, 'home'), scrolled);
    });

    testWidgets('is a swap, not a page transition', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.bySemanticsLabel('Sessions'));
      // A single frame — no time for an animation to run. `go()` used to push
      // a route here and the destination would still be sliding in.
      await tester.pump();
      expect(find.text('sessions-0'), findsOneWidget);
    });

    testWidgets('re-tapping the current tab pops it back to its root', (
      tester,
    ) async {
      final router = await pumpShell(
        tester,
        detailRoutes: {
          0: {'/patient/find': const Text('find')},
        },
      );

      router.push('/patient/find');
      await tester.pumpAndSettle();
      expect(find.text('find'), findsOneWidget);

      await tapTab(tester, 'Home');
      expect(find.text('find'), findsNothing);
      expect(find.text('home-0'), findsOneWidget);
    });

    testWidgets('Sessions keeps its own history', (tester) async {
      final router = await pumpShell(
        tester,
        initialLocation: '/patient/sessions',
        detailRoutes: {
          1: {'/patient/session-detail': const Text('session detail')},
        },
      );

      router.push('/patient/session-detail');
      await tester.pumpAndSettle();
      expect(find.text('session detail'), findsOneWidget);

      // Leave the tab and come back: a branch owns its Navigator, so the
      // pushed page is still on the stack rather than reset to the root.
      await tapTab(tester, 'Account');
      expect(find.text('account-0'), findsOneWidget);
      await tapTab(tester, 'Sessions');
      expect(find.text('session detail'), findsOneWidget);
    });
  });

  group('the bar', () {
    testWidgets('is on every patient tab', (tester) async {
      for (final route in patientTabRoutes) {
        await pumpShell(tester, initialLocation: route);
        expect(
          find.byType(PatientNav),
          findsOneWidget,
          reason: '$route should carry the bottom bar',
        );
      }
    });

    testWidgets('is also on Notifications inside the Home branch', (
      tester,
    ) async {
      await pumpShell(tester, initialLocation: '/patient/notifications');
      expect(find.byType(PatientNav), findsOneWidget);
    });

    testWidgets('is mounted once, by the shell', (tester) async {
      await pumpShell(tester);
      // Four branches are alive inside the IndexedStack at all times. If the
      // screens still mounted their own bars we would find several.
      expect(find.byType(PatientNav), findsOneWidget);
    });

    testWidgets('lights up the tab you are on', (tester) async {
      await pumpShell(tester, initialLocation: '/patient/recovery');
      final active = tester.widget<Icon>(
        find.byIcon(Icons.healing_rounded),
      );
      final inactive = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(active.color, AppColors.pine);
      expect(inactive.color, isNot(AppColors.pine));
    });
  });

  group('back', () {
    testWidgets('pops within the tab when there is somewhere to go', (
      tester,
    ) async {
      final router = await pumpShell(
        tester,
        detailRoutes: {
          3: {'/patient/edit-profile': const Text('edit profile')},
        },
        initialLocation: '/patient/account',
      );

      router.push('/patient/edit-profile');
      await tester.pumpAndSettle();
      expect(find.text('edit profile'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('edit profile'), findsNothing);
      expect(
        find.text('account-0'),
        findsOneWidget,
        reason: 'stays in the tab',
      );
    });

    testWidgets('at a non-first tab root lands on the first tab', (
      tester,
    ) async {
      // Every rung of the ladder, not just one: reordering the tabs is
      // exactly the change that would quietly break this.
      for (final route in patientTabRoutes.skip(1)) {
        final router = await pumpShell(tester, initialLocation: route);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(
          router.state.uri.path,
          '/patient/home',
          reason: 'Back from $route should land on Home',
        );
        expect(find.text('home-0'), findsOneWidget);
      }
    });

    testWidgets('from a non-root screen on the first tab resets that tab', (
      tester,
    ) async {
      final router = await pumpShell(
        tester,
        detailRoutes: {
          0: {'/patient/find': const Text('find')},
        },
        // Reached with go(), which leaves the branch with no history — the
        // clinic list's "find a therapist instead" link does exactly this.
        initialLocation: '/patient/find',
      );
      expect(find.text('find'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/patient/home');
    });

    testWidgets('at the first tab root is allowed through to the platform', (
      tester,
    ) async {
      final router = await pumpShell(tester);

      // This is the one rung where leaving is correct: Android closes the app
      // from the home tab's root, and the shell must not swallow that.
      expect(shellLetsPopThrough(tester), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/patient/home');
    });

    testWidgets('is swallowed anywhere else', (tester) async {
      for (final route in patientTabRoutes.skip(1)) {
        await pumpShell(tester, initialLocation: route);
        expect(
          shellLetsPopThrough(tester),
          isFalse,
          reason: 'Back on $route should not leave the app',
        );
      }
    });
  });

  group('the patient tab set', () {
    testWidgets('is Home, Sessions, Recovery, Account around the centre '
        'action', (tester) async {
      await pumpShell(tester);

      // Five slots: four tabs split two and two by the centre action. The bar
      // reports the index it was tapped at and the shell hands that straight
      // to `goBranch`, so left-to-right order *is* the branch order.
      const expected = ['Home', 'Sessions', 'Recovery', 'Account'];
      final xs = [
        for (final label in expected)
          tester.getCenter(find.bySemanticsLabel(label)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));

      final fab = tester.getCenter(find.byIcon(Icons.add)).dx;
      expect(
        fab,
        greaterThan(xs[1]),
        reason: 'the centre action splits 2 and 2',
      );
      expect(fab, lessThan(xs[2]));
    });

    testWidgets('no longer has a Find tab', (tester) async {
      await pumpShell(tester);
      expect(find.bySemanticsLabel('Find'), findsNothing);
      // Scoped to the bar. The magnifier still exists — it moved up into the
      // shared header, which is the whole point — so a bare
      // `find.byIcon(Icons.search_rounded)` would now pass for the wrong
      // reason and keep passing if Find ever crept back into the bar.
      expect(
        find.descendant(
          of: find.byType(PatientNav),
          matching: find.byIcon(Icons.search_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('puts Sessions at index 1', (tester) async {
      await pumpShell(tester, initialLocation: '/patient/sessions');

      expect(find.text('sessions-0'), findsOneWidget);
      final active = tester.widget<Icon>(find.byIcon(Icons.history_rounded));
      final home = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(active.color, AppColors.pine);
      expect(home.color, isNot(AppColors.pine));
    });
  });
}
