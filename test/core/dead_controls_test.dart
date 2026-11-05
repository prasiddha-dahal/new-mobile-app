import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_contact_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_certifications_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_payout_methods_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_service_areas_screen.dart';

import '../l10n_harness.dart';

/// Controls that looked live and did nothing.
///
/// Each of these was an `onPressed: () {}` or an `onTap: () {}` — a button
/// with the full pressed ripple and no consequence whatsoever. None of them
/// has a backend to reach, so none of them is *wired* here: each explains,
/// through the shared `showUnavailableDialog`, which is the pattern six other
/// screens in this app already used.
///
/// What these tests pin is the thing that is easy to lose again: that the tap
/// produces *something*. A future refactor that drops the handler puts the
/// screen back exactly where it was, and silently.
void main() {
  Future<void> expectExplains(
    WidgetTester tester, {
    required Finder control,
    required String Function(AppLocalizations) title,
  }) async {
    final l10n = tester.element(find.byType(Scaffold).first).l10n;

    await tester.ensureVisible(control);
    await tester.tap(control, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(title(l10n)), findsOneWidget);

    // And it can be dismissed, which the hand-rolled copies also did.
    await tester.tap(find.text(l10n.actionGotIt));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }

  testWidgets('"+ Add certification" explains instead of doing nothing', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const TherapistCertificationsScreen(),
      size: const Size(390, 1400),
    );
    await tester.pump();

    await expectExplains(
      tester,
      control: find.byType(OutlinedButton),
      title: (l) => l.certificationsAddUnavailableTitle,
    );
  });

  group('the payout-methods screen', () {
    testWidgets('the bank-transfer "Add" explains', (tester) async {
      await pumpLocalized(
        tester,
        const TherapistPayoutMethodsScreen(),
        size: const Size(390, 1400),
      );
      await tester.pump();

      await expectExplains(
        tester,
        control: find.byType(TextButton).first,
        title: (l) => l.payoutAddUnavailableTitle,
      );
    });

    testWidgets('and so does "+ Add new payout method"', (tester) async {
      await pumpLocalized(
        tester,
        const TherapistPayoutMethodsScreen(),
        size: const Size(390, 1400),
      );
      await tester.pump();

      await expectExplains(
        tester,
        control: find.byType(OutlinedButton),
        title: (l) => l.payoutAddUnavailableTitle,
      );
    });
  });

  group('the service-areas screen', () {
    testWidgets('the "Add" beside the search field explains', (tester) async {
      await pumpLocalized(
        tester,
        const TherapistServiceAreasScreen(),
        size: const Size(390, 1400),
      );
      await tester.pump();

      await expectExplains(
        tester,
        control: find.byType(TextButton).first,
        title: (l) => l.serviceAreasAddUnavailableTitle,
      );
    });

    testWidgets('and so do the five suggested-area chips', (tester) async {
      // These are the sharpest of the group: they are styled as selectable
      // chips, sitting under a heading that says "Add an area".
      await pumpLocalized(
        tester,
        const TherapistServiceAreasScreen(),
        size: const Size(390, 1400),
      );
      await tester.pump();

      final chips = find.descendant(
        of: find.byType(Wrap).last,
        matching: find.byType(GestureDetector),
      );
      expect(chips, findsNWidgets(5));

      await expectExplains(
        tester,
        control: chips.first,
        title: (l) => l.serviceAreasAddUnavailableTitle,
      );
    });
  });

  testWidgets('the contact composer is visibly disabled, not silently inert', (
    tester,
  ) async {
    // The worst of the twelve. A patient could write five lines into this
    // box, press Send, and get nothing back — no snackbar, no error, no
    // state change. They would reasonably believe the message had been sent.
    await pumpLocalized(
      tester,
      const PatientContactScreen(),
      size: const Size(390, 1200),
    );
    await tester.pump();

    final l10n = tester.element(find.byType(Scaffold)).l10n;

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(field.decoration!.hintText, l10n.contactMessageUnavailable);

    final send = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(
      send.onPressed,
      isNull,
      reason:
          'A disabled Send is honest. A Send that swallows the message is '
          'the one failure this screen must not have.',
    );

    // The details that *do* work are still on the screen, which is the point
    // of disabling rather than removing.
    expect(find.text('support@sahayatrihealth.com'), findsOneWidget);
    expect(find.text('+977 1 590 1234'), findsOneWidget);
  });
}
