import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/system_bar_inset.dart';

/// The pinned "Confirm & pay" button was half under the system navigation.
///
/// Its bar wrapped itself in `SafeArea`, which reads `MediaQuery.padding`.
/// `Scaffold` zeroes the bottom padding -- and `viewPadding` with it -- for its
/// `bottomSheet` slot, so inside the bar there is nothing left to read and the
/// Android back/home/recents buttons were drawn over the lower half of the
/// button. The inset has to be read from the screen's own context, above the
/// Scaffold, which is what these mount.
void main() {
  const barKey = Key('bar');
  const height = 800.0;

  /// A screen shaped like the booking one: reads the inset in `build`, hands it
  /// to a bar in the Scaffold's `bottomSheet`.
  Widget screen(Widget Function(BuildContext screenContext, Widget bar) wrap) {
    return Builder(
      builder: (context) => Scaffold(
        bottomSheet: wrap(context, const SizedBox(key: barKey, height: 48)),
      ),
    );
  }

  Future<double> bottomOfBar(
    WidgetTester tester, {
    required Widget Function(BuildContext screenContext, Widget bar) wrap,
    double systemBar = 48,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, height);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(400, height),
          padding: EdgeInsets.only(bottom: systemBar),
          viewPadding: EdgeInsets.only(bottom: systemBar),
        ),
        child: MaterialApp(home: screen(wrap)),
      ),
    );
    return tester.getBottomLeft(find.byKey(barKey)).dy;
  }

  testWidgets('lifts the bar above the system navigation', (tester) async {
    final bottom = await bottomOfBar(
      tester,
      wrap: (screenContext, bar) =>
          SystemBarInset(inset: SystemBarInset.of(screenContext), child: bar),
    );

    expect(bottom, height - 48);
  });

  testWidgets('where SafeArea inside the bottomSheet reserved nothing', (
    tester,
  ) async {
    // The bug, pinned: the Scaffold has already taken the padding away, so
    // SafeArea leaves the bar at the very bottom, under the system buttons.
    final bottom = await bottomOfBar(
      tester,
      wrap: (_, bar) => SafeArea(child: bar),
    );

    expect(bottom, height);
  });

  testWidgets('and reading viewPadding from inside it is no better', (
    tester,
  ) async {
    // removePadding takes the same amount off viewPadding, so the obvious
    // second attempt reads zero as well.
    final bottom = await bottomOfBar(
      tester,
      wrap: (_, bar) => Builder(
        builder: (inner) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(inner).bottom,
          ),
          child: bar,
        ),
      ),
    );

    expect(bottom, height);
  });

  testWidgets('adds nothing on a phone with gesture navigation', (
    tester,
  ) async {
    final bottom = await bottomOfBar(
      tester,
      systemBar: 0,
      wrap: (screenContext, bar) =>
          SystemBarInset(inset: SystemBarInset.of(screenContext), child: bar),
    );

    expect(bottom, height);
  });

  testWidgets('follows the inset of the device it is on', (tester) async {
    final bottom = await bottomOfBar(
      tester,
      systemBar: 34,
      wrap: (screenContext, bar) =>
          SystemBarInset(inset: SystemBarInset.of(screenContext), child: bar),
    );

    expect(bottom, height - 34);
  });
}
