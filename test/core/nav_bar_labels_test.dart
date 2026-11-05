import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';

import '../l10n_harness.dart';
import 'tab_shell_harness.dart';

/// The bar used to draw four icons and hang the words off `Semantics` alone.
///
/// Every patient tab is named, in order: `Home · Sessions · Recovery · Account`.
/// under the glyphs, and an icon-only bar asks the user to learn four
/// pictograms — `◷` for Sessions and `☰` for Availability are not words
/// anyone guesses. These pin the labels, their two states, and the fact that
/// adding them did not cost the bar its system-inset behaviour (which
/// `nav_bar_insets_test.dart` owns) or announce every tab twice.
void main() {
  /// The bar on its own, at [size] and [textScale].
  Future<void> pumpBar(
    WidgetTester tester,
    Widget bar, {
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    await pumpLocalized(
      tester,
      Scaffold(bottomNavigationBar: bar),
      locale: locale,
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  /// The `Text` widget carrying [label] inside the bar.
  Text labelOf(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label));

  group('the labels are drawn', () {
    testWidgets('on the patient bar, in tab order', (tester) async {
      await pumpBar(tester, PatientNav(currentIndex: 0, onSelect: (_) {}));

      for (final label in ['Home', 'Sessions', 'Recovery', 'Account']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('and on the therapist bar', (tester) async {
      await pumpBar(tester, TherapistNav(currentIndex: 0, onSelect: (_) {}));

      for (final label in ['Home', 'Schedule', 'Requests', 'Account']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('at the design\'s 10px, under the icon rather than beside it', (
      tester,
    ) async {
      await pumpBar(tester, PatientNav(currentIndex: 0, onSelect: (_) {}));

      expect(labelOf(tester, 'Home').style!.fontSize, 10);

      final icon = tester.getRect(find.byIcon(Icons.home_rounded));
      final text = tester.getRect(find.text('Home'));
      expect(
        text.top,
        greaterThanOrEqualTo(icon.bottom),
        reason: 'the label belongs below the glyph, not next to it',
      );
      expect(
        text.center.dx,
        closeTo(icon.center.dx, 1),
        reason: 'and centred on it',
      );
    });
  });

  group('active and inactive', () {
    testWidgets('the lit tab is pine and semibold, the rest are not', (
      tester,
    ) async {
      await pumpBar(tester, PatientNav(currentIndex: 2, onSelect: (_) {}));

      final active = labelOf(tester, 'Recovery').style!;
      expect(active.color, AppColors.pine);
      expect(active.fontWeight, FontWeight.w600);

      for (final label in ['Home', 'Sessions', 'Account']) {
        final inactive = labelOf(tester, label).style!;
        expect(inactive.color, AppColors.inkMute);
        expect(inactive.fontWeight, FontWeight.w400);
      }
    });

    testWidgets('the label and its icon always agree on colour', (
      tester,
    ) async {
      // A pine icon over a grey word would read as a half-selected tab.
      //
      // Asserted on the patient bar because the therapist bar draws
      // `calendar_month_rounded` twice — once for Schedule, once as the
      // centre action's glyph — so `find.byIcon` is ambiguous there. That
      // duplication is a real finding, recorded in docs/design_review.md;
      // it is not this test's to fix.
      await pumpBar(tester, PatientNav(currentIndex: 1, onSelect: (_) {}));

      final icon = tester.widget<Icon>(find.byIcon(Icons.history_rounded));
      expect(labelOf(tester, 'Sessions').style!.color, icon.color);
      expect(icon.color, AppColors.pine);
    });
  });

  group('the bar still behaves', () {
    testWidgets('a tap anywhere in the slot selects it, not just the glyph', (
      tester,
    ) async {
      // The hit area used to be the 24dp icon alone — half the 48dp minimum.
      int? tapped;
      await pumpBar(
        tester,
        PatientNav(currentIndex: 0, onSelect: (i) => tapped = i),
      );

      final slot = tester.getRect(find.text('Account'));
      // Two pixels below the label: inside the slot, outside both the glyph
      // and the text.
      await tester.tapAt(Offset(slot.center.dx, slot.bottom + 2));
      await tester.pumpAndSettle();

      expect(tapped, 3);
    });

    testWidgets('each tab is announced once, not twice', (tester) async {
      // The visible `Text` and the wrapping `Semantics` both carry the word.
      // Without `excludeSemantics` a screen reader reads "Home, Home".
      final handle = tester.ensureSemantics();
      await pumpBar(tester, PatientNav(currentIndex: 0, onSelect: (_) {}));

      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Recovery'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('and the labels survive a small phone at a large text scale', (
      tester,
    ) async {
      // 320dp at 1.6x is the combination that breaks rows in this app. The
      // labels scale down rather than clip, so nothing overflows and all four
      // labels are still whole.
      await pumpBar(
        tester,
        PatientNav(currentIndex: 0, onSelect: (_) {}),
        size: const Size(320, 640),
        textScale: 1.6,
      );

      expect(tester.takeException(), isNull);
      for (final label in ['Home', 'Sessions', 'Recovery', 'Account']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('in Nepali too', (tester) async {
      await pumpBar(
        tester,
        TherapistNav(currentIndex: 0, onSelect: (_) {}),
        locale: const Locale('ne'),
        size: const Size(320, 640),
        textScale: 1.6,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('अनुरोधहरू'), findsOneWidget);
    });
  });

  group('inside the real shell', () {
    testWidgets('the bar is taller than it was but still a bar', (
      tester,
    ) async {
      // Labels cost height, and the bar sits on top of the system inset. The
      // ceiling here is a judgement — a bottom bar taking a fifth of a 640pt
      // phone would be a regression whatever it says — and the floor proves
      // the labels are actually occupying space rather than being clipped to
      // nothing.
      final router = patientShellHarnessRouter(
        screens: const [
          Scaffold(body: SizedBox.expand()),
          Scaffold(body: SizedBox.expand()),
          Scaffold(body: SizedBox.expand()),
          Scaffold(body: SizedBox.expand()),
        ],
      );
      await tester.pumpWidget(shellHarnessApp(router));
      await tester.pumpAndSettle();

      final height = tester.getRect(find.byType(PatientNav)).height;
      expect(height, greaterThan(48));
      expect(height, lessThan(80));
    });
  });
}
