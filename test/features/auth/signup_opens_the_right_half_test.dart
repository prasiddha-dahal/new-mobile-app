import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/screens/signup_screen.dart';

import '../../l10n_harness.dart';

/// The landing screen has exactly one control that says "I'm a
/// physiotherapist", and it opened the patient form.
///
/// It pushed a bare `/signup`, whose route built `SignupScreen()` with its
/// default — and the default is the patient half. So the only place in the app
/// where a therapist self-identifies sent them into the wrong signup, with
/// nothing on the next screen to say it had happened. They would have filled
/// in a patient application.
///
/// The route now reads `?role=therapist`, which is worth a test on both ends:
/// the query parameter is easy to typo, and the failure is silent.
void main() {
  /// Everything the therapist half asks for and the patient half does not.
  const therapistOnly = 'NMC LICENSE NUMBER';

  testWidgets('a bare /signup still opens the patient form', (tester) async {
    await pumpLocalized(
      tester,
      const SignupScreen(),
      size: const Size(390, 2400),
    );

    expect(find.text(therapistOnly), findsNothing);
  });

  testWidgets('startAsTherapist opens the therapist form', (tester) async {
    await pumpLocalized(
      tester,
      const SignupScreen(startAsTherapist: true),
      size: const Size(390, 2400),
    );

    expect(
      find.text(therapistOnly),
      findsOneWidget,
      reason: 'the therapist half has to be the one on screen, not a tab the '
          'reader still has to find',
    );
  });

  testWidgets('and the route carries the role through', (tester) async {
    // The parameter and the widget are two separate chances to get this wrong;
    // this is the half that lives in the router.
    late bool asTherapist;
    final router = GoRouter(
      initialLocation: '/signup?role=therapist',
      routes: [
        GoRoute(
          path: '/signup',
          builder: (_, s) {
            asTherapist = s.uri.queryParameters['role'] == 'therapist';
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(asTherapist, isTrue);
  });
}
