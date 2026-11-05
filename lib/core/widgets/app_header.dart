import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../l10n/locale_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// The app's top bar: logo and wordmark, who is signed in, language,
/// search and notifications.
///
/// Every screen used to roll its own — a green greeting block on the two
/// dashboards, a `BackHeader` or a `PageHeader` on sub-pages, ad-hoc `Row`s
/// elsewhere — so the language toggle only existed on two screens and the
/// wordmark drifted between three type sizes.
///
/// ## Where it is mounted
///
/// Once, in `TabShell` (`lib/core/router/app_router.dart`), as the shell
/// Scaffold's `appBar` — the same place and for the same reason the bottom
/// bar is mounted there. Every route inside either role's shell therefore
/// gets the identical bar, and no screen can drift by forgetting it or by
/// building its own. Mounting it as an `appBar` also makes `Scaffold` strip
/// the top padding from the body, so a screen that wraps itself in a
/// `SafeArea` — most of them do — no longer reserves the status bar twice.
///
/// Routes *above* the shell (the booking funnel, the clinic flow, the shop,
/// the unauthenticated screens) deliberately carry no bottom bar and no
/// header: they own the whole viewport and pin their own chrome.
///
/// ## Relationship to `PageHeader`
///
/// [AppHeader] sits *above* `PageHeader`; it does not absorb or wrap it.
/// `PageHeader` is an in-page title bar owning no global state. [AppHeader]
/// is app chrome: identity plus controls ([LanguageToggle], search,
/// notifications) that must be reachable from anywhere and that read
/// providers. A sub-page that needs `← Title` puts a `PageHeader` at the top
/// of its own content, under the chrome. [title] and [leading] remain for a
/// surface that has no shell above it — a full-screen funnel page — and are
/// exercised by the tests.
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.leading,
    this.title,
    this.onSearch,
    this.onNotifications,
    this.showSearch = true,
    this.showNotifications = true,
  });

  /// Usually an [AppHeaderBackButton]. Sits before the title/identity block.
  final Widget? leading;

  /// When set, replaces the logo-and-name block. Already-localised text —
  /// the header does not translate it, the caller does.
  final String? title;

  /// Overrides where the magnifier goes. Defaults to the role's discovery
  /// screen, so most callers can leave it alone.
  final VoidCallback? onSearch;

  /// Overrides where the bell goes. Defaults to the role's notifications.
  final VoidCallback? onNotifications;

  /// Set false on a screen that *is* the search screen.
  final bool showSearch;

  /// Set false on a screen that *is* the notifications screen.
  final bool showNotifications;

  /// Height of the bar itself, excluding the status-bar inset it also draws.
  static const double barHeight = 60;

  /// The logo-and-name line. Named so tests and the later integration pass
  /// can address it without matching on the user's name.
  static const Key identityKey = Key('app_header.identity');

  /// The [title] line, when one is given.
  static const Key titleKey = Key('app_header.title');

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // viewPadding, not SafeArea or MediaQuery.padding. SafeArea reads
    // `padding`, which any ancestor — a Scaffold, an enclosing SafeArea, a
    // route transition — may already have consumed, in which case it resolves
    // to zero and the wordmark ends up under the notch. `viewPadding` reports
    // what the status bar actually occupies no matter who consumed it.
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final text = AppTypography.textTheme;

    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        color: AppColors.card,
        // A hairline so the bar reads as chrome over scrolling content.
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      // This header now owns the top inset, so nothing inside it should pad
      // for the status bar a second time.
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: title != null
                      ? Text(
                          title!,
                          key: titleKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge,
                        )
                      : const _Identity(),
                ),
                const SizedBox(width: AppSpacing.sm),
                const LanguageToggle(),

                if (showNotifications) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    label: context.l10n.navNotifications,
                    showDot: _hasUnreadNotifications(ref),
                    onPressed:
                        onNotifications ??
                        () => _defaultNotifications(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether to draw the red dot on the bell.
  ///
  /// TODO(notifications): wire this to the real unread signal, for example
  /// `(ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0) > 0`.
  /// Until then the dot never shows, rather than showing for everyone.
  static bool _hasUnreadNotifications(WidgetRef ref) => false;

  /// Where the magnifier goes when a caller does not say.
  ///
  /// A therapist searches their patient list; everyone else searches for a
  /// therapist. The role split is the guard: `/patient/find` has no therapist
  /// equivalent, and the router's redirect bounces a therapist off
  /// `/patient/*` — a header that is on every screen of both shells must not
  /// hand a therapist a route that throws them back to their dashboard.
  ///
  /// `push`, not `go`. An imperative push stacks on the *current* branch's
  /// navigator whichever branch declares the route, so a control visible from
  /// every tab opens Find inside the tab the user is already in: that tab
  /// stays lit, its scroll survives, and Back returns them exactly where they
  /// were. `go` would yank them to the Home tab and replace its stack.
  ///
  /// Already being on the destination is a no-op rather than a second copy
  /// of it: the button is chrome, so it is present on the search screen too,
  /// and tapping it there should not grow the stack.
  ///
  /// A missing router is a no-op rather than a crash — the header is also
  /// pumped on its own in tests and in previews.
  /// 
  /// 
  // static void _defaultSearch(BuildContext context, WidgetRef ref) {
  //   final router = GoRouter.maybeOf(context);
  //   if (router == null) return;
  //   final user = ref.read(currentUserProvider);
  //   final destination = user?.isTherapist ?? false
  //       ? '/therapist/patients'
  //       : '/patient/find';
  //   if (router.state.uri.path == destination) return;
  //   router.push(destination);
  // }

  /// Where the bell goes when a caller does not say.
  ///
  /// A patient has Notifications as a tab of its own, so `go` lights that
  /// tab. A therapist's copy lives inside the Account branch, so it is
  /// pushed. Already being there is a no-op.
  static void _defaultNotifications(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final therapist = ref.read(currentUserProvider)?.isTherapist ?? false;
    final destination = therapist
        ? '/therapist/notifications'
        : '/patient/notifications';
    if (router.state.uri.path == destination) return;
    therapist ? router.go(destination) : router.go(destination);
  }
}

