import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/l10n/locale_provider.dart';
import 'package:sahayatri_care_connect/core/router/app_router.dart';
import 'package:sahayatri_care_connect/core/storage/preferences_storage.dart';

/// The four patient tab roots, in bottom-bar order.
///
/// Find is not among them: it lost its tab to Sessions and is now a page in
/// the Home branch, reached from the hero card and the header search icon.
const patientTabRoutes = [
  '/patient/home',
  '/patient/sessions',
  '/patient/recovery',
  '/patient/account',
];

/// A router shaped exactly like the app's patient shell — four
/// [StatefulShellBranch]es under the real [PatientShell] — but with stand-in
/// screens, so a test can pin navigation behaviour without booting providers,
/// Dio or mock data.
///
/// [screens] supplies one widget per tab, in the same order.
/// [detailRoutes] optionally adds extra routes inside a branch, keyed by the
/// branch index, to exercise pushing within a tab.
/// [rootRoutes] adds routes *beside* the shell rather than inside it — the
/// shape `/shop`, `/clinics` and the booking funnel really have. They are the
/// only way to exercise the difference the shell makes: a route declared here
/// covers the bottom bar when it is opened, and one in [detailRoutes] does not.
GoRouter patientShellHarnessRouter({
  required List<Widget> screens,
  Map<int, Map<String, Widget>> detailRoutes = const {},
  Map<String, Widget> rootRoutes = const {},
  String initialLocation = '/patient/home',
}) {
  assert(screens.length == patientTabRoutes.length);

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            PatientShell(navigationShell: navigationShell),
        branches: [
          for (var i = 0; i < patientTabRoutes.length; i++)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: patientTabRoutes[i],
                  builder: (_, _) => screens[i],
                ),
                if (i == 0)
                  GoRoute(
                    path: '/patient/notifications',
                    builder: (_, _) =>
                        detailRoutes[0]?['/patient/notifications'] ??
                        screens[0],
                  ),
                for (final entry in (detailRoutes[i] ?? const {}).entries)
                  if (!(i == 0 && entry.key == '/patient/notifications'))
                  GoRoute(path: entry.key, builder: (_, _) => entry.value),
              ],
            ),
        ],
      ),
      for (final entry in rootRoutes.entries)
        GoRoute(path: entry.key, builder: (_, _) => entry.value),
    ],
  );
}

/// The four therapist tab roots, in bottom-bar order.
const therapistTabRoutes = [
  '/therapist/home',
  '/therapist/schedule',
  '/therapist/requests',
  '/therapist/account',
];

/// The therapist twin of [patientShellHarnessRouter], for the things the two
/// shells are supposed to share — the header above all.
GoRouter therapistShellHarnessRouter({
  required List<Widget> screens,
  Map<int, Map<String, Widget>> detailRoutes = const {},
  String initialLocation = '/therapist/home',
}) {
  assert(screens.length == therapistTabRoutes.length);

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            TherapistShell(navigationShell: navigationShell),
        branches: [
          for (var i = 0; i < therapistTabRoutes.length; i++)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: therapistTabRoutes[i],
                  builder: (_, _) => screens[i],
                ),
                for (final entry in (detailRoutes[i] ?? const {}).entries)
                  GoRoute(path: entry.key, builder: (_, _) => entry.value),
              ],
            ),
        ],
      ),
    ],
  );
}

/// The app around [router], with what the shell needs to build.
///
/// `TabShell` mounts `AppHeader`, which reads `currentUserProvider` and the
/// locale, so a bare `MaterialApp.router` no longer boots the shell: there
/// has to be a `ProviderScope`, and preferences have to be in memory rather
/// than reaching for `shared_preferences`. The real localisation delegates
/// are installed too, so a test can assert what the bar and the header
/// actually render in each language.
///
/// [mediaQuery] wraps the app rather than the router, which is where the
/// inset tests need it — above `MaterialApp` so the shell sees it.
Widget shellHarnessApp(
  GoRouter router, {
  MediaQueryData? mediaQuery,
  List<Override> overrides = const [],
}) {
  // `locale:` is driven by `localeProvider`, exactly as `SahayatriApp` drives
  // it. Without that, tapping the header's language toggle would move the
  // provider and leave the delegates in English, and a test could not tell a
  // localised label from a hardcoded one.
  final Widget app = Consumer(
    builder: (_, ref, _) => MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(localeProvider),
    ),
  );

  return ProviderScope(
    overrides: [
      preferencesStorageProvider.overrideWithValue(
        InMemoryPreferencesStorage(),
      ),
      ...overrides,
    ],
    child: mediaQuery == null
        ? app
        : MediaQuery(data: mediaQuery, child: app),
  );
}

/// A long list that can actually be scrolled, tagged so a test can find it.
class ScrollableProbe extends StatelessWidget {
  const ScrollableProbe({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          key: PageStorageKey<String>(name),
          itemCount: 120,
          itemExtent: 40,
          itemBuilder: (_, i) => Text('$name-$i'),
        ),
      ),
    );
  }
}
