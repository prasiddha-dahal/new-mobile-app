import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/shared_widgets.dart';

/// `PageHeader` is the in-page title bar that sits under the shared
/// `AppHeader` on a sub-page. Thirteen screens moved onto it from the
/// hand-rolled `BackHeader`, so a title it cannot fit is now thirteen
/// screens' problem rather than one widget's.
void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required String title,
    double textScale = 1.0,
    Size size = const Size(320, 640),
    VoidCallback? onBack,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(body: PageHeader(title: title, onBack: onBack)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a long title on a narrow phone at a large text scale gives '
      'way instead of overflowing', (tester) async {
    // The real case: the longest title in the app, on the smallest phone we
    // draw for, at the text size someone who needs it actually uses. This
    // overflowed the row by 481px before the title had any width of its own.
    await pumpHeader(
      tester,
      title: 'Certifications & license',
      textScale: 1.6,
      onBack: () {},
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a title that fits is still centred', (tester) async {
    // The truncation must not cost the centring, which is the whole point of
    // this bar: the title sits between two 36dp gutters, not beside the back
    // button.
    await pumpHeader(tester, title: 'My Packages', onBack: () {});

    final row = tester.getRect(find.byType(PageHeader));
    final text = tester.getRect(find.text('My Packages'));
    expect(text.center.dx, closeTo(row.center.dx, 1));
  });

  testWidgets('and it is still centred with no back button', (tester) async {
    await pumpHeader(tester, title: 'My Packages');

    final row = tester.getRect(find.byType(PageHeader));
    final text = tester.getRect(find.text('My Packages'));
    expect(text.center.dx, closeTo(row.center.dx, 1));
  });
}
