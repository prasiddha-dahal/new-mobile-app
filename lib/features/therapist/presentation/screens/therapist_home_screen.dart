import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/session_in_progress.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patient/domain/entities/session.dart';
import '../../../patient/presentation/session_labels.dart';
import '../../../patient/presentation/providers/patient_providers.dart'
    show formatDateKey;
import '../providers/therapist_providers.dart';
import '../widgets/navigate_button.dart';

const double _navClearance = 96;

class TherapistHomeScreen extends ConsumerWidget {
  const TherapistHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(therapistDashboardProvider);
    final sessions = ref.watch(therapistSessionsProvider);
    final user = ref.watch(currentUserProvider);

    final all = sessions.valueOrNull ?? const <Session>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // not cancelled and not already completed, but reschedule/decline requests are included
    final upcoming =
        all
            .where(
              (s) =>
                  !s.isCancelled &&
                  s.status != SessionStatus.completed &&
                  !s.hasElapsed,
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.date.compareTo(b.date);
            return byDate != 0 ? byDate : a.time.compareTo(b.time);
          });

    final next = upcoming.isEmpty ? null : upcoming.first;

    final remainingToday = upcoming
        .where((s) => DateTime(s.date.year, s.date.month, s.date.day) == today)
        .toList();

    final pending =
        all
            .where(
              (s) =>
                  s.status == SessionStatus.rescheduleRequested ||
                  s.status == SessionStatus.declineRequested ||
                  // Same as the Requests tab: a past visit nobody closed.
                  (s.hasElapsed &&
                      (s.status == SessionStatus.scheduled ||
                          s.status == SessionStatus.inProgress)),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final name = user?.name.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(therapistDashboardProvider);
            ref.invalidate(therapistSessionsProvider);
            ref.invalidate(ownSlotsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // The hero. It opened with "Good morning, {name}" and an
                // avatar until the shell started mounting one header for
                // every screen; keeping both would print the therapist's name
                // twice on the same page. What is left is the part that is
                // this screen's own — whether they are accepting bookings.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfileAvatar(
                            initials: user?.initials ?? 'T',
                            // TODO: pass the therapist's photoUrl
                            size: 56,
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_greeting(l10n)},',
                                  style: text.bodyMedium!.copyWith(
                                    fontSize: 12,
                                    color: AppColors.ink.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                                Text(
                                  user?.name.trim().isNotEmpty == true
                                      ? name
                                      : '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium!.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sessions.isLoading || sessions.hasError
                                      ? ''
                                      : remainingToday.isEmpty
                                      ? l10n.therapistNothingToday
                                      : l10n.therapistSessionsScheduledToday(
                                          remainingToday.length,
                                        ),
                                  style: text.titleSmall!.copyWith(
                                    fontSize: 10,
                                    color: AppColors.ink.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Search ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: GestureDetector(
                    onTap: () => context.push('/therapist/patients'),
                    child: Hero(
                      tag: 'session-search-bar',
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                size: 22,
                                color: AppColors.inkMid,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.therapistSearchHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium!.copyWith(
                                    color: AppColors.inkMid,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                //  Quick actions component
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _SectionHeader(
                    title: l10n.therapistNextSessionTitle,
                    actionLabel: l10n.actionViewAll,
                    onAction: () {},
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  // Loading -> error -> empty -> data
                  child: sessions.isLoading
                      ? const SkeletonList(count: 1, itemHeight: 200)
                      : sessions.hasError
                      ? InlineRetry(
                          message: l10n.therapistTodayLoadFailed,
                          onRetry: () =>
                              ref.invalidate(therapistSessionsProvider),
                        )
                      : next == null
                      ? _NoNextSessionCard(
                          onManage: () =>
                              context.push('/therapist/availability'),
                        )
                      : _NextSessionCard(
                          session: next,
                          onReschedule: () => context.go('/therapist/requests'),

                          onStart:
                              // () {
                              //   context.push('/therapist/session/${all.last.id}');
                              // },
                              canOpenSessionInProgress(next)
                              ? () => openSessionInProgress(context, ref, next)
                              : null,
                        ),
                ),

                const SizedBox(height: AppSpacing.md),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _GroupedPanel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _QuickAction(
                          icon: Icons.file_present_outlined,
                          label: l10n.therapistActionPatientRecords,
                          onTap: () => context.push('/therapist/patients'),
                        ),
                        _QuickAction(
                          icon: Icons.insert_chart_outlined,
                          label: l10n.therapistActionViewEarnings,
                          onTap: () => context.push('/therapist/earnings'),
                        ),
                        _QuickAction(
                          icon: Icons.settings,
                          label: l10n.therapistActionManageAvailability,
                          onTap: () => context.push('/therapist/availability'),
                        ),
                        _QuickAction(
                          icon: Icons.landscape_sharp,
                          label: 'Service Area',
                          onTap: () => context.push('/therapist/service-areas'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _SectionHeader(
                    title: l10n.therapistKpiThisWeek,
                    actionLabel: 'Insights',
                    onAction: () {},
                  ),
                ),

                // KPI cards compoent
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: _GroupedPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            compact: true,
                            label: l10n.therapistKpiThisWeek,
                            value: dashboard.valueOrNull == null
                                ? '—'
                                : l10n.therapistKpiSessionsCount(
                                    dashboard.value!.sessionsThisWeek,
                                  ),
                            subtitle: l10n.therapistKpiBooked,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: KpiCard(
                            compact: true,
                            label: l10n.therapistKpiEarnings,
                            value: dashboard.valueOrNull == null
                                ? '—'
                                : formatCurrency(
                                    dashboard.value!.earningsThisMonth,
                                    l10n,
                                  ),
                            subtitle: l10n.therapistKpiThisMonth,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: KpiCard(
                            compact: true,
                            label: l10n.therapistKpiRating,
                            value: dashboard.valueOrNull == null
                                ? '—'
                                : (dashboard.value!.averageRating == 0
                                      ? l10n.therapistNotRated
                                      : l10n.therapistRatingValue(
                                          dashboard.value!.averageRating,
                                        )),
                            subtitle: l10n.therapistKpiAverage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: KpiCard(
                            compact: true,
                            label: l10n.therapistKpiPatients,
                            value: dashboard.valueOrNull == null
                                ? '—'
                                : '${dashboard.value!.totalPatients}',
                            subtitle: l10n.therapistKpiTotalSeen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (pending.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: Column(
                      children: pending
                          .take(3)
                          .map(
                            (r) => _PendingCard(
                              session: r,
                              onOpen: () => context.go('/therapist/requests'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(title: l10n.upcomingPatientsHeading),

                const SizedBox(height: _navClearance),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers & components/ widgets ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: text.titleSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

const Color _mint = Color.fromARGB(255, 203, 230, 208);

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.session,
    required this.onReschedule,
    required this.onStart,
  });

  final Session session;
  final VoidCallback onReschedule;

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final l10n = context.l10n;

    final needsAttention =
        session.status == SessionStatus.rescheduleRequested ||
        session.status == SessionStatus.declineRequested;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: AppColors.pinePale),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -34,
            child: Opacity(
              opacity: 0.12,
              child: SvgPicture.asset(
                'assets/images/sahayatri-logo.svg',
                width: 120,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SquarePhoto(
                        name: session.patientName,
                        photoUrl: session.patientPhotoUrl,
                        thumbUrl: session.patientPhotoThumbUrl,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              session.patientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall!.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: needsAttention
                                    ? AppColors.amberBrand
                                    : AppColors.pine,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.full,
                                ),
                              ),
                              child: Text(
                                sessionStatusLabel(
                                  session.status,
                                  l10n,
                                ).toUpperCase(),
                                style: text.bodySmall!.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // TODO: therapy type eg, Back Pain Management . see Figma desgin

                            Text(
                              (session.isHomeVisit
                                      ? l10n.sessionTypeHomeVisit
                                      : l10n.sessionTypeAtClinic)
                                  .toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium!.copyWith(
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                            if (session.isHomeVisit &&
                                session.address.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 12),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      session.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodySmall!.copyWith(
                                        fontSize: 10,
                                        height: 1.2,
                                        color: AppColors.inkMid,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        icon: Icons.calendar_today_outlined,
                        title: formatDayLabelFromString(
                          formatDateKey(session.date),
                          l10n,
                        ),
                        subtitle: formatFullDate(session.date, l10n),
                      ),
                    ),
                    Expanded(
                      child: _InfoBlock(
                        icon: Icons.access_time,
                        title: formatTime12h(session.time),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: onReschedule,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.pine,
                            side: const BorderSide(color: AppColors.pine),
                            textStyle: text.titleSmall,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                          ),
                          child: Text(l10n.actionReschedule),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // TODO: start session page/widget
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: onStart,
                          // onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pine,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            textStyle: text.titleSmall!.copyWith(
                              color: Colors.white,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                          ),
                          child: Text(context.l10n.actionStartSession),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SquarePhoto extends StatelessWidget {
  const _SquarePhoto({
    required this.name,
    required this.photoUrl,
    required this.thumbUrl,
  });

  final String name;
  final String? photoUrl;
  final String? thumbUrl;

  static const double _size = 80;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final url = (thumbUrl?.isNotEmpty ?? false) ? thumbUrl : photoUrl;

    final fallback = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      color: AppColors.pinePale,
      child: Text(
        getInitials(name),
        style: text.titleMedium!.copyWith(color: AppColors.pine),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.row),
      child: (url == null || url.isEmpty)
          ? fallback
          : Image.network(
              url,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _NoNextSessionCard extends StatelessWidget {
  const _NoNextSessionCard({required this.onManage});
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.therapistNoUpcomingSessions,
              style: text.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pine,
              textStyle: text.titleSmall,
            ),
            child: Text(l10n.therapistActionManageAvailability),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.ink),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium!.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hero eyebrow. The trailing comma went with the name it used to
/// introduce — that name is in the shared header now.
String _greeting(AppLocalizations l10n) {
  final hour = DateTime.now().hour;
  if (hour < 12) return l10n.greetingMorning;
  if (hour < 17) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}

// A container grouping tiles in a row (for quick actions tiles, KPIs tiles)
class _GroupedPanel extends StatelessWidget {
  const _GroupedPanel({required this.child, this.horizontalPadding = 4});

  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AppSpacing.md,
      ),
      child: child,
    );
  }
}

/// One icon and description in a tile.
///
/// [onTap] is nullable: `null` means "not available yet".
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.mist,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    label.replaceFirst(' ', '\n'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      fontSize: 10,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
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

class _VisitRow extends ConsumerWidget {
  const _VisitRow({required this.session});
  final Session session;

  bool get _canStart => session.status == SessionStatus.scheduled;
  bool get _canEnd => session.status == SessionStatus.inProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  session.time,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 14,
                    color: AppColors.pine,
                  ),
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      session.isHomeVisit
                          ? session.address
                          : context.l10n.sessionTypeAtClinic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ],
                ),
              ),
              StatusTag(
                label: sessionStatusLabel(session.status, context.l10n),
                tone: sessionStatusTone(session),
              ),
              if (canNavigateTo(session))
                NavigateButton(session: session, compact: true),
            ],
          ),
          if (_canStart || _canEnd)
            Padding(
              padding: const EdgeInsets.only(left: 60, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () async {
                    final actions = ref.read(therapistActionsProvider);
                    final result = _canStart
                        ? await actions.startSession(session.id)
                        : await actions.endSession(session.id);
                    if (!context.mounted) return;
                    result.match(
                      (f) => ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(f.message))),
                      (_) {},
                    );
                  },
                  child: Text(
                    _canStart
                        ? context.l10n.sessionStart
                        : context.l10n.sessionEnd,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.session, required this.onOpen});
  final Session session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onOpen,
        child: Row(
          children: [
            ProfileAvatar(
              initials: getInitials(session.patientName),
              photoUrl: session.patientPhotoUrl,
              thumbUrl: session.patientPhotoThumbUrl,
              tint: AppColors.amberPale,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sessionStatusLabel(session.status, context.l10n),
                    style: text.bodyMedium!.copyWith(fontSize: 11),
                  ),
                  Text(
                    '${formatDateTime(session.date, session.time, context.l10n)} · '
                    '${formatCurrency(session.fee, context.l10n)}',
                    style: text.bodySmall!.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkMute),
          ],
        ),
      ),
    );
  }
}
