import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/report_therapist_screen.dart';

import '../../l10n_harness.dart';

/// Reporting a therapist could not work, and nothing said so.
///
/// The screen collected the therapist's name as free text and sent
/// `againstId: ''`. `ComplaintCreate` declares that field `min_length=1`, so
/// every single report came back 422 — the form looked like it submitted and
/// no complaint was ever filed. A patient trying to raise a safety concern got
/// a generic error and no other route to admin.
///
/// The fix is a picker over the real directory, because the id is the only
/// thing that ties a complaint to an account. These tests pin the two halves
/// that matter: that the control is a picker rather than a text box, and that
/// the list's own loading and failure states are rendered instead of an empty
/// dropdown that looks like "no therapists exist".
Therapist _therapist(String id, String name) => Therapist(
      id: id,
      userId: 'u-$id',
      name: name,
      specialty: 'Sports',
      city: 'Lalitpur',
      gender: 'Female',
      rating: 4.5,
      reviewCount: 3,
      fee: 1500,
      experienceYears: 5,
      bio: '',
    );

void main() {
  testWidgets('the therapist is picked from the directory, not typed', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const ReportTherapistScreen(),
      size: const Size(390, 2000),
      overrides: [
        therapistListProvider.overrideWith(
          (_) async => [_therapist('t1', 'Sita Gurung')],
        ),
      ],
    );
    await tester.pumpAndSettle();

    // The name box was the screen's only TextFormField; "what happened" is a
    // plain TextField. One left here would mean the typed name is still there.
    expect(
      find.byType(TextFormField),
      findsNothing,
      reason: 'a typed name cannot produce the id the API requires',
    );
    expect(find.text('THERAPIST NAME'), findsOneWidget);
  });

  testWidgets('submitting without picking one says so instead of failing', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const ReportTherapistScreen(),
      size: const Size(390, 2000),
      overrides: [
        therapistListProvider.overrideWith(
          (_) async => [_therapist('t1', 'Sita Gurung')],
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send report to admin'));
    await tester.pumpAndSettle();

    // The old screen let this through to a 422. Nothing should leave the app.
    expect(find.text('Choose the therapist you are reporting.'), findsOneWidget);
  });

  testWidgets('a failed directory fetch offers a retry, not an empty list', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      const ReportTherapistScreen(),
      size: const Size(390, 2000),
      overrides: [
        therapistListProvider.overrideWith(
          (_) async => throw Exception('offline'),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load the therapist list.'),
      findsOneWidget,
      reason: 'an empty picker reads as "there are no therapists", which is a '
          'different and much worse thing to tell someone filing a complaint',
    );
    expect(find.textContaining(RegExp('retry', caseSensitive: false)),
        findsWidgets);
  });
}
