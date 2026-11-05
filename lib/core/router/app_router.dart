import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/my_reviews_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/select_slot_screen.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/onboarding_page_first.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/onboarding_page_fourth.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/onboarding_page_second.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/onboarding_page_third.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/patient_intro_screen.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/therapist_intro_screen.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/screens/welcome_screen.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_pending_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/patient/presentation/screens/patient_home_screen.dart';
import '../../features/patient/presentation/screens/patient_find_screen.dart';
import '../../features/patient/presentation/screens/therapist_profile_screen.dart';
import '../../features/patient/presentation/screens/booking_screen.dart';
import '../../features/patient/presentation/screens/booking_success_screen.dart';
import '../../features/patient/presentation/screens/gateway_checkout_screen.dart';
import '../../features/patient/presentation/screens/patient_sessions_screen.dart';
import '../../features/patient/presentation/screens/patient_account_screen.dart';
import '../../features/patient/presentation/screens/saved_addresses_screen.dart';
import '../../features/about/presentation/screens/about_us_screen.dart';
import '../../features/about/presentation/screens/privacy_policy_screen.dart';
import '../../features/about/presentation/screens/terms_screen.dart';
import '../../features/patient/presentation/screens/patient_contact_screen.dart';
import '../../features/patient/presentation/screens/patient_help_screen.dart';
import '../../features/patient/presentation/screens/report_therapist_screen.dart';
import '../../features/patient/presentation/screens/payment_methods_screen.dart';
import '../../features/patient/presentation/screens/recovery_screen.dart';
import '../../features/patient/presentation/screens/reports_screen.dart';
import '../../features/therapist/presentation/screens/session_in_progress.dart';
import '../../features/therapist/presentation/screens/therapist_home_screen.dart';
import '../../features/therapist/presentation/screens/therapist_schedule_screen.dart';
import '../../features/therapist/presentation/screens/therapist_requests_screen.dart';
import '../../features/therapist/presentation/screens/therapist_patients_screen.dart';
import '../../features/therapist/presentation/screens/therapist_earnings_screen.dart';
import '../../features/therapist/presentation/screens/therapist_account_screen.dart';
import '../../features/therapist/presentation/screens/therapist_availability_screen.dart';
import '../../features/therapist/presentation/screens/therapist_performance_screen.dart';
import '../../features/therapist/presentation/screens/therapist_reviews_screen.dart';
import '../../features/therapist/presentation/screens/therapist_bio_screen.dart';
import '../../features/therapist/presentation/screens/therapist_certifications_screen.dart';
import '../../features/therapist/presentation/screens/therapist_payout_methods_screen.dart';
import '../../features/therapist/presentation/screens/therapist_service_areas_screen.dart';
import '../../features/therapist/presentation/screens/therapist_edit_profile_screen.dart';
import '../../features/therapist/presentation/screens/rate_increase_screen.dart';
import '../../features/therapist/presentation/screens/report_patient_screen.dart';
import '../../features/therapist/presentation/screens/day_off_screen.dart';
import '../../features/shop/presentation/screens/shop_screen.dart';
import '../../features/shop/presentation/screens/cart_screen.dart';
import '../../features/shop/presentation/screens/order_success_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/patient/domain/entities/booking_outcome.dart';
import '../../features/patient/domain/entities/session.dart';
import '../../features/clinics/presentation/screens/clinic_list_screen.dart';
import '../../features/clinics/presentation/screens/clinic_profile_screen.dart';
import '../../features/clinics/presentation/screens/clinic_booking_screen.dart';
import '../../features/clinics/presentation/screens/clinic_booked_screen.dart';
import '../../features/patient/presentation/screens/referral_screen.dart';
import '../../features/therapist/presentation/screens/therapist_referral_screen.dart';
import '../../features/rewards/presentation/screens/my_points_screen.dart';
import '../../features/coverage/presentation/screens/coverage_map_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/patient/presentation/screens/edit_profile_screen.dart';
import '../../features/packages/presentation/screens/my_packages_screen.dart';
import '../../features/packages/presentation/screens/therapy_packages_screen.dart';
import '../widgets/app_header.dart';
import '../widgets/nav_bars.dart';