/// Logo mark, wordmark and, when there is one, the signed-in user's name
/// under it.
///
/// Signed out, mid-restore, or a user whose name came back blank all render
/// the logo and wordmark alone. No spinner: the header is chrome, and a bar
/// that flickers a loader on every cold start reads as breakage. No
/// placeholder name either — an empty space is honest, `null` is not.
class _Identity extends ConsumerWidget {
  const _Identity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppTypography.textTheme;
    return Align(
      alignment: AlignmentGeometry.centerLeft,
      child: Column(
        key: AppHeader.identityKey,
        children: [
          SvgPicture.asset('assets/images/sahayatri-logo.svg', height: 38),
          Text(
            'Physioghar',
            style: text.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.pine,
              fontSize: 12
            ),
          ),
        ],
      ),
    );
  }
}

/// A round header button with an optional red unread dot.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.mist,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 25, color: AppColors.ink),
                ),
                if (showDot)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        // A ring in the bar's colour so the dot stays crisp
                        // against the button behind it.
                        border: Border.all(color: AppColors.card, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What one segment of the toggle reads, and what a screen reader calls it.
///
/// Driven off the locale rather than a parallel enum: `localeProvider` is the
/// single source of truth for the language, and a second type mirroring it was
/// one store too many. Adding a language means a case here *and* turning the
/// pill into a menu — see docs/localization.md.
String _segmentLabel(Locale locale, AppLocalizations l10n) =>
    locale.languageCode == 'ne' ? l10n.languageNepali : l10n.languageEnglish;

String _segmentA11yLabel(Locale locale, AppLocalizations l10n) =>
    locale.languageCode == 'ne'
    ? l10n.languageNepaliA11y
    : l10n.languageEnglishA11y;

/// The two-segment `EN | नेपाली` pill, with a green thumb that slides to the
/// active language.
///
/// Both labels stay visible. The toggle this replaced showed only the
/// language you were *not* in, which reads as a label rather than a control,
/// and a Nepali reader had to parse English to find Nepali.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  /// Every segment is the same fixed width so the thumb can slide between
  /// them by alignment alone.
  static const double _segmentWidth = 46;
  static const double _segmentHeight = 30;
  static const double _pad = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    final count = supportedLocales.length;
    final index = supportedLocales.toList().indexWhere(
      (l) => l.languageCode == current.languageCode,
    );
    // -1 for the first segment, +1 for the last.
    final alignX = (count > 1 && index >= 0)
        ? -1 + 2 * index / (count - 1)
        : 0.0;

    return Container(
      width: _segmentWidth * count + _pad * 2,
      height: _segmentHeight + _pad * 2,
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Stack(
        children: [
          // The sliding thumb.
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment(alignX, 0),
            child: Container(
              width: _segmentWidth,
              height: _segmentHeight,
              decoration: BoxDecoration(
                color: AppColors.pine,
                borderRadius: BorderRadius.circular(AppRadii.full),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pine.withAlpha(60),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // The labels on top, each one tappable.
          Row(
            children: [
              for (final locale in supportedLocales)
                Semantics(
                  button: true,
                  selected: locale.languageCode == current.languageCode,
                  label: _segmentA11yLabel(locale, l10n),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(localeProvider.notifier).set(locale),
                    child: SizedBox(
                      width: _segmentWidth,
                      height: _segmentHeight,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: text.titleSmall!.copyWith(
                            fontSize: 12,
                            letterSpacing: 0,
                            color: locale.languageCode == current.languageCode
                                ? Colors.white
                                : AppColors.inkMid,
                          ),
                          child: Text(
                            _segmentLabel(locale, l10n),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Back arrow for [AppHeader.leading].
///
/// Same 36dp mist circle [PageHeader] draws, so a screen that swaps one
/// header for the other does not visibly move its back button. Pops by
/// default; pass [onPressed] where "back" is not "pop".
class AppHeaderBackButton extends StatelessWidget {
  const AppHeaderBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // Read through Localizations rather than `MaterialLocalizations.of`,
      // which throws when the delegates are absent — the header has to
      // survive being pumped on its own.
      label:
          Localizations.of<MaterialLocalizations>(
            context,
            MaterialLocalizations,
          )?.backButtonTooltip ??
          context.l10n.actionBack,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed ?? () => context.pop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.mist,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.arrow_back, size: 18, color: AppColors.ink),
        ),
      ),
    );
  }
}
