import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';

import 'tab_shell_harness.dart';

/// The centre action used to be a shortcut list that duplicated the bar:
/// "Book a session" opened Find, which was a tab, and "View my sessions"
/// opened Sessions, which is a tab now. Both are gone — a sheet that repeats
/// the bar underneath it is two taps where one would do.
void main() {
  Future<GoRouter> openSheet(
    WidgetTester tester, {
    Map<int, Map<String, Widget>> detailRoutes = const {},
    Map<String, Widget> rootRoutes = const {},
  }) async {
    final router = patientShellHarnessRouter(
      screens: const [
        ScrollableProbe(name: 'home'),
        ScrollableProbe(name: 'sessions'),
        ScrollableProbe(name: 'notifications'),
        ScrollableProbe(name: 'account'),
      ],
      detailRoutes: detailRoutes,
      rootRoutes: rootRoutes,
    );
    await tester.pumpWidget(
      shellHarnessApp(router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the centre action opens Quick Action', (tester) async {
    await openSheet(tester);
    expect(find.text('QUICK ACTION'), findsOneWidget);
  });

  testWidgets('with two rows: Packages and Shop', (tester) async {
    await openSheet(tester);

    expect(find.text('Packages'), findsOneWidget);
    expect(find.text('Browse care packages'), findsOneWidget);
    // Shop was routed and reachable from nowhere: every mention of `/shop`
    // in lib/ came from inside the shop itself. This row is its only door.
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Equipment, rentals and supplies'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

    // The two rows the bar now covers itself.
    expect(find.text('Book a session'), findsNothing);
    expect(find.text('View my sessions'), findsNothing);
  });

  testWidgets('and a Close button that dismisses it', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('QUICK ACTION'), findsNothing);
  });

  testWidgets('Packages closes the sheet and opens the catalogue', (
    tester,
  ) async {
    // This used to assert the row navigated *nowhere*: the destination was
    // being built on `feat/packages-mobile` and inventing a route would have
    // been worse than a dead row. The route exists now, so the placeholder
    // assertion is replaced rather than dropped — a row in the design that
    // silently goes nowhere is exactly the regression worth catching.
    final router = await openSheet(
      tester,
      detailRoutes: {
        0: {'/patient/packages': const Text('therapy packages')},
      },
    );

    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();

    expect(find.text('QUICK ACTION'), findsNothing, reason: 'sheet closed');
    expect(find.text('therapy packages'), findsOneWidget);
    expect(router.state.uri.path, '/patient/packages');
    expect(tester.takeException(), isNull);
  });

  testWidgets('and lands there with the bottom bar still under it', (
    tester,
  ) async {
    // `go`, not `push`: the sheet is already popped, so there is nothing to
    // pop back through. The route lives in the Home branch, so the bar stays
    // and Home is the tab that lights up.
    await openSheet(
      tester,
      detailRoutes: {
        0: {'/patient/packages': const Text('therapy packages')},
      },
    );

    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientNav), findsOneWidget);
    final home = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
    expect(home.color, AppColors.pine, reason: 'Home is the lit tab');
  });

  group('Shop', () {
    /// The sheet opened from the Sessions tab, so a test can tell "came back
    /// to where I was" from "came back to Home".
    Future<GoRouter> openShop(WidgetTester tester) async {
      final router = await openSheet(
        tester,
        rootRoutes: {'/shop': const Scaffold(body: Text('shop screen'))},
      );
      // Tab 1, so the return trip has somewhere specific to land.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      router.go('/patient/sessions');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('closes the sheet and opens the shop', (tester) async {
      final router = await openShop(tester);

      expect(find.text('QUICK ACTION'), findsNothing, reason: 'sheet closed');
      expect(find.text('shop screen'), findsOneWidget);
      expect(router.state.uri.path, '/shop');
      expect(tester.takeException(), isNull);
    });

    testWidgets('which owns the viewport, bottom bar and all', (tester) async {
      await openShop(tester);

      // `/shop` is a root route, so it covers the shell rather than sitting
      // in a branch. That is the documented rule and this pins it: the shop
      // has its own chrome and deliberately no tabs under it.
      expect(find.byType(PatientNav), findsNothing);
    });

    testWidgets('and is pushed, so the user gets back out', (tester) async {
      final router = await openShop(tester);

      // `go` — what every other row in this sheet does — would have replaced
      // the stack. With no bottom bar and nothing to pop, Android Back would
      // then close the app from a screen opened one tap earlier.
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/patient/sessions');
      expect(find.byType(PatientNav), findsOneWidget);
    });
  });
}
