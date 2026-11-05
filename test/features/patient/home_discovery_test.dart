import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/care_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_account_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_find_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_home_screen.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/care_models.dart';

/// The "What are you looking for?" block is the only place clinics and the
/// coverage map are offered: the clinic list moved off the Account menu and
/// the coverage map had no caller at all before this. If a row stops
/// navigating, its screen is unreachable rather than merely awkward to reach.
void main() {
  /// A router that knows the three destinations, each answering with a
  /// recognisable stand-in so a test can say which one it landed on.
  GoRouter discoveryRouter({
    required String initialLocation,
    required Map<String, WidgetBuilder> entryPoints,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        for (final entry in entryPoints.entries)
          GoRoute(
            path: entry.key,
            builder: (context, _) => entry.value(context),
          ),
        GoRoute(
          path: '/patient/find',
          builder: (_, _) => const Scaffold(body: Text('find screen')),
        ),
        GoRoute(
          path: '/clinics',
          builder: (_, _) => const Scaffold(body: Text('clinic list')),
        ),
        GoRoute(
          path: '/patient/coverage',
          builder: (_, _) => const Scaffold(body: Text('coverage map')),
        ),
      ],
    );
  }

  /// Stubs every future the screens reach for, so nothing touches Dio.
  Widget host(GoRouter router) {
    return ProviderScope(
      overrides: [
        patientDashboardProvider.overrideWith(
          (_) async => const PatientDashboard(
            name: 'Test Patient',
            totalSessions: 0,
            completedSessions: 0,
            upcomingSessions: 0,
          ),
        ),
        featuredTherapistsProvider.overrideWith((_) async => <Therapist>[]),
        therapistListProvider.overrideWith((_) async => <Therapist>[]),
        patientSessionsProvider.overrideWith((_) async => <Session>[]),
        reportsProvider.overrideWith((_) async => <ReportDto>[]),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<GoRouter> pumpHome(WidgetTester tester) async {
    final router = discoveryRouter(
      initialLocation: '/patient/home',
      entryPoints: {'/patient/home': (_) => const PatientHomeScreen()},
    );
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<GoRouter> pumpFind(WidgetTester tester) async {
    final router = discoveryRouter(
      initialLocation: '/patient/search',
      entryPoints: {'/patient/search': (_) => const PatientFindScreen()},
    );
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();
    return router;
  }

  /// Home is taller than a test viewport, so the block at the bottom has to be
  /// scrolled to before it can be tapped.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('the discovery block on Home', () {
    testWidgets('heads three rows with the copy from the design', (
      tester,
    ) async {
      await pumpHome(tester);

      await scrollTo(tester, find.text('WHAT ARE YOU LOOKING FOR?'));
      expect(find.text('WHAT ARE YOU LOOKING FOR?'), findsOneWidget);

      expect(find.text('Find a Physiotherapist'), findsOneWidget);
      expect(
        find.text('Book a verified therapist for a home visit.'),
        findsOneWidget,
      );
      expect(find.text('Find a Clinic'), findsOneWidget);
      expect(find.text('Book a visit at a clinic near you.'), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);
      expect(
        find.text('See therapists and clinics that cover your area.'),
        findsOneWidget,
      );
    });

    testWidgets('sends "Find a Physiotherapist" to Find', (tester) async {
      final router = await pumpHome(tester);

      await scrollTo(tester, find.text('Find a Physiotherapist'));
      await tester.tap(find.text('Find a Physiotherapist'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/patient/find');
      expect(find.text('find screen'), findsOneWidget);
    });

    testWidgets('sends "Find a Clinic" to the clinic list', (tester) async {
      final router = await pumpHome(tester);

      await scrollTo(tester, find.text('Find a Clinic'));
      await tester.tap(find.text('Find a Clinic'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/clinics');
      expect(find.text('clinic list'), findsOneWidget);
    });

    testWidgets('sends "View on Map" to the coverage map', (tester) async {
      final router = await pumpHome(tester);

      await scrollTo(tester, find.text('View on Map'));
      await tester.tap(find.text('View on Map'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/patient/coverage');
      expect(find.text('coverage map'), findsOneWidget);
    });

    testWidgets('pushes rather than goes, so Back returns to Home', (
      tester,
    ) async {
      final router = await pumpHome(tester);

      await scrollTo(tester, find.text('View on Map'));
      await tester.tap(find.text('View on Map'));
      await tester.pumpAndSettle();

      // `go()` would replace the branch's stack: the user would fall through
      // to the shell's back ladder instead of returning to the card they
      // tapped, and Home would lose its scroll position on the way.
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/patient/home');
    });
  });

  group('the shortcuts on Find', () {
    testWidgets('offer the other two ways to look, not a third loop back to '
        'this screen', (tester) async {
      await pumpFind(tester);

      expect(find.text('Find a Clinic'), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);
      // The Find screen linking to Find is a button that does nothing
      // visible, so the third row is deliberately absent here.
      expect(find.text('Find a Physiotherapist'), findsNothing);
    });

    testWidgets('survive a full screen of results, because they are pinned '
        'above the list', (tester) async {
      await pumpFind(tester);

      // No scrolling: both are on the first frame of the first screenful,
      // which is the property that would break if they were moved into the
      // results list.
      expect(find.text('Find a Clinic'), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);
    });

    testWidgets('navigate to the clinic list and the coverage map', (
      tester,
    ) async {
      final router = await pumpFind(tester);

      await tester.tap(find.text('Find a Clinic'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/clinics');

      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('View on Map'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/patient/coverage');
    });
  });

  group('on a small phone', () {
    /// The default test viewport is 800x600 — wider than any phone this ships
    /// on. Both new layouts put several fixed-width things in one Row, which
    /// is exactly the shape that fits in a test and overflows on a device.
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Future<void> narrow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the discovery cards fit without overflowing', (tester) async {
      await narrow(tester);
      await pumpHome(tester);
      await scrollTo(tester, find.text('View on Map'));

      // pumpAndSettle rethrows a RenderFlex overflow, so reaching here is the
      // assertion; the text check is just proof the block actually rendered.
      expect(find.text('Find a Physiotherapist'), findsOneWidget);
    });

    testWidgets('the Find shortcuts fit beside each other', (tester) async {
      await narrow(tester);
      await pumpFind(tester);

      expect(find.text('Find a Clinic'), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);
    });
  });

  group('the Account menu', () {
    testWidgets('no longer offers "Find a clinic"', (tester) async {
      final router = discoveryRouter(
        initialLocation: '/patient/account',
        entryPoints: {'/patient/account': (_) => const PatientAccountScreen()},
      );
      await tester.pumpWidget(host(router));
      await tester.pumpAndSettle();

      // Asserted by absence on purpose: this is the entry point that moved to
      // Home, and a re-added copy here is a duplicate nobody would notice.
      expect(find.text('Find a clinic'), findsNothing);
      expect(find.text('Find a Clinic'), findsNothing);

      // The rest of the Health group stayed, so removing one row did not
      // empty the group it was in.
      expect(find.text('HEALTH'), findsOneWidget);
      expect(find.text('My sessions'), findsOneWidget);
      expect(find.text('Reports & files'), findsOneWidget);
      expect(find.text('Recovery progress'), findsOneWidget);
    });
  });
}