/// Auth state notifier that go_router listens to for redirects.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._ref) {
    _ref.listen(authProvider, (_, user) {
      final authenticated = user != null;
      final role = user?.role ?? '';
      if (authenticated != _isAuthenticated || role != _role) {
        _isAuthenticated = authenticated;
        _role = role;
        notifyListeners();
      }
    });
  }

  final Ref _ref;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  String _role = '';
  String get role => _role;
}

final authStateNotifierProvider = ChangeNotifierProvider<AuthStateNotifier>((
  ref,
) {
  return AuthStateNotifier(ref);
});

/// Cached GoRouter instance. Creating the router on every widget build would
/// recreate it (and the shared navigator GlobalKeys) each time the app
/// rebuilds, causing "Multiple widgets used the same GlobalKey" errors.
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where a new route goes
/// ----------------------
///
/// Navigation is two `StatefulShellRoute.indexedStack`es — one per role —
/// each with one [StatefulShellBranch] per bottom-bar tab, **in tab order**.
/// A branch keeps its own `Navigator`, so switching tabs is an `IndexedStack`
/// swap: no page transition, no rebuild, scroll position intact.
///
/// * **Inside a branch** — anything you reach *from* a tab and expect to come
///   back to: details, lists, settings. It keeps the bottom bar and the
///   [AppHeader]. Back pops within that tab. Put it in the branch of the tab
///   it is reached from. This is the default; prefer it.
/// * **Above the shell (root route)** — only self-contained funnels that own
///   the whole viewport and carry their own pinned chrome: the booking flow,
///   the shop (`/shop`, `/cart`, `/order-success`), clinic booking
///   (`/clinics/:id/book`, `/clinics/booked`), and the unauthenticated
///   screens. Browsing a clinic list or profile stays in the Home branch so
///   the header does not disappear. Committing to a booking does not.
///
/// Note that an imperative `context.push` always stacks on the *current*
/// branch's navigator whichever branch declares the route, so branch
/// membership decides where a `context.go` lands and which tab lights up —
/// not whether a pushed page renders.
///
/// A screen that is no longer a tab in its own right still needs a branch, and
/// the rule above already answers which: the branch of the tab it is reached
/// from. Find (`/patient/find`, plus the therapist profile and coverage map
/// behind it) lives in the Home branch, because the hero card on Home is the
/// entry point that owns it. The header's search icon is on every tab and
/// pushes, so it keeps the user in whichever tab they were already in.
///
/// Screens shared by both roles (notifications, help, contact, the About and
/// legal pages) are declared once per shell under a role prefix, because a
/// branch belongs to exactly one role's bottom bar and the auth redirect
/// below bounces a therapist off `/patient/*`. The unprefixed paths
/// (`/notifications`, `/help`, `/contact`, `/about...`) survive as aliases
/// that redirect to the signed-in role's copy, so call sites stay role-blind.
GoRouter createRouter(Ref ref) {
  final authNotifier = ref.read(authStateNotifierProvider);

  /// Sends a role-blind path such as `/about/terms` to `/patient/about/terms`
  /// or `/therapist/about/terms`.
  String roleAlias(GoRouterState state) {
    final prefix = authNotifier.role == 'THERAPIST' ? '/therapist' : '/patient';
    final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
    return '$prefix${state.uri.path}$query';
  }

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.isAuthenticated;
      final role = authNotifier.role;
      final location = state.matchedLocation;
      // Routes reachable without a session. Password recovery obviously
      // needs to be, and therapist signup does not issue a token — the
      // account is PENDING until an admin approves it — so the
      // "application received" screen has no session either. Both used to
      // fall through to the redirect below and bounce to /splash.
      final isAuthRoute =
          location == '/login' ||
          location == '/signup' ||
          location == '/splash' ||
          location == '/forgot-password' ||
          location == '/welcome' ||
          location == '/onboardingFirst' ||
          location == '/onboardingSecond' ||
          location == '/onboardingThird' ||
          location == '/onboardingFourth' ||
          location == '/role-selection' ||
          location == '/patient-intro' ||
          location == '/therapist-intro' ||
          location == '/verify-pending';

      if (!isLoggedIn && !isAuthRoute) return '/splash';
      if (isLoggedIn && isAuthRoute) {
        return role == 'THERAPIST' ? '/therapist/home' : '/patient/home';
      }
      if (isLoggedIn &&
          role == 'THERAPIST' &&
          location.startsWith('/patient')) {
        return '/therapist/home';
      }
      // The mirror of the rule above. It matters now that both shells carry a
      // copy of the shared screens: without it a patient could land on
      // `/therapist/about` and get the therapist bottom bar.
      if (isLoggedIn &&
          role != 'THERAPIST' &&
          location.startsWith('/therapist')) {
        return '/patient/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // `?role=therapist` opens the therapist half. The landing screen's
      // "I'm a physiotherapist" button is the only caller that sets it; a
      // bare /signup still opens the patient form.

      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),

      GoRoute(
        path: '/onboardingFirst',
        builder: (_, _) => const OnboardingPageFirst(),
      ),

      GoRoute(
        path: '/onboardingSecond',
        builder: (_, _) => const OnboardingPageSecond(),
      ),

      GoRoute(
        path: '/onboardingThird',
        builder: (_, _) => const OnboardingPageThird(),
      ),
      GoRoute(
        path: '/onboardingFourth',
        builder: (_, _) => const OnboardingPageFourth(),
      ),

      GoRoute(
        path: '/role-selection',
        builder: (_, _) => const RoleSelectionScreen(),
      ),

      GoRoute(
        path: '/patient-intro',
        builder: (_, _) => const PatientIntroScreen(),
      ),

      GoRoute(
        path: '/therapist-intro',
        builder: (_, _) => const TherapistIntroScreen(),
      ),

      GoRoute(
        path: '/signup',
        builder: (_, s) => SignupScreen(
          startAsTherapist: s.uri.queryParameters['role'] == 'therapist',
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-pending',
        builder: (_, _) => const VerifyPendingScreen(),
      ),

      // Role-blind aliases. Every caller can keep saying `/notifications`.
      GoRoute(path: '/notifications', redirect: (_, s) => roleAlias(s)),
      GoRoute(path: '/help', redirect: (_, s) => roleAlias(s)),
      GoRoute(path: '/contact', redirect: (_, s) => roleAlias(s)),
      GoRoute(
        path: '/about',
        redirect: (_, s) => roleAlias(s),
        routes: [
          GoRoute(path: 'privacy', redirect: (_, s) => roleAlias(s)),
          GoRoute(path: 'terms', redirect: (_, s) => roleAlias(s)),
        ],
      ),

      // Patient tabs: Home, Sessions, Recovery, Account — same order as
      // `PatientNav`'s tabs, because the bar drives branches by index. The
      // centre `+` is not a tab and has no branch; it opens the quick-action
      // sheet over whichever tab you are on.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            PatientShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/home',
                builder: (_, _) => const PatientHomeScreen(),
              ),
              // Find is reached from the hero card on Home and from the
              // header's search icon, not from a tab of its own, so it and
              // the two screens behind it are pages in the Home tab.
              GoRoute(
                path: '/patient/find',
                builder: (_, state) => PatientFindScreen(
                  autofocusSearch:
                      state.uri.queryParameters['focus'] == 'search',
                ),
              ),
              GoRoute(
                path: '/patient/therapist/:id',
                builder: (_, state) => TherapistProfileScreen(
                  therapistId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: '/patient/coverage',
                builder: (_, _) => const CoverageMapScreen(),
              ),
              GoRoute(
                path: '/clinics',
                builder: (_, _) => const ClinicListScreen(),
              ),
              GoRoute(
                path: '/clinics/:id',
                builder: (_, state) =>
                    ClinicProfileScreen(clinicId: state.pathParameters['id']!),
              ),
              // Notifications are no longer a tab, but remain reachable from
              // the header and role-aware `/notifications` alias.
              GoRoute(
                path: '/patient/notifications',
                builder: (_, _) => const NotificationsScreen(),
              ),
              // Packages are opened from the centre quick-action sheet, not
              // from a bottom-navigation tab. Keep them in Home's branch so
              // the bar remains visible and Home stays selected.
              GoRoute(
                path: '/patient/packages',
                builder: (context, _) => TherapyPackagesScreen(
                  onBack: () => _backTo(context, '/patient/home'),
                  onViewMyPackages: () =>
                      context.push('/patient/packages/mine'),
                ),
                routes: [
                  GoRoute(
                    path: 'mine',
                    builder: (context, _) => MyPackagesScreen(
                      onBack: () => _backTo(context, '/patient/home'),
                      onBrowsePackages: () => context.go('/patient/packages'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/sessions',
                builder: (_, _) => const PatientSessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/recovery',
                builder: (_, _) => const RecoveryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/account',
                builder: (_, _) => const PatientAccountScreen(),
              ),
              GoRoute(
                path: '/patient/reviews',
                builder: (_, _) => const MyReviewsScreen(),
              ),
              GoRoute(
                path: '/patient/reports',
                builder: (_, _) => const ReportsScreen(),
              ),
              GoRoute(
                path: '/patient/edit-profile',
                builder: (_, _) => const EditProfileScreen(),
              ),
              GoRoute(
                path: '/patient/addresses',
                builder: (_, _) => const SavedAddressesScreen(),
              ),
              GoRoute(
                path: '/patient/payment-methods',
                builder: (_, _) => const PaymentMethodsScreen(),
              ),
              GoRoute(
                path: '/patient/help',
                builder: (_, _) => const PatientHelpScreen(),
              ),
              GoRoute(
                path: '/patient/contact',
                builder: (_, _) => const PatientContactScreen(),
              ),
              GoRoute(
                path: '/patient/report-therapist',
                builder: (_, _) => const ReportTherapistScreen(),
              ),
              GoRoute(
                path: '/patient/referral',
                builder: (_, _) => const ReferralScreen(),
              ),
              GoRoute(
                path: '/patient/rewards',
                builder: (_, _) => const MyPointsScreen(),
              ),
              GoRoute(
                path: '/patient/about',
                builder: (_, _) => const AboutUsScreen(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    builder: (_, _) => const PrivacyPolicyScreen(),
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (_, _) => const TermsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // The booking funnel. Browsing keeps the tabs — a therapist profile is
      // just another page in Find — but committing does not: this screen
      // carries its own pinned Confirm sheet, and stacking the tab bar under
      // it both crowds the CTA and invites a tab away mid-booking.
      //
      // `/patient/booking-success` is reached with `pushReplacement`, so Back
      // from the receipt returns to the shell rather than leaving the app.
      GoRoute(
        path: '/patient/booking/:therapistId',
        builder: (_, state) => BookingScreen(
          therapistId: state.pathParameters['therapistId']!,
          date: state.uri.queryParameters['date'] ?? '',
          time: state.uri.queryParameters['time'] ?? '',
        ),
      ),

      GoRoute(
        path: '/patient/select-slot/:therapistId',
        builder: (context, state) =>
            SelectSlotScreen(therapistId: state.pathParameters['therapistId']!),
      ),

      GoRoute(
        path: '/therapist/session/:id',
        builder: (_, state) => SessionInProgressScreen(
          sessionId: state.pathParameters['id']!,
          // The home screen passes the moment the start call succeeded, so
          // the clock begins at 00:00. Null (reopened later) = count from now.
          startedAt: state.extra is DateTime ? state.extra as DateTime : null,
        ),
      ),

      GoRoute(
        path: '/patient/booking-success',
        builder: (_, state) => BookingSuccessScreen(
          session: state.extra is Session ? state.extra as Session : null,
        ),
      ),
      // Reached only with a BookingOutcome in `extra`, by pushReplacement from
      // the booking screen. There is nothing sensible to show without one --
      // the payment id it has to confirm lives in that object -- so a direct
      // visit is sent to the sessions list rather than rendering an empty
      // checkout.
      GoRoute(
        path: '/patient/checkout',
        redirect: (_, state) =>
            state.extra is BookingOutcome ? null : '/patient/sessions',
        builder: (_, state) =>
            GatewayCheckoutScreen(outcome: state.extra as BookingOutcome),
      ),

      // Clinic booking only. The list and profile live in the Home branch.
      // `/clinics/booked` stays a literal path so it is not captured as an id.
      GoRoute(
        path: '/clinics/booked',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ClinicBookedScreen(
            clinicName: q['clinic'],
            address: q['address'],
            hours: q['hours'],
            date: q['date'],
            time: q['time'],
          );
        },
      ),
      GoRoute(
        path: '/clinics/:id/book',
        builder: (_, state) =>
            ClinicBookingScreen(clinicId: state.pathParameters['id']!),
      ),

      // Shop routes (outside the shell because of unique nav)
      GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(
        path: '/order-success',
        builder: (_, _) => const OrderSuccessScreen(),
      ),

      // Therapist tabs: Home, Schedule, Requests, Account — same order as
      // `TherapistNav`'s tabs.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            TherapistShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/therapist/home',
                builder: (_, _) => const TherapistHomeScreen(),
              ),
              GoRoute(
                path: '/therapist/availability',
                builder: (_, _) => const TherapistAvailabilityScreen(),
              ),
              GoRoute(
                path: '/therapist/performance',
                builder: (_, _) => const TherapistPerformanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/therapist/schedule',
                builder: (_, _) => const TherapistScheduleScreen(),
              ),
              GoRoute(
                path: '/therapist/day-off',
                builder: (_, _) => const DayOffScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/therapist/requests',
                builder: (_, _) => const TherapistRequestsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/therapist/account',
                builder: (_, _) => const TherapistAccountScreen(),
              ),
              GoRoute(
                path: '/therapist/patients',
                builder: (_, _) => const TherapistPatientsScreen(),
              ),
              GoRoute(
                path: '/therapist/earnings',
                builder: (_, _) => const TherapistEarningsScreen(),
              ),
              GoRoute(
                path: '/therapist/reviews',
                builder: (_, _) => const TherapistReviewsScreen(),
              ),
              GoRoute(
                path: '/therapist/referral',
                builder: (_, _) => const TherapistReferralScreen(),
              ),
              GoRoute(
                path: '/therapist/rewards',
                builder: (_, _) => const MyPointsScreen(),
              ),
              GoRoute(
                path: '/therapist/edit-profile',
                builder: (_, _) => const TherapistEditProfileScreen(),
              ),
              GoRoute(
                path: '/therapist/bio',
                builder: (_, _) => const TherapistBioScreen(),
              ),
              GoRoute(
                path: '/therapist/certifications',
                builder: (_, _) => const TherapistCertificationsScreen(),
              ),
              GoRoute(
                path: '/therapist/payout-methods',
                builder: (_, _) => const TherapistPayoutMethodsScreen(),
              ),
              // Reached from the `Request a rate increase` row in the
              // Professional group, so the branch rule above puts it here —
              // and a notification tapped in the Notifications tab pushes it
              // there instead, which is what `push` does regardless of which
              // branch declares the route.
              GoRoute(
                path: '/therapist/rate-increase',
                builder: (_, _) => const RateIncreaseScreen(),
              ),
              GoRoute(
                path: '/therapist/service-areas',
                builder: (_, _) => const TherapistServiceAreasScreen(),
              ),
              GoRoute(
                path: '/therapist/notifications',
                builder: (_, _) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/therapist/help',
                builder: (_, _) => const PatientHelpScreen(),
              ),
              GoRoute(
                path: '/therapist/contact',
                builder: (_, _) => const PatientContactScreen(),
              ),
              // The therapist half of `POST /admin/complaints`. Declared in
              // the same place in the same branch as the patient's
              // `/patient/report-therapist`, and reached the same way: the
              // last row of the Account screen's Support group.
              GoRoute(
                path: '/therapist/report-patient',
                builder: (_, _) => const ReportPatientScreen(),
              ),
              GoRoute(
                path: '/therapist/about',
                builder: (_, _) => const AboutUsScreen(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    builder: (_, _) => const PrivacyPolicyScreen(),
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (_, _) => const TermsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Back for a screen that can be arrived at two ways.
///
/// The packages screens are pushed from Home (Back should return there) and
/// `go`-ed to from the centre-action sheet, which leaves the branch with no
/// history at all — `pop()` on that stack throws. Falling back to [fallback]
/// keeps one `onBack` correct for both.
void _backTo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Patient shell: the four patient tabs under one bottom bar.
class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return TabShell(
      navigationShell: navigationShell,
      firstTabLocation: '/patient/home',
      navBuilder: (index, onSelect) =>
          PatientNav(currentIndex: index, onSelect: onSelect),
    );
  }
}

/// Therapist shell: the four therapist tabs under one bottom bar.
class TherapistShell extends StatelessWidget {
  const TherapistShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return TabShell(
      navigationShell: navigationShell,
      firstTabLocation: '/therapist/home',
      resetTherapistNotificationsOnTabChange: true,
      navBuilder: (index, onSelect) =>
          TherapistNav(currentIndex: index, onSelect: onSelect),
    );
  }
}

/// The one place the top and bottom bars are mounted.
///
/// Before this, all ten tab screens carried their own `bottomNavigationBar:`.
/// Ten copies drifted — different body padding, one screen's bar sitting
/// higher than the next's — and `/notifications`, a tab in its own right,
/// had no bar at all. Mounting it here means every route inside a branch gets
/// the same bar in the same place, for free.
///
/// [AppHeader] is here for exactly the same reason, and the symmetry is the
/// argument: the top bar is app chrome, not page content, so it belongs to
/// the shell and not to the forty-odd screens inside it. Every route in a
/// branch — tab roots and the pages pushed on top of them alike — now shows
/// the identical `Sahayatri {name} | EN/नेपाली | search` bar, and a new
/// screen gets it without doing anything.
///
/// It hangs off `appBar:` rather than sitting in a `Column` above the body
/// on purpose: `Scaffold` strips the top padding from the body of a Scaffold
/// that has an app bar, so the `SafeArea` nearly every screen wraps itself in
/// stops reserving the status bar a second time under a header that already
/// consumed it. A `Column` would have left every one of those screens with a
/// double inset to fix by hand.
class TabShell extends StatefulWidget {
  const TabShell({
    super.key,
    required this.navigationShell,
    required this.firstTabLocation,
    required this.navBuilder,
    this.resetTherapistNotificationsOnTabChange = false,
  });

  final StatefulNavigationShell navigationShell;

  /// Where the Back ladder bottoms out — the first tab's root.
  final String firstTabLocation;

  /// The therapist notifications page shares the Account branch, but is
  /// opened from the header rather than being an Account sub-page. Once the
  /// user leaves it for another tab, returning to Account should show Account
  /// instead of restoring Notifications.
  final bool resetTherapistNotificationsOnTabChange;

  final Widget Function(int currentIndex, ValueChanged<int> onSelect)
  navBuilder;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  bool _resetAccountBranchOnReturn = false;

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final index = navigationShell.currentIndex;
    final location = GoRouterState.of(context).uri.path;
    final atFirstTabRoot = index == 0 && location == widget.firstTabLocation;

    // Back ladder, rung by rung. Anything stacked inside a branch is popped
    // by that branch's Navigator before this route is ever consulted, so by
    // the time we get here the user is at the root of some tab:
    //
    //   not the first tab   -> switch to the first tab (keeping its stack)
    //   first tab, off root -> reset the first tab to its root
    //   first tab root      -> canPop, so the pop bubbles and Android closes
    //                          the app, which is what Android users expect.
    //
    // No "press back again to exit": leaving now takes a deliberate press on
    // the home tab's own root, and a confirmation toast would cost a timer,
    // a messenger and a translated string to guard against nothing.
    return PopScope(
      canPop: atFirstTabRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        navigationShell.goBranch(0, initialLocation: index == 0);
      },
      child: Scaffold(
        appBar: const AppHeader(),
        body: navigationShell,
        bottomNavigationBar: widget.navBuilder(index, (i) {
          if (widget.resetTherapistNotificationsOnTabChange &&
              location == '/therapist/notifications' &&
              i != index) {
            _resetAccountBranchOnReturn = true;
          }

          // Once Notifications has been left, returning to Account should
          // land on its root rather than the notification route retained
          // in that branch's IndexedStack navigator.
          final resetNotifications =
              widget.resetTherapistNotificationsOnTabChange &&
              i == 3 &&
              i != index &&
              _resetAccountBranchOnReturn;
          if (resetNotifications) _resetAccountBranchOnReturn = false;

          // Re-tapping the current tab pops it back to its root.
          navigationShell.goBranch(
            i,
            initialLocation: i == index || resetNotifications,
          );
        }),
      ),
    );
  }
}
