import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/router/app_router.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/providers/therapist_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_account_screen.dart';

/// Two finished therapist screens were registered in no router and linked from
/// nowhere. A route with nothing pointing at it is the same bug as no route at
/// all, so these check both halves: that the path exists and belongs to the
/// therapist, and that the Account row a therapist would actually look for
/// opens it.
///
/// `Report a patient` is the one that matters. It posts to the same
/// `POST /admin/complaints` the patient's `Report a therapist` uses, and until
/// this row existed only one side of a home visit could report the other.
void main() {
  User userWithRole(String role) => User(
    id: 'u1',
    name: 'Test',
    email: 'test@example.com',
    role: role,
    status: 'APPROVED',
  );

  /// Builds the real router with [role] signed in and asks where [path] lands.
  /// A path with no route resolves to the error page, so this catches a route
  /// that does not exist as well as one the redirect bounces.
  Future<String> resolve(String role, String path) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Read the router first: it creates the AuthStateNotifier, which only
    // learns about a user by listening for the change below.
    final router = container.read(routerProvider);
    container.read(authProvider.notifier).state = userWithRole(role);

    final match = router.configuration.findMatch(Uri.parse(path));
    final redirected = await router.configuration.redirect(
      _FakeContext(),
      match,
      redirectHistory: <RouteMatchList>[],
    );
    return redirected.uri.path;
  }

  const newRoutes = ['/therapist/report-patient', '/therapist/rate-increase'];

  group('the routes', () {
    test('resolve to themselves for a therapist', () async {
      for (final path in newRoutes) {
        expect(await resolve('THERAPIST', path), path);
      }
    });

    test('and bounce a patient to their own home', () async {
      // The mirror of the rule the patient shell already relies on. Without
      // it a patient could land on a therapist screen wearing the therapist
      // bottom bar.
      for (final path in newRoutes) {
        expect(await resolve('PATIENT', path), '/patient/home', reason: path);
      }
    });
  });

  group('the Account rows', () {
    /// Mounts the therapist Account screen over a router that also knows the
    /// two new paths, with everything it reads stubbed so nothing needs Dio.
    Future<GoRouter> pumpAccount(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/therapist/account',
        routes: [
          GoRoute(
            path: '/therapist/account',
            builder: (_, _) => const TherapistAccountScreen(),
          ),
          for (final path in [...newRoutes, '/therapist/bio'])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text('at $path')),
            ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (_) => userWithRole('THERAPIST'),
            ),
            therapistProfileProvider.overrideWith(
              (_) async => const TherapistProfileDto(
                id: 't1',
                userId: 'u1',
                name: 'Test Therapist',
                email: 'therapist@test.com',
                specialty: 'Sports',
                city: 'Kathmandu',
                price: 1800,
              ),
            ),
            therapistDashboardProvider.overrideWith(
              (_) => Future.error(Exception('not needed here')),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('Report a patient opens the complaint form', (tester) async {
      final router = await pumpAccount(tester);

      await tester.scrollUntilVisible(
        find.text('Report a patient'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Report a patient'));
      await tester.pumpAndSettle();

      expect(find.text('at /therapist/report-patient'), findsOneWidget);
      expect(router.state.uri.path, '/therapist/report-patient');
    });

    testWidgets('Request a rate increase opens the rate form', (tester) async {
      final router = await pumpAccount(tester);

      await tester.scrollUntilVisible(
        find.text('Request a rate increase'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Request a rate increase'));
      await tester.pumpAndSettle();

      expect(find.text('at /therapist/rate-increase'), findsOneWidget);
      expect(router.state.uri.path, '/therapist/rate-increase');
    });

    testWidgets('only one row leads to Bio & portfolio', (tester) async {
      // "Specializations" and "Bio & portfolio" both pushed /therapist/bio.
      // That screen already carries a specialisms section, so the menu was
      // listing one page twice under two names — a therapist who edited their
      // specialisms and then opened the other row found their own edit there
      // and had no way to tell whether they had two records or one.
      await pumpAccount(tester);

      final rows = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Bio & portfolio',
      );
      expect(rows, findsOneWidget);
      expect(
        find.text('Specializations'),
        findsNothing,
        reason: 'the specialty survives as the meta line on the row that '
            'remains, which is all this row ever showed',
      );
    });

    testWidgets('both push, so Back returns to the menu', (tester) async {
      // `go` would replace the branch's stack and drop the therapist onto the
      // shell's back ladder instead of returning them to the row they tapped.
      final router = await pumpAccount(tester);

      await tester.scrollUntilVisible(
        find.text('Report a patient'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Report a patient'));
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/therapist/account');
    });
  });
}

/// `redirect` only passes the context through to the route callbacks, and none
/// of the app's redirects touch it.
class _FakeContext extends Fake implements BuildContext {}
