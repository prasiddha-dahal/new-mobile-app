import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/screens/signup_screen.dart';

import '../../l10n_harness.dart';

/// The therapist signup form used to collect five fields it could not send.
///
/// Specialism and city were multi-select chip rows, and the submit sent
/// `.first` of each — so a therapist who picked three specialisms had two
/// dropped, silently, with the chips still showing all three as chosen. The
/// API stores one `specialty` column and one `city`, so the multi-select was
/// promising something that could never be kept.
///
/// Working days, time blocks and payout method were worse: signup accepts
/// none of them, so all three were read into state and discarded on submit.
///
/// Nothing asserted what the form submitted, which is why this survived. These
/// pin the contract at the surface a person actually sees: what you can pick,
/// and whether picking again replaces or silently accumulates.
void main() {
  /// Opens signup and switches to the therapist flow.
  Future<void> pumpTherapistForm(WidgetTester tester) async {
    await pumpLocalized(tester, const SignupScreen(), size: const Size(390, 2400));
    final therapistTab = find.textContaining(
      RegExp('physiotherapist', caseSensitive: false),
    );
    await tester.tap(therapistTab.first);
    await tester.pumpAndSettle();
  }

  /// A chip reads as chosen by its fill, which is the only signal a person has.
  bool isChosen(WidgetTester tester, String label) {
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    return (box.decoration as BoxDecoration).color == AppColors.pine;
  }

  testWidgets('choosing a second specialism replaces the first', (tester) async {
    await pumpTherapistForm(tester);

    expect(isChosen(tester, 'Sports & post-surgery'), isTrue,
        reason: 'the default should read as chosen');

    await tester.tap(find.text('Neuro'));
    await tester.pumpAndSettle();

    expect(isChosen(tester, 'Neuro'), isTrue);
    expect(
      isChosen(tester, 'Sports & post-surgery'),
      isFalse,
      reason: 'both must never read as chosen: only one is ever submitted, and '
          'showing two is exactly how the dropped value went unnoticed',
    );
  });

  testWidgets('choosing a second city replaces the first', (tester) async {
    await pumpTherapistForm(tester);

    await tester.tap(find.text('Bhaktapur'));
    await tester.pumpAndSettle();

    expect(isChosen(tester, 'Bhaktapur'), isTrue);
    expect(isChosen(tester, 'Lalitpur'), isFalse);
  });

  testWidgets('the form no longer collects what it cannot send', (tester) async {
    await pumpTherapistForm(tester);

    // Signup takes no working days, time blocks or payout method. Any control
    // for them here is collecting input to throw away.
    for (final gone in ['Mon', 'Morning', 'Afternoon', 'eSewa', 'Khalti']) {
      expect(
        find.text(gone),
        findsNothing,
        reason: '"$gone" cannot reach the API from signup',
      );
    }
  });

  testWidgets('and says where those are set instead', (tester) async {
    await pumpTherapistForm(tester);
    expect(
      find.textContaining(RegExp('approved', caseSensitive: false)),
      findsWidgets,
      reason: 'removing the controls without saying where they went would '
          'leave the therapist wondering when they get to set their hours',
    );
  });
}
