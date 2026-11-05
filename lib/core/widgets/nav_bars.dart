import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

typedef NavTab = ({IconData icon, String label});

/// Bottom padding a scrollable body should reserve so its last item clears
/// the bar. Carried over unchanged from the prototype bar this file replaced,
/// which is where the four screens using it picked the number up.
const double navBarReservedHeight = 96;

/// A row in the centre-button sheet. [route] is nullable because a row can be
/// in the design before its destination exists.
///
/// [icon] is an [IconData] (it used to be an emoji string): emoji render
/// differently per device and cannot be tinted to the brand.
///
/// [push] is the same question `NotificationDestination.isTab` asks, from the
/// other end. Every row here used to `go`, and the reason is recorded on the
/// tap handler: the sheet is popped before navigating, so there is nothing to
/// pop back through, and a row is a change of context rather than a drill-down.
/// That holds for a destination *inside* a branch — `go` keeps the bottom bar
/// and the shell's back ladder catches the user at the far end.
///
/// It does not hold for one **above** the shell. `/shop` is a root route (see
/// the rule at the top of `app_router.dart`), so `go` there replaces the whole
/// stack: no bottom bar, nothing to pop, and Android Back closes the app from
/// a screen the user opened one tap ago. Those rows [push] instead, which is
/// how the other above-the-shell destination reached from the shell —
/// `/clinics`, from Home's discovery block — already works.
typedef QuickAction = ({
  IconData icon,
  String label,
  String meta,
  String? route,
  bool push,
});

/// Tab order is load-bearing: the bar reports the index it was tapped at and
/// the shell hands that straight to `goBranch`, so these lists must stay in
/// step with the branch order in `app_router.dart`.
///
/// Built per-call from [AppLocalizations] rather than held in a `const` list:
/// the labels are drawn under the icons *and* are the tabs' accessible names,
/// so a Nepali reader seeing — or hearing — four English words is the same
/// bug either way. `context.l10n` falls back to English when the delegates
/// are absent, so a bar pumped on its own in a test still reads sensibly.
///
/// Find is deliberately not here. It is reached from the hero card on Home
/// and from the header's search icon, which frees the second slot for
/// Sessions — the screen a patient actually returns to between visits.
List<NavTab> _patientTabs(AppLocalizations l10n) => [
  (icon: Icons.home_rounded, label: l10n.navHome),
  (icon: Icons.history_rounded, label: l10n.navSessions),
  (icon: Icons.healing_rounded, label: l10n.navRecovery),
  (icon: Icons.person_rounded, label: l10n.navAccount),
];

List<NavTab> _therapistTabs(AppLocalizations l10n) => [
  (icon: Icons.home_rounded, label: l10n.navHome),
  (icon: Icons.calendar_month_rounded, label: l10n.navSchedule),
  (icon: Icons.mail_rounded, label: l10n.navRequests),
  (icon: Icons.person_rounded, label: l10n.navAccount),
];

class PatientNav extends StatelessWidget {
  const PatientNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _SahayatriBottomNav(
      tabs: _patientTabs(context.l10n),
      currentIndex: currentIndex,
      onSelect: onSelect,
      // Every supplied patient design draws the centre control as a plain
      // `+`, and so does the prototype bar in `app_bottom_nav.dart`. A
      // calendar glyph promises a calendar; the sheet behind this button
      // holds Packages, so the promise was wrong as well as off-design.
      fabIcon: Icons.add,
      onFabPressed: () => _showQuickActionSheet(context, 'patient'),
    );
  }
}

class TherapistNav extends StatelessWidget {
  const TherapistNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _SahayatriBottomNav(
      tabs: _therapistTabs(context.l10n),
      currentIndex: currentIndex,
      onSelect: onSelect,
      // Left as it was. The `+` above comes from the patient designs; there
      // is no therapist design here saying the same, and the therapist bar is
      // not this branch's to change. Worth revisiting: this glyph is also the
      // Schedule tab's icon two slots to the left, so the bar currently says
      // "calendar" twice and means different things by it.
      onFabPressed: () => _showQuickActionSheet(context, 'therapist'),
    );
  }
}

void _showQuickActionSheet(BuildContext context, String role) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickActionSheet(role: role),
  );
}

