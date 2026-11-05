import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';

/// The centre control's glyph is per-role, and the two roles disagree on
/// purpose: the patient designs draw a `+`, the therapist bar has no such
/// design and keeps the calendar it shipped with. A future "tidy-up" that
/// unifies them should have to delete one of these.
void main() {
  Future<void> pumpBar(WidgetTester tester, Widget bar) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(bottomNavigationBar: bar)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the patient centre action is a +', (tester) async {
    await pumpBar(tester, PatientNav(currentIndex: 0, onSelect: (_) {}));

    expect(find.byIcon(Icons.add), findsOneWidget);
    // Not the calendar it used to be: nothing behind this button is a
    // calendar, so the glyph was promising a screen that never opened.
    expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
  });

  testWidgets('the therapist centre action is unchanged', (tester) async {
    await pumpBar(tester, TherapistNav(currentIndex: 0, onSelect: (_) {}));

    expect(find.byIcon(Icons.add), findsNothing);
    // Two of them: the Schedule tab and the centre action. That duplication
    // is the reason this is worth revisiting — but not on this branch, which
    // owns no therapist design.
    expect(find.byIcon(Icons.calendar_month_rounded), findsNWidgets(2));
  });
}
