import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';

import 'tab_shell_harness.dart';

/// The bottom bar has to clear the system navigation.
///
/// On a device with on-screen back/home/recents buttons the system reserves
/// roughly 48dp at the bottom of the window. A bar that ignores it is drawn
/// underneath those buttons, which is exactly what happened: the buttons
/// landed on top of the tab icons and the centre action.
///
/// `SafeArea` is the obvious tool and the wrong one here — it reads
/// `MediaQuery.padding`, which is already consumed by the time a Scaffold
/// builds its `bottomNavigationBar`, so it resolves to zero. These tests pin
/// the behaviour to `viewPadding`, which reports what the system bar occupies
/// regardless of who consumed the padding.
///
/// The bar now hangs off the shell's Scaffold rather than each screen's, so
/// these mount it the way the app does today: through the real `PatientShell`
/// over a `StatefulShellRoute`.
void main() {
  /// Mounts the nav the way the app does — as the shell Scaffold's
  /// `bottomNavigationBar`, under a MediaQuery reporting [bottomInset].
  Future<void> pumpNav(WidgetTester tester, double bottomInset) async {
    final router = patientShellHarnessRouter(
      // Shaped like the real tab screens: a Scaffold whose body is a SafeArea.
      screens: const [
        Scaffold(
          body: SafeArea(child: SizedBox.expand(key: Key('body'))),
        ),
        Scaffold(body: SafeArea(child: SizedBox.expand())),
        Scaffold(body: SafeArea(child: SizedBox.expand())),
        Scaffold(body: SafeArea(child: SizedBox.expand())),
      ],
    );

    await tester.pumpWidget(
      shellHarnessApp(
        router,
        mediaQuery: MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: bottomInset),
          padding: EdgeInsets.only(bottom: bottomInset),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Distance from the bottom of the icon row to the bottom of the bar.
  double gapBelowIcons(WidgetTester tester) {
    final bar = tester.getRect(find.byType(PatientNav));
    final icons = tester.getRect(find.byIcon(Icons.home_rounded));
    return bar.bottom - icons.bottom;
  }

  testWidgets('leaves room for on-screen navigation buttons', (tester) async {
    await pumpNav(tester, 48);
    // The icons must sit clear of the 48dp the buttons occupy.
    expect(gapBelowIcons(tester), greaterThanOrEqualTo(48));
  });

  testWidgets('still has breathing room with no system inset', (tester) async {
    await pumpNav(tester, 0);
    final gap = gapBelowIcons(tester);
    expect(gap, greaterThan(0), reason: 'icons should not touch the edge');
    expect(
      gap,
      lessThan(48),
      reason: 'and should not reserve space for a bar that is not there',
    );
  });

  testWidgets('grows with the inset rather than using a fixed height', (
    tester,
  ) async {
    await pumpNav(tester, 0);
    final short = tester.getRect(find.byType(PatientNav)).height;

    await pumpNav(tester, 48);
    final tall = tester.getRect(find.byType(PatientNav)).height;

    // A fixed-height bar would report the same height for both, which is the
    // shape of the original bug.
    expect(tall - short, closeTo(48, 0.5));
  });

  testWidgets('and the screen above it is not padded twice', (tester) async {
    await pumpNav(tester, 48);
    // The shell Scaffold consumes the bottom padding for its body, so a
    // screen's own `SafeArea` must not reserve the inset a second time —
    // the screen should run right down to the top of the bar.
    final body = tester.getRect(find.byKey(const Key('body')));
    final bar = tester.getRect(find.byType(PatientNav));
    expect(body.bottom, closeTo(bar.top, 0.5));
  });
}