class _SahayatriBottomNav extends StatelessWidget {
  const _SahayatriBottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onFabPressed,
    this.fabIcon = Icons.add,
  });

  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onFabPressed;

  /// The centre control's glyph. Per-role because the two bars disagree: the
  /// patient designs show a `+`, the therapist bar has no such design and
  /// keeps the calendar it shipped with.
  final IconData fabIcon;

  @override
  Widget build(BuildContext context) {
    // The centre action splits the row, so the tabs are laid out two and two.
    final indices = List<int>.generate(tabs.length, (i) => i);
    final left = indices.take(2).toList();
    final right = indices.skip(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // The card colour and shadow run to the screen edge, but the controls
      // sit above the system bar: without this the back/home/recents buttons
      // are drawn straight over the icons on a device that shows them.
      //
      // viewPadding, not SafeArea: SafeArea reads MediaQuery.padding, which an
      // ancestor has already consumed by the time a Scaffold builds its
      // bottomNavigationBar, so it resolves to zero here. viewPadding reports
      // what the system bar actually occupies regardless of who consumed it.
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          6 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Builder(
          builder: (context) => Row(
            children: [
              // Each slot takes an equal share of its half of the bar rather
              // than a fixed 48dp: the labels below the icons are what needs
              // the width, and "Notifications" needs all of it.
              Expanded(
                child: Row(
                  children: left
                      .map(
                        (i) => Expanded(
                          child: _NavItem(
                            icon: tabs[i].icon,
                            label: tabs[i].label,
                            active: currentIndex == i,
                            onTap: () => onSelect(i),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onFabPressed,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.pine,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(fabIcon, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  children: right
                      .map(
                        (i) => Expanded(
                          child: _NavItem(
                            icon: tabs[i].icon,
                            label: tabs[i].label,
                            active: currentIndex == i,
                            onTap: () => onSelect(i),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.pine : AppColors.inkMute;

    return GestureDetector(
      onTap: onTap,
      // The slot is wider than the glyph, and every pixel of it should be
      // tappable: `deferToChild` made the hit area the 24dp icon alone, well
      // under the 48dp minimum. With the label below it the column is ~44dp
      // tall, and opaque makes the whole width of the slot live.
      behavior: HitTestBehavior.opaque,
      // The label is drawn now, so the Text announces itself; this node only
      // has to carry the role and the selected state. Without
      // `excludeSemantics` a screen reader reads every tab twice.
      child: Semantics(
        label: label,
        button: true,
        selected: active,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              // "Notifications" at 10px is wider than a quarter of a 320dp
              // bar, and so is "सूचनाहरू"; "अनुरोधहरू" on the therapist bar is
              // wider still. A label clipped to "Notific…" is worse than one
              // drawn a point smaller, and `scaleDown` only ever shrinks — so
              // every label that fits is drawn at the design's 10px.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    // The patient sheet used to duplicate the bar: "Book a session" opened
    // Find, which was a tab, and "View my sessions" opened Sessions, which is
    // a tab now. Both are gone — the sheet is for what the bar cannot reach.
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    final List<QuickAction> actions = role == 'therapist'
        ? [
            (
              icon: Icons.schedule_rounded,
              label: l10n.quickActionAddTimeBlock,
              meta: l10n.quickActionAddTimeBlockMeta,
              route: '/therapist/schedule',
              push: false,
            ),
            (
              icon: Icons.mail_rounded,
              label: l10n.quickActionViewRequests,
              meta: l10n.quickActionViewRequestsMeta,
              route: '/therapist/requests',
              push: false,
            ),
            (
              icon: Icons.notifications_rounded,
              label: l10n.quickActionNotifications,
              meta: l10n.quickActionNotificationsMeta,
              route: '/notifications',
              push: false,
            ),
          ]
        : [
            (
              icon: Icons.inventory_2_rounded,
              label: l10n.quickActionPackages,
              meta: l10n.quickActionPackagesMeta,
              // `go`, which the tap handler below already does: the sheet is
              // popped first, so there is no sheet to pop back through, and
              // this is a change of context rather than a drill-down into the
              // page the user was on. The route lives in the Home branch, so
              // the bottom bar stays and Home lights up.
              route: '/patient/packages',
              push: false,
            ),
            // The shop had no entrance at all. Every reference to `/shop` in
            // `lib/` came from inside the shop itself — the cart's Back and
            // the order receipt's "Continue shopping" — so ~800 lines of
            // working commerce, and the app's only non-session revenue, could
            // not be opened by anyone.
            //
            // It belongs here rather than on the Account menu or in Home's
            // discovery block. This sheet's whole job, stated where it is
            // built, is "what the bar cannot reach", and it already carries
            // the patient's other commerce surface; Shop is Packages' twin and
            // sits one tap from every tab. The discovery block is the three
            // answers to "how do I get care?" and buying a walker is not one
            // of them, and the Account menu is a record of care had and a set
            // of settings — burying a storefront three taps deep under it
            // would be a decision to hide it.
            //
            // `push`, not `go`: see [QuickAction].
            (
              icon: Icons.shopping_bag_rounded,
              label: l10n.quickActionShop,
              meta: l10n.quickActionShopMeta,
              route: '/shop',
              push: true,
            ),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        0,
      ),
      // A sheet sits at the very bottom of the screen, so its last action
      // lands under the system buttons without this.
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // The mono eyebrow (`quickActionEyebrow`) is gone: the settled
            // look has no eyebrow labels, and the title carries the sheet.
            Text(
              l10n.quickActionPrompt,
              style: text.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...actions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ActionTile(
                  icon: a.icon,
                  label: a.label,
                  meta: a.meta,
                  onTap: () {
                    Navigator.pop(context);
                    final route = a.route;
                    if (route == null) return;
                    a.push ? context.push(route) : context.go(route);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // The sheet is dismissible by drag and by tapping the barrier,
            // but neither is discoverable, and the design asks for a way out
            // that does not require guessing.
            //
            // Plain OutlinedButton with an explicit textStyle: the default
            // label style is labelLarge (mono, letter-spaced).
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.pine,
                  side: const BorderSide(color: AppColors.pine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  textStyle: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.actionClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.meta,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    // Mint tint from the settled look.
                    color: Color.alphaBlend(
                      AppColors.pinePale.withAlpha(150),
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 24, color: AppColors.pine),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: text.bodySmall?.copyWith(
                          fontSize: 12,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.inkMute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}