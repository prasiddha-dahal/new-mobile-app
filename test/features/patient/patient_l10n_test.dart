import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/session_labels.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/widgets/discovery_section.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_ne.dart';

import '../../l10n_harness.dart';

/// The patient side is where most of the app's copy lives, and the discovery
/// cards are the densest bit of it: three titles and three descriptions that
/// used to be `const` strings baked into a record.
void main() {
  final ne = AppLocalizationsNe();

  testWidgets('the discovery cards change language with the app', (
    tester,
  ) async {
    final container = await pumpLocalized(
      tester,
      const Scaffold(
        body: Column(
          children: [
            DiscoveryCard(entry: findTherapistEntry),
            DiscoveryCard(entry: findClinicEntry),
            DiscoveryCard(entry: viewOnMapEntry),
          ],
        ),
      ),
    );

    expect(find.text('Find a Physiotherapist'), findsOneWidget);
    expect(find.text('Find a Clinic'), findsOneWidget);
    expect(find.text('View on Map'), findsOneWidget);

    await switchTo(tester, container, const Locale('ne'));

    expectNoEnglish(tester, const [
      'Find a Physiotherapist',
      'Book a verified therapist for a home visit.',
      'Find a Clinic',
      'Book a visit at a clinic near you.',
      'View on Map',
      'See therapists and clinics that cover your area.',
    ]);
    expect(find.text(ne.discoveryFindTherapistTitle), findsOneWidget);
  });

  testWidgets('so do the compact shortcuts on Find', (tester) async {
    final container = await pumpLocalized(
      tester,
      const Scaffold(
        body: Row(
          children: [
            Expanded(child: DiscoveryShortcut(entry: findClinicEntry)),
            Expanded(child: DiscoveryShortcut(entry: viewOnMapEntry)),
          ],
        ),
      ),
    );
    await switchTo(tester, container, const Locale('ne'));

    expectNoEnglish(tester, const ['Find a Clinic', 'View on Map']);
  });

  testWidgets('two shortcuts fit one narrow row in Nepali', (tester) async {
    // They are Expanded halves of a Row on a screen whose job is the results
    // below them, so a longer label has to ellipsise rather than push.
    await pumpLocalized(
      tester,
      const Scaffold(
        body: Row(
          children: [
            Expanded(child: DiscoveryShortcut(entry: findClinicEntry)),
            SizedBox(width: 8),
            Expanded(child: DiscoveryShortcut(entry: viewOnMapEntry)),
          ],
        ),
      ),
      locale: const Locale('ne'),
      size: const Size(320, 640),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('every session status has a Nepali label', () {
    // The enum's own `label` stays English — it is the value the domain layer
    // carries. This is the lookup a badge actually reads, and a status added
    // to the enum without a key here would not compile.
    final devanagari = RegExp(r'[ऀ-ॿ]');
    for (final status in SessionStatus.values) {
      final label = sessionStatusLabel(status, ne);
      expect(label, isNotEmpty, reason: status.name);
      expect(
        devanagari.hasMatch(label),
        isTrue,
        reason: '${status.name} still reads "$label"',
      );
    }
  });

  test('and the English labels still match the domain defaults', () {
    // Not a tautology: it pins that moving the copy into the ARB did not
    // quietly reword any status along the way.
    final en = englishL10n;
    for (final status in SessionStatus.values) {
      expect(sessionStatusLabel(status, en), status.label, reason: status.name);
    }
  });
}
