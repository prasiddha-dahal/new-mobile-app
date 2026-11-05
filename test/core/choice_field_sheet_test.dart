import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/form_fields.dart';

import '../l10n_harness.dart';

/// `AppChoiceField`'s sheet could not show a long list.
///
/// Every caller until the complaint form passed a handful of fixed options —
/// a gender, a category, a city — and the un-scrollable `Column` fitted. The
/// complaint form picks from the live therapist directory, so the sheet drew a
/// yellow overflow bar across its last rows on a real phone. The therapist a
/// patient wanted to report could be one of the ones underneath it, and there
/// was no way to scroll to them.
///
/// Both cases are worth holding: a long list must scroll, and a short one must
/// not suddenly become full height because of the fix.
void main() {
  Future<void> pumpField(WidgetTester tester, List<String> options) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: Center(
          child: AppChoiceField(
            label: 'PICK',
            hint: 'Choose one',
            options: options,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose one'));
    await tester.pumpAndSettle();
  }

  testWidgets('a directory-length list scrolls instead of overflowing', (
    tester,
  ) async {
    await pumpField(tester, [for (var i = 0; i < 40; i++) 'Dr. Therapist $i']);

    expect(
      tester.takeException(),
      isNull,
      reason: 'the sheet must not overflow, however long the list is',
    );

    // The last entry is below the fold; it has to be reachable.
    await tester.dragUntilVisible(
      find.text('Dr. Therapist 39'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Dr. Therapist 39'), findsOneWidget);
  });

  testWidgets('a short list still shrink-wraps', (tester) async {
    await pumpField(tester, ['Female', 'Male', 'Other']);

    final sheet = tester.getRect(find.byType(ListView));
    expect(
      sheet.height,
      lessThan(tester.view.physicalSize.height / 2),
      reason: 'three options should not open a half-screen sheet',
    );
  });
}
