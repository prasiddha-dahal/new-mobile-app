import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_find_screen.dart';

import '../../l10n_harness.dart';

/// Find has to survive the smallest phone at the largest text.
///
/// 320dp at 1.6x is the accessibility setting the audits on this project use,
/// and Nepali is the longer of the two languages. The header block alone --
/// eyebrow, title, search field, filter pill and the two care shortcuts --
/// used to burst by 157px there, before a single result was drawn.
///
/// The existing Nepali sweep runs at 1.0x, which is why this went unseen: the
/// row fits in Devanagari at normal size and only fails once the reader turns
/// the font up.
void main() {
  testWidgets('the header block fits a 320dp phone at 1.6x in Nepali', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      Theme(data: AppTheme.light, child: const PatientFindScreen()),
      locale: const Locale('ne'),
      size: const Size(320, 640),
      textScale: 1.6,
      // An empty result set is the harshest case for the header: nothing
      // below it to absorb the space, and no network call left pending.
      overrides: [therapistListProvider.overrideWith((_) async => [])],
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'nothing in the header may overflow at the smallest size the '
          'app claims to support',
    );
  });

  testWidgets('and at 1.6x in English', (tester) async {
    await pumpLocalized(
      tester,
      Theme(data: AppTheme.light, child: const PatientFindScreen()),
      size: const Size(320, 640),
      textScale: 1.6,
      overrides: [therapistListProvider.overrideWith((_) async => [])],
    );
    expect(tester.takeException(), isNull);
  });
}
