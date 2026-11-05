import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/widgets/app_header.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';

import 'tab_shell_harness.dart';

/// The header used to exist and be mounted nowhere: `AppHeader` was built,
/// tested on its own, and no screen reached for it, so the app still showed
/// one hand-rolled bar per screen — a green greeting block on the two
/// dashboards, a back bar on sub-pages, nothing at all on several.
///
/// It is mounted once now, by `TabShell`, exactly where the bottom bar is
/// mounted and for the same reason. These tests pin the three things that
/// buys — it is on every route in a shell, it is on each route *once*, and
/// putting it in `appBar:` is what stops the screens' own `SafeArea`s
/// reserving the status bar a second time underneath it.
void main() {
  User signedIn({required bool therapist}) => User(
    id: 'u1',
    name: 'Aakar Sharma',
    email: 'aakar@example.com',
    role: therapist ? 'THERAPIST' : 'PATIENT',
    status: 'APPROVED',
  );

  /// A screen shaped like the real ones: a `Scaffold` whose body is a
  /// `SafeArea`. That shape is the whole reason the inset test below exists.
  Widget probe(String name) => Scaffold(
    body: SafeArea(child: SizedBox.expand(key: Key('body-$name'))),
  );

  Future<GoRouter> pumpPatient(
    WidgetTester tester, {
    String initialLocation = '/patient/home',
    Map<int, Map<String, Widget>> detailRoutes = const {},
    User? user,
    MediaQueryData? mediaQuery,
  }) async {
    final router = patientShellHarnessRouter(
      initialLocation: initialLocation,
      detailRoutes: detailRoutes,
      screens: [for (final r in patientTabRoutes) probe(r)],
    );
    await tester.pumpWidget(
      shellHarnessApp(
        router,
        mediaQuery: mediaQuery,
        overrides: [
          if (user != null) authProvider.overrideWith((_) => user),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<GoRouter> pumpTherapist(
    WidgetTester tester, {
    String initialLocation = '/therapist/home',
    Map<int, Map<String, Widget>> detailRoutes = const {},
  }) async {
    final router = therapistShellHarnessRouter(
      initialLocation: initialLocation,
      detailRoutes: detailRoutes,
      screens: [for (final r in therapistTabRoutes) probe(r)],
    );
    await tester.pumpWidget(
      shellHarnessApp(
        router,
        overrides: [authProvider.overrideWith((_) => signedIn(therapist: true))],
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('where the header is', () {
    testWidgets('on every patient tab, notifications included', (tester) async {
      for (final route in patientTabRoutes) {
        await pumpPatient(tester, initialLocation: route);
        expect(
          find.byType(AppHeader),
          findsOneWidget,
          reason: '$route should carry the shared header',
        );
      }
    });

    testWidgets('on every therapist tab too', (tester) async {
      for (final route in therapistTabRoutes) {
        await pumpTherapist(tester, initialLocation: route);
        expect(
          find.byType(AppHeader),
          findsOneWidget,
          reason: '$route should carry the shared header',
        );
      }
    });

    testWidgets('on a sub-page pushed inside a tab', (tester) async {
      // The representative case: a page reached *from* a tab, which is where
      // the old hand-rolled back bars lived.
      final router = await pumpPatient(
        tester,
        initialLocation: '/patient/account',
        detailRoutes: {
          3: {'/patient/edit-profile': const Scaffold(body: Text('edit'))},
        },
      );

      router.push('/patient/edit-profile');
      await tester.pumpAndSettle();

      expect(find.text('edit'), findsOneWidget);
      expect(find.byType(AppHeader), findsOneWidget);
    });

    testWidgets('showing the signed-in name, not just the wordmark', (
      tester,
    ) async {
      await pumpPatient(tester, user: signedIn(therapist: false));

      final identity = tester.widget<Text>(find.byKey(AppHeader.identityKey));
      expect(identity.textSpan!.toPlainText(), 'Sahayatri  Aakar Sharma');
    });

    testWidgets('once, not once per branch', (tester) async {
      // All four branches are alive inside the IndexedStack at all times. A
      // header mounted by the screens rather than the shell would show up
      // four times here — and did, in the shape of four different bars.
      await pumpPatient(tester);
      expect(find.byType(AppHeader), findsOneWidget);
    });

    testWidgets('and still once on a sub-page, so nothing stacks two', (
      tester,
    ) async {
      final router = await pumpPatient(
        tester,
        detailRoutes: {
          0: {'/patient/find': const Scaffold(body: Text('find'))},
        },
      );

      router.push('/patient/find');
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsOneWidget);
      // One language toggle and one magnifier, i.e. one set of controls —
      // the symptom a second header would show even if it were a different
      // widget class.
      expect(find.byType(LanguageToggle), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });

  group('the top inset', () {
    const inset = 48.0;

    testWidgets('is reserved once, not once by the header and once by the '
        'screen', (tester) async {
      // The header consumes the status bar itself. Hanging it off `appBar:`
      // makes Scaffold strip the top padding from the body, so the SafeArea
      // every screen wraps itself in adds nothing on top. Mounted in a
      // Column instead, this would be 48dp taller and every screen would
      // need fixing by hand.
      await pumpPatient(
        tester,
        mediaQuery: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: inset),
          padding: EdgeInsets.only(top: inset),
        ),
      );

      final header = tester.getRect(find.byType(AppHeader));
      final body = tester.getRect(find.byKey(const Key('body-/patient/home')));

      expect(header.top, 0);
      expect(header.height, inset + AppHeader.barHeight);
      expect(
        body.top,
        header.bottom,
        reason: 'the body starts where the header ends, with no second inset',
      );
    });

    testWidgets('and the wordmark still clears the status bar', (tester) async {
      await pumpPatient(
        tester,
        user: signedIn(therapist: false),
        mediaQuery: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: inset),
          padding: EdgeInsets.only(top: inset),
        ),
      );

      final wordmark = tester.getRect(find.byKey(AppHeader.identityKey));
      expect(wordmark.top, greaterThanOrEqualTo(inset));
    });
  });

  group('the search button', () {
    testWidgets('opens Find for a patient', (tester) async {
      final router = await pumpPatient(
        tester,
        user: signedIn(therapist: false),
        detailRoutes: {
          0: {'/patient/find': const Scaffold(body: Text('find screen'))},
        },
      );

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('find screen'), findsOneWidget);
      expect(router.state.uri.path, '/patient/find');
    });

    testWidgets('pushes, so the tab the user was in survives Back', (
      tester,
    ) async {
      // The header is on all four tabs, so `go` would yank whoever taps it
      // out of their tab and replace that branch's stack. `push` stacks on
      // the branch they are already in.
      final router = await pumpPatient(
        tester,
        initialLocation: '/patient/sessions',
        user: signedIn(therapist: false),
        detailRoutes: {
          1: {'/patient/find': const Scaffold(body: Text('find screen'))},
        },
      );

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(find.text('find screen'), findsOneWidget);

      final sessions = tester.widget<Icon>(find.byIcon(Icons.history_rounded));
      expect(
        sessions.color,
        AppColors.pine,
        reason: 'Sessions stays lit: the page stacked on that tab',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/patient/sessions');
    });

    testWidgets('tapping it on Find does not stack a second copy', (
      tester,
    ) async {
      final router = await pumpPatient(
        tester,
        initialLocation: '/patient/find',
        user: signedIn(therapist: false),
        detailRoutes: {
          0: {'/patient/find': const Scaffold(body: Text('find screen'))},
        },
      );

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('find screen'), findsOneWidget);
      // Back would have to be pressed twice if the tap had pushed again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/patient/home');
    });

    testWidgets('never sends a therapist to the patient Find screen', (
      tester,
    ) async {
      // `/patient/find` has no therapist equivalent and the router's redirect
      // bounces a therapist off `/patient/*` — a control on every screen of
      // both shells must not aim at it. Theirs searches their own patients.
      final router = await pumpTherapist(
        tester,
        detailRoutes: {
          3: {'/therapist/patients': const Scaffold(body: Text('patients'))},
        },
      );

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, isNot('/patient/find'));
      expect(router.state.uri.path, '/therapist/patients');
      expect(tester.takeException(), isNull);
    });
  });

  group('the tab labels', () {
    testWidgets('come from the ARB, in the language the header is set to', (
      tester,
    ) async {
      await pumpPatient(tester);

      // English first, which is also what the old hardcoded literals said —
      // so the switch below is the assertion that actually proves the ARB is
      // wired rather than the strings merely being unchanged.
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Sessions'), findsOneWidget);

      await tester.tap(find.text('नेपाली'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('गृह'), findsOneWidget);
      expect(find.bySemanticsLabel('सत्रहरू'), findsOneWidget);
      expect(find.bySemanticsLabel('सूचनाहरू'), findsOneWidget);
      expect(find.bySemanticsLabel('खाता'), findsOneWidget);
      expect(find.bySemanticsLabel('Home'), findsNothing);
    });

    testWidgets('including the therapist bar, which has its own two', (
      tester,
    ) async {
      await pumpTherapist(tester);

      await tester.tap(find.text('नेपाली'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('तालिका'), findsOneWidget);
      expect(find.bySemanticsLabel('अनुरोधहरू'), findsOneWidget);
      expect(find.bySemanticsLabel('Schedule'), findsNothing);
      expect(find.byType(TherapistNav), findsOneWidget);
    });
  });
}
