import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/state_views.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_find_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_sessions_screen.dart';

import '../l10n_harness.dart';

/// The shared skeleton, and the one screen-shaped proof that it waits the way
/// the rest of `state_views.dart` fails, empties and explains.
///
/// Two of these are regressions rather than specifications. [SkeletonList]
/// was a `Column` in its first draft, which overflowed by 112px the moment it
/// landed inside the `Expanded` on Find — a striped bar where the wait should
/// be. And a stack of five boxes each carrying its own `Semantics` made a
/// screen reader say "Loading" five times, which is worse than the silence
/// the spinners left behind.
void main() {
  group('SkeletonBox', () {
    testWidgets('is a mist block at the card radius', (tester) async {
      await pumpLocalized(
        tester,
        const Scaffold(body: Center(child: SkeletonBox(width: 120))),
      );

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;

      expect(decoration.color, AppColors.mist);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppRadii.card),
        reason:
            'A skeleton stands where a card is about to be, so it has to be '
            'the same shape as the card — otherwise the content snaps into a '
            'different silhouette on arrival.',
      );
    });

    testWidgets('does not animate', (tester) async {
      // Not a style note. An unbounded animation never lets `pumpAndSettle`
      // return, and most of this suite is built on it — so a shimmer here
      // would hang every test that waits for a screen holding one.
      await pumpLocalized(
        tester,
        const Scaffold(body: Center(child: SkeletonBox())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(SkeletonBox), findsOneWidget);
    });
  });

  group('SkeletonList', () {
    testWidgets('clips rather than overflows inside a bounded parent', (
      tester,
    ) async {
      // 6 x 96 plus the gaps is far more than the 200 it is given. The
      // `Column` this started as painted the striped overflow bar here.
      await pumpLocalized(
        tester,
        const Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 200,
                child: Column(
                  children: [
                    Expanded(child: SkeletonList(count: 6, itemHeight: 96)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SkeletonList)).height, 200);
    });

    testWidgets('sizes to its content inside an unbounded parent', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: SkeletonList(count: 3, itemHeight: 50, gap: 10),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Three 50s and two 10s.
      expect(tester.getSize(find.byType(SkeletonList)).height, 170);
    });

    testWidgets('announces the wait once, not once per row', (tester) async {
      await pumpLocalized(
        tester,
        const Scaffold(body: SkeletonList(count: 5)),
      );

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Loading'),
        findsOneWidget,
        reason:
            'Five placeholder rows are one wait, and a reader that says so '
            'five times is noise.',
      );
      handle.dispose();
    });
  });

  group('a screen waiting', () {
    /// Find, with its therapist list permanently in flight.
    Widget findScreen() => const Scaffold(
      backgroundColor: AppColors.cream,
      body: PatientFindScreen(),
    );

    List<Override> pending() => [
      therapistListProvider.overrideWith(
        (_) => Completer<List<Therapist>>().future,
      ),
    ];

    /// Sessions, likewise stalled. Used for the small-phone shot because
    /// Find cannot be rendered at 320dp / 1.6x at all: its header block —
    /// eyebrow, 26px Fraunces title, search field, filter row and chips —
    /// is 157px taller than the viewport before the results start, so the
    /// `Column` bursts. That is not this branch's doing; it reproduces on
    /// the base commit with a *loaded* list, and it is reported rather than
    /// fixed here because narrowing that header is a design decision (the
    /// design review's 2.10, one screen over).
    Widget sessionsScreen() => const Scaffold(
      backgroundColor: AppColors.cream,
      body: PatientSessionsScreen(),
    );

    List<Override> pendingSessions() => [
      patientSessionsProvider.overrideWith(
        (_) => Completer<List<Session>>().future,
      ),
    ];

    testWidgets('draws skeleton rows, not a lone spinner', (tester) async {
      await pumpLocalized(
        tester,
        findScreen(),
        overrides: pending(),
        theme: AppTheme.light,
      );
      await tester.pump();

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason:
            'The whole point of §2.7: a list that is waiting draws the shape '
            'of what is coming, rather than a 22dp spinner in the middle of '
            'an empty screen.',
      );
    });

    testWidgets('and keeps the screen usable while it waits', (tester) async {
      await pumpLocalized(
        tester,
        findScreen(),
        overrides: pending(),
        theme: AppTheme.light,
      );
      await tester.pump();

      // The header, the search field and the filter pill are all still there.
      // The spinner replaced only the results, and so does the skeleton.
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('390dp, English', (tester) async {
      await pumpLocalized(
        tester,
        findScreen(),
        locale: const Locale('en'),
        size: const Size(390, 640),
        overrides: pending(),
        theme: AppTheme.light,
      );
      await tester.pump();

      await expectLater(
        find.byType(PatientFindScreen),
        matchesGoldenFile('goldens/find_loading_390_en.png'),
      );
    });

    testWidgets('and Sessions at 320dp / 1.6x in Nepali', (tester) async {
      // The size the rows in this app stop fitting at. A skeleton carries no
      // text, so what this watches for is the opposite failure: the tab bar
      // and header growing under Devanagari at 1.6x until the skeleton is
      // squeezed out of the viewport, leaving a screen that reads as broken
      // rather than busy.
      await pumpLocalized(
        tester,
        sessionsScreen(),
        locale: const Locale('ne'),
        size: const Size(320, 640),
        textScale: 1.6,
        overrides: pendingSessions(),
        theme: AppTheme.light,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(PatientSessionsScreen),
        matchesGoldenFile('goldens/sessions_loading_320_ne_1_6x.png'),
      );
    });
  });
}
