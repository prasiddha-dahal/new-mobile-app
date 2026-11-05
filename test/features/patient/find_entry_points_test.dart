import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_home_screen.dart';

/// Find used to be a bottom-bar tab. It is not any more, so the entry points
/// that replaced it are the only way in — if the hero button stops working,
/// the screen is unreachable from Home rather than merely inconvenient.
void main() {
  /// Mounts Home over a router that also knows `/patient/find`, with the two
  /// dashboard futures stubbed so nothing reaches for Dio.
  Future<GoRouter> pumpHome(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/patient/home',
      routes: [
        GoRoute(
          path: '/patient/home',
          builder: (_, _) => const PatientHomeScreen(),
        ),
        GoRoute(
          path: '/patient/find',
          builder: (_, _) => const Scaffold(body: Text('find screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the hero button on Home opens Find', (tester) async {
    final router = await pumpHome(tester);

    await tester.tap(find.text('Find Physiotherapist'));
    await tester.pumpAndSettle();

    expect(find.text('find screen'), findsOneWidget);
    expect(router.state.uri.path, '/patient/find');
  });

  testWidgets('and pushes it, so Back returns to Home', (tester) async {
    final router = await pumpHome(tester);

    await tester.tap(find.text('Find Physiotherapist'));
    await tester.pumpAndSettle();

    // `go()` would have replaced the stack and left nothing to pop back to —
    // the user would fall through to the shell's back ladder instead of
    // simply returning to the card they tapped.
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/patient/home');
  });
}
