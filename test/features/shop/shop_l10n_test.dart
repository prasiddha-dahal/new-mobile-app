import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/features/about/presentation/screens/about_us_screen.dart';
import 'package:sahayatri_care_connect/features/about/presentation/screens/privacy_policy_screen.dart';
import 'package:sahayatri_care_connect/features/about/presentation/screens/terms_screen.dart';
import 'package:sahayatri_care_connect/features/notifications/presentation/widgets/notification_visuals.dart';
import 'package:sahayatri_care_connect/features/shop/domain/entities/product.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/shop_labels.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_ne.dart';

import '../../l10n_harness.dart';

/// The last of the per-area checks: the shop's category labels, the
/// notification pills, and the three about/legal pages — which are the only
/// screens in the app that are almost entirely prose.
void main() {
  final ne = AppLocalizationsNe();
  final devanagari = RegExp(r'[ऀ-ॿ]');

  test('every product category has a Nepali label', () {
    // The enum keeps its English `label` as the domain-layer value; this is
    // the lookup a tab actually reads, and a category added without a key
    // here would not compile.
    for (final category in ProductCategory.values) {
      final label = productCategoryLabel(category, ne);
      expect(label, isNotEmpty, reason: category.name);
      expect(
        devanagari.hasMatch(label),
        isTrue,
        reason: '${category.name} still reads "$label"',
      );
    }
  });

  test('and the English labels still match the domain defaults', () {
    for (final category in ProductCategory.values) {
      expect(
        productCategoryLabel(category, englishL10n),
        category.label,
        reason: category.name,
      );
    }
  });

  test('every notification pill has a Nepali badge', () {
    for (final pill in NotificationPill.values) {
      expect(
        devanagari.hasMatch(pill.labelIn(ne)),
        isTrue,
        reason: '${pill.name} still reads "${pill.labelIn(ne)}"',
      );
      // The English handle is what the tests address the badge by, so it has
      // to survive the move to the ARB unchanged.
      expect(pill.labelIn(englishL10n), pill.label, reason: pill.name);
    }
  });

  testWidgets('the about page reads in Nepali', (tester) async {
    final container = await pumpLocalized(tester, const AboutUsScreen());

    expect(find.text('Our mission'), findsOneWidget);
    await switchTo(tester, container, const Locale('ne'));

    expectNoEnglish(tester, const [
      'About us',
      'Licensed physio care, at your door',
      'Our mission',
      'Verified professionals',
      'Home & clinic care',
      'Care from anywhere',
      'Verified',
      'Valley-wide',
      'Home or clinic',
      'You choose',
    ]);
  });

  testWidgets('so do the terms and the privacy policy', (tester) async {
    // Their Nepali has not been through legal review — see the doc comments on
    // both screens. That is a separate problem from whether they render, which
    // is what this checks.
    for (final screen in const [TermsScreen(), PrivacyPolicyScreen()]) {
      await pumpLocalized(tester, screen, locale: const Locale('ne'));
      await tester.pump();

      final rendered = renderedText(tester);
      expect(rendered, isNotEmpty, reason: '$screen rendered nothing');
      expect(
        rendered.where((s) => devanagari.hasMatch(s)).length,
        greaterThan(rendered.length ~/ 2),
        reason: 'most of $screen is still English',
      );
    }
  });
}
