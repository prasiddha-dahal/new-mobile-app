import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/screens/login_screen.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/screens/verify_pending_screen.dart';

import '../../l10n_harness.dart';

/// The auth screens are the first thing anyone sees, and the only ones a
/// signed-out Nepali reader can reach at all. If the language toggle does not
/// work here it does not matter that it works anywhere else.
void main() {
  testWidgets('sign-in is English until the language changes, then it is not', (
    tester,
  ) async {
    final container = await pumpLocalized(tester, const LoginScreen());

    expect(find.text('Log in to Sahayatri'), findsOneWidget);
    expect(
      find.text(
        'One login for patients and therapists — your account decides where '
        'you land.',
      ),
      findsOneWidget,
    );

    await switchTo(tester, container, const Locale('ne'));

    // Every visible string on the screen, so a literal left behind anywhere
    // on it fails rather than only the one the test happened to name.
    expectNoEnglish(tester, const [
      'WELCOME BACK',
      'Log in to Sahayatri',
      'One login for patients and therapists — your account decides where '
          'you land.',
      'EMAIL',
      'PASSWORD',
      'Forgot password?',
      'Log in',
      'OR CONTINUE WITH',
      'Continue with Google',
      "Don't have an account?",
      'Sign up free',
    ]);
  });

  testWidgets('the brand stays put while the sentence around it moves', (
    tester,
  ) async {
    // "Sahayatri" is a name, not a word. It has to survive the translation
    // it is embedded in.
    final container = await pumpLocalized(tester, const LoginScreen());
    await switchTo(tester, container, const Locale('ne'));

    expect(
      renderedText(tester).any((s) => s.contains('Sahayatri')),
      isTrue,
      reason: 'the wordmark was translated away',
    );
  });

  testWidgets('the therapist waiting room reads in Nepali too', (tester) async {
    // A therapist sits on this screen for 24–48 hours, so it is the auth
    // screen a partner spends the most time reading.
    final container = await pumpLocalized(
      tester,
      const VerifyPendingScreen(),
      locale: const Locale('ne'),
    );
    await tester.pump();

    expectNoEnglish(tester, const [
      'UNDER REVIEW',
      'Application submitted',
      'Application ref',
      'Status',
      'PENDING',
      'Preview my dashboard',
      "You'll get full booking access once verified.",
    ]);

    await switchTo(tester, container, const Locale('en'));
    expect(find.text('Application submitted'), findsOneWidget);
  });
}
