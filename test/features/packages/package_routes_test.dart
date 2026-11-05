import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/router/app_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_header.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/package_purchase.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/therapy_package.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/providers/package_providers.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/widgets/active_package_card.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/screens/my_packages_screen.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/screens/therapy_packages_screen.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_home_screen.dart';

import '../../core/tab_shell_harness.dart';

/// The Packages module shipped with no way in: two screens, no routes, and a
/// row in the centre-action sheet that deliberately navigated nowhere. These
/// pin the wiring — that both paths resolve inside the patient shell, and
/// that the screens, which carry no `Scaffold` of their own, get the shell's
/// chrome rather than rendering bare.
void main() {
  User patientUser() => const User(
    id: 'u1',
    name: 'Aakar Sharma',
    email: 'aakar@example.com',
    role: 'PATIENT',
    status: 'APPROVED',
  );

  group('the real router', () {
    /// Asks the app's own router where [path] ends up for a signed-in
    /// patient. A path with no route resolves to the error page, so this
    /// catches a missing registration rather than only a bad redirect.
    Future<String> resolve(String path) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      container.read(authProvider.notifier).state = patientUser();

      final match = router.configuration.findMatch(Uri.parse(path));
      final redirected = await router.configuration.redirect(
        _FakeContext(),
        match,
        redirectHistory: <RouteMatchList>[],
      );
      return redirected.uri.path;
    }

    test('knows both packages paths', () async {
      expect(await resolve('/patient/packages'), '/patient/packages');
      expect(
        await resolve('/patient/packages/mine'),
        '/patient/packages/mine',
        reason: '"mine" must not be swallowed as a package id',
      );
    });

    test('puts them in the Home branch, so the bar stays and Home lights up',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      container.read(authProvider.notifier).state = patientUser();

      // Branch membership is what a `go` from the centre-action sheet lands
      // on: a route in the Home branch keeps the bottom bar and lights Home
      // up. The patient shell is the first StatefulShellRoute, Home is its
      // first branch — the same ordering the bar's tab indices rely on.
      final patientShell = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .first;

      final homeBranchPaths = <String>[];
      void collect(RouteBase route, String parent) {
        if (route is! GoRoute) return;
        final path = route.path.startsWith('/')
            ? route.path
            : '$parent/${route.path}';
        homeBranchPaths.add(path);
        for (final child in route.routes) {
          collect(child, path);
        }
      }

      for (final route in patientShell.branches.first.routes) {
        collect(route, '');
      }

      expect(homeBranchPaths, contains('/patient/home'));
      expect(homeBranchPaths, contains('/patient/packages'));
      expect(homeBranchPaths, contains('/patient/packages/mine'));
    });
  });

  group('mounted in the shell', () {
    /// The two screens over the real `PatientShell`, with the repository's
    /// futures stubbed so nothing reaches for Dio.
    Future<GoRouter> pump(
      WidgetTester tester, {
      required String initialLocation,
      PackagePurchase? active,
    }) async {
      final router = patientShellHarnessRouter(
        initialLocation: initialLocation,
        detailRoutes: {
          0: {
            '/patient/packages': TherapyPackagesScreen(
              onBack: () {},
              onViewMyPackages: () {},
            ),
            '/patient/packages/mine': MyPackagesScreen(
              onBack: () {},
              onBrowsePackages: () {},
            ),
          },
        },
        screens: const [
          Scaffold(body: Text('home')),
          Scaffold(body: Text('sessions')),
          Scaffold(body: Text('notifications')),
          Scaffold(body: Text('account')),
        ],
      );

      await tester.pumpWidget(
        shellHarnessApp(
          router,
          overrides: [
            authProvider.overrideWith((_) => patientUser()),
            packageCatalogueProvider.overrideWith(
              (_) async => const PackageCatalogue(<TherapyPackage>[]),
            ),
            activePackageProvider.overrideWith((_) async => active),
            myPackagePurchasesProvider.overrideWith(
              (_) async => const <PackagePurchase>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('the catalogue renders under the shared chrome', (
      tester,
    ) async {
      await pump(tester, initialLocation: '/patient/packages');

      expect(find.text('Therapy Packages'), findsOneWidget);
      // The screens are deliberately Scaffold-free. Mounted anywhere else
      // they would have no bars at all; here they inherit both.
      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.byType(PatientNav), findsOneWidget);
    });

    testWidgets('and so does My packages', (tester) async {
      await pump(tester, initialLocation: '/patient/packages/mine');

      expect(find.text('My Packages'), findsOneWidget);
      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.byType(PatientNav), findsOneWidget);
      expect(find.text('No active package'), findsOneWidget);
    });
  });

  group('the card on Home', () {
    /// The patient home screen with its own futures stubbed, over a router
    /// that also knows My packages.
    Future<GoRouter> pumpHome(
      WidgetTester tester, {
      PackagePurchase? active,
    }) async {
      final router = GoRouter(
        initialLocation: '/patient/home',
        routes: [
          GoRoute(
            path: '/patient/home',
            builder: (_, _) => const PatientHomeScreen(),
          ),
          GoRoute(
            path: '/patient/packages/mine',
            builder: (_, _) => const Scaffold(body: Text('my packages')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => patientUser()),
            patientDashboardProvider.overrideWith(
              (_) async => const PatientDashboard(
                name: 'Aakar Sharma',
                totalSessions: 0,
                completedSessions: 0,
                upcomingSessions: 0,
              ),
            ),
            featuredTherapistsProvider.overrideWith((_) async => <Therapist>[]),
            activePackageProvider.overrideWith((_) async => active),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('shows the active package and opens My packages', (
      tester,
    ) async {
      await pumpHome(tester, active: _activePurchase());

      expect(find.text('Stroke & Neuro Recovery'), findsOneWidget);
      expect(find.text('10 sessions remaining'), findsOneWidget);

      await tester.tap(find.text('Stroke & Neuro Recovery'));
      await tester.pumpAndSettle();
      expect(find.text('my packages'), findsOneWidget);
    });

    testWidgets('is mounted unconditionally and collapses to nothing', (
      tester,
    ) async {
      // The card answers `SizedBox.shrink()` for no package, an expired one,
      // a used-up one and a failed call alike, which is what makes it safe to
      // place without asking first — but only if the padding around it
      // collapses with it, or Home keeps an empty slot for a card nobody has.
      await pumpHome(tester);

      expect(find.byType(ActivePackageCard), findsOneWidget);
      expect(tester.getSize(find.byType(ActivePackageCard)).height, 0);
      expect(find.text('Stroke & Neuro Recovery'), findsNothing);
    });

    testWidgets('sits above the ways to find new care, not below them', (
      tester,
    ) async {
      // A package already paid for outranks an invitation to buy more.
      await pumpHome(tester, active: _activePurchase());

      final card = tester.getRect(find.text('Stroke & Neuro Recovery')).top;
      final discovery = tester
          .getRect(find.text('WHAT ARE YOU LOOKING FOR?'))
          .top;
      expect(card, lessThan(discovery));
    });
  });
}

PackagePurchase _activePurchase() => PackagePurchase(
  id: 'purchase-1',
  packageId: 'package-1',
  packageName: 'Stroke & Neuro Recovery',
  sessionsTotal: 12,
  sessionsUsed: 2,
  status: 'ACTIVE',
  purchasedAt: DateTime.now().subtract(const Duration(days: 3)),
  expiresAt: DateTime.now().add(const Duration(days: 27)),
);

/// `redirect` only passes the context through to the route callbacks, and
/// none of the app's redirects touch it.
class _FakeContext extends Fake implements BuildContext {}
