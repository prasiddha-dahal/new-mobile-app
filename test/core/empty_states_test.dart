import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/state_views.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_sessions_screen.dart';

import '../l10n_harness.dart';

/// One empty state, not two.
///
/// `EmptyState` (one grey line) and `EmptyStateView` (icon, title,
/// description) both existed, and the split between them ran the wrong way
/// round: the bare sentence was on Home, Find, Sessions and Cart — the four
/// busiest patient surfaces — and the designed one on the fifteen quieter
/// screens. These pin that there is only one now, and that the designed one
/// survives being handed a whole sentence as its title in Devanagari at 1.6x
/// on a 320dp phone, which is what those four screens pass it.
void main() {
  group('EmptyStateView', () {
    testWidgets('compact is a smaller icon and smaller type, same structure', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        const Scaffold(
          body: Column(
            children: [
              Expanded(child: EmptyStateView(title: 'Full', description: 'd')),
              Expanded(
                child: EmptyStateView(
                  title: 'Compact',
                  description: 'd',
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      );

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.map((i) => i.size), [40.0, 28.0]);

      // Both still draw an icon, a title and a description — `compact` is a
      // size, not a different component. That is the point of folding the
      // bare `EmptyState` into this one rather than keeping both.
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('d'), findsNWidgets(2));
    });

    testWidgets('an action sits under the description', (tester) async {
      await pumpLocalized(
        tester,
        const Scaffold(
          body: EmptyStateView(
            title: 'Nothing here',
            description: 'Not yet.',
            action: Text('Do something'),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Do something')).dy,
        greaterThan(tester.getTopLeft(find.text('Not yet.')).dy),
      );
    });
  });

  group('Sessions with nothing booked', () {
    List<Override> empty() => [
      patientSessionsProvider.overrideWith((_) async => <Session>[]),
      therapistListProvider.overrideWith((_) async => <Therapist>[]),
    ];

    testWidgets('draws the designed state, not a grey line', (tester) async {
      await pumpLocalized(
        tester,
        const Scaffold(
          backgroundColor: AppColors.cream,
          body: PatientSessionsScreen(),
        ),
        overrides: empty(),
        theme: AppTheme.light,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
    });

    testWidgets('and at 320dp / 1.6x in Nepali', (tester) async {
      // The worst case for this component: a whole sentence handed to it as a
      // *title*, set at 16/700 and centred, in the longer script, at the
      // accessibility font size, on the narrowest phone. If a bold centred
      // sentence were going to wrap into a column of single words or push the
      // icon off the top, it would be here.
      await pumpLocalized(
        tester,
        const Scaffold(
          backgroundColor: AppColors.cream,
          body: PatientSessionsScreen(),
        ),
        locale: const Locale('ne'),
        size: const Size(320, 640),
        textScale: 1.6,
        overrides: empty(),
        theme: AppTheme.light,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(PatientSessionsScreen),
        matchesGoldenFile('goldens/sessions_empty_320_ne_1_6x.png'),
      );
    });
  });
}
