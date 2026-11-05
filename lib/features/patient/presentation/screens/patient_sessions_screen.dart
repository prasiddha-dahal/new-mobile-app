import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/navigation/tab_requests.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/session.dart';
import '../providers/patient_providers.dart';
import '../session_labels.dart';
import '../widgets/reschedule_sheet.dart';
import '../widgets/review_sheet.dart';

/// The three tabs, in the prototype's order.
enum _Tab { upcoming, past, cancelled }

extension on _Tab {
  String label(AppLocalizations l10n) => switch (this) {
    _Tab.upcoming => l10n.sessionTabUpcoming,
    _Tab.past => l10n.sessionTabPast,
    _Tab.cancelled => l10n.sessionTabCancelled,
  };

  /// The heading above the list.
  String heading(AppLocalizations l10n) => switch (this) {
    _Tab.upcoming => l10n.upcomingAppointmentsHeading,
    _Tab.past => l10n.pastAppointmentsHeading,
    _Tab.cancelled => l10n.cancelledAppointmentsHeading,
  };

  /// Which sessions belong under this tab.
  ///
  /// Grouping is date-aware, not status-only: a SCHEDULED session whose date
  /// has passed belongs under Past, otherwise it would keep offering a
  /// Reschedule the backend rejects.
  bool matches(Session s) => switch (this) {
    _Tab.upcoming => s.isUpcoming,
    _Tab.past => s.isPast,
    _Tab.cancelled => s.isCancelled,
  };

  String emptyMessage(AppLocalizations l10n) => switch (this) {
    _Tab.upcoming => l10n.sessionsEmptyUpcoming,
    _Tab.past => l10n.sessionsEmptyPast,
    _Tab.cancelled => l10n.sessionsEmptyCancelled,
  };
}

class PatientSessionsScreen extends ConsumerStatefulWidget {
  const PatientSessionsScreen({super.key});

  @override
  ConsumerState<PatientSessionsScreen> createState() =>
      _PatientSessionsScreenState();
}

class _PatientSessionsScreenState extends ConsumerState<PatientSessionsScreen> {
  _Tab _tab = _Tab.upcoming;

  /// Ids with an action in flight, so a card can disable its own buttons
  /// without freezing the rest of the list.
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    // A "rate your visit" tap that built this screen: the provider was set
    // before the tab existed, so `ref.listen` in build would never see the
    // change. Read it once here and clear it after the first frame.
    if (ref.read(openPastSessionsProvider)) {
      _tab = _Tab.past;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(openPastSessionsProvider.notifier).state = false;
        _refreshReviewState();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final sessions = ref.watch(patientSessionsProvider);

    // The same tap arriving while this tab is already built (the shell keeps
    // it alive).
    ref.listen(openPastSessionsProvider, (_, open) {
      if (!open) return;
      setState(() => _tab = _Tab.past);
      ref.read(openPastSessionsProvider.notifier).state = false;
      _refreshReviewState();
    });

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.sessionsTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabs: three separate pills, the active one dark.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final tab in _Tab.values) ...[
                    if (tab != _Tab.values.first) const SizedBox(width: 8),
                    Expanded(
                      child: _TabPill(
                        label: _tabLabel(tab, sessions.valueOrNull, l10n),
                        active: _tab == tab,
                        onTap: () => setState(() => _tab = tab),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // List heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _tab.heading(l10n),
                style: text.titleMedium!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: sessions.when(
                loading: () => const SkeletonList(
                  count: 3,
                  itemHeight: 210,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(patientSessionsProvider),
                ),
                data: (all) {
                  final items = all.where(_tab.matches).toList()
                    // Upcoming reads soonest-first; history reads newest-first.
                    ..sort(
                      (a, b) => _tab == _Tab.upcoming
                          ? a.date.compareTo(b.date)
                          : b.date.compareTo(a.date),
                    );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(patientSessionsProvider);
                      ref.invalidate(reviewableSessionIdsProvider);
                      ref.invalidate(myReviewsProvider);
                    },
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 40),
                              EmptyStateView(
                                title: _tab.emptyMessage(l10n),
                                icon: Icons.event_busy_outlined,
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _SessionCard(
                              session: items[i],
                              reviewState: _reviewState(items[i]),
                              busy: _busy.contains(items[i].id),
                              onReschedule: () => _reschedule(items[i]),
                              onCancel: () => _cancel(items[i]),
                              onReview: () => _review(items[i]),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(_Tab tab, List<Session>? all, AppLocalizations l10n) {
    final count = all?.where(tab.matches).length;
    return count == null
        ? tab.label(l10n)
        : l10n.sessionTabWithCount(tab.label(l10n), count);
  }

  Future<void> _runAction(
    Session session,
    Future<AppResult<Object?>> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busy.add(session.id));
    final result = await action();
    if (!mounted) return;
    setState(() => _busy.remove(session.id));

    result.match(
      (failure) => _toast(failure.message, isError: true),
      (_) => _toast(successMessage),
    );
  }

  Future<void> _reschedule(Session session) async {
    final choice = await showRescheduleSheet(context, session: session);
    if (choice == null || !mounted) return;

    await _runAction(
      session,
      () => ref
          .read(patientActionsProvider)
          .reschedule(
            sessionId: session.id,
            newDate: choice.date,
            newTime: choice.time,
          ),
      successMessage: context.l10n.sessionRescheduleRequested,
    );
  }

  Future<void> _cancel(Session session) async {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        title: Text(l10n.sessionCancelTitle),
        titleTextStyle: text.titleLarge,
        content: Text(
          l10n.sessionCancelBody(
            session.therapistName,
            formatDateTime(session.date, session.time, l10n),
          ),
        ),
        contentTextStyle: text.bodyMedium!.copyWith(height: 1.45),
        actions: [
          // Buttons default to labelLarge (mono, spaced), so the style is
          // set explicitly.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMid,
              textStyle: text.titleSmall,
            ),
            child: Text(l10n.sessionKeepIt),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              textStyle: text.titleSmall,
            ),
            child: Text(l10n.sessionCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction(
      session,
      () => ref.read(patientActionsProvider).cancel(session.id),
      successMessage: context.l10n.sessionCancelledToast,
    );
  }

  /// The visit just completed is not in lists fetched before it was: refetch
  /// them, so the card the notification pointed at shows its review button.
  void _refreshReviewState() {
    ref.invalidate(patientSessionsProvider);
    ref.invalidate(reviewableSessionIdsProvider);
    ref.invalidate(myReviewsProvider);
  }

  /// What [session]'s card says about its review: the button, the rating the
  /// patient gave, or why there is no button.
  ///
  /// While the lookups load nothing is shown, so a line does not appear and
  /// then change; if the "still reviewable" lookup fails the button is offered,
  /// because withholding it would take the feature away over a flaky
  /// connection and the server refuses a duplicate anyway.
  ReviewState _reviewState(Session session) {
    final reviewable = ref.watch(reviewableSessionIdsProvider);
    final reviews = ref.watch(myReviewsProvider);
    return reviewStateFor(
      session,
      reviewable: reviewable.valueOrNull,
      reviews: reviews.valueOrNull,
      reviewableFailed: reviewable.hasError,
    );
  }

  Future<void> _review(Session session) async {
    final choice = await showReviewSheet(context, session: session);
    if (choice == null || !mounted) return;

    await _runAction(
      session,
      () => ref
          .read(patientActionsProvider)
          .review(
            sessionId: session.id,
            rating: choice.rating,
            comment: choice.comment,
          ),
      successMessage: context.l10n.sessionReviewThanks,
    );
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }
}

// ── Tabs ─────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: text.titleSmall!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────

/// "14:30" -> "2:30 PM". A value that already has AM/PM, or that isn't
/// HH:mm, is returned as is.
String _time12(String raw) {
  final value = raw.trim();
  if (RegExp(r'[ap]\.?m\.?$', caseSensitive: false).hasMatch(value)) {
    return value;
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value;
  final hour = int.parse(match.group(1)!);
  if (hour > 23) return value;
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${match.group(2)} $period';
}

/// The soft mint behind the date block.
final Color _mint = Color.alphaBlend(
  AppColors.pinePale.withAlpha(150),
  Colors.white,
);

/// A status is only worth a tag when it is not the ordinary "confirmed and
/// still to come" case; the date block already says when it is.
bool _showStatus(Session s) =>
    !(s.status == SessionStatus.scheduled && !s.hasElapsed);

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.reviewState,
    required this.busy,
    required this.onReschedule,
    required this.onCancel,
    required this.onReview,
  });

  final Session session;

  /// Decided by the screen, which knows what the server will accept.
  final ReviewState reviewState;
  final bool busy;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final canAct = session.canReschedule || session.canCancel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date block, photo and the visit's details.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBlock(date: session.date),
                const SizedBox(width: 10),
                ProfileAvatar(
                  initials: getInitials(session.therapistName),
                  photoUrl: session.therapistPhotoUrl,
                  thumbUrl: session.therapistPhotoThumbUrl,
                  tint: AppColors.pinePale,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.therapistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled_rounded,
                            size: 15,
                            color: AppColors.inkMid,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _time12(session.time),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TypeChip(
                            icon: session.isHomeVisit
                                ? Icons.home_outlined
                                : Icons.local_hospital_outlined,
                            label: session.isHomeVisit
                                ? l10n.homeVisit
                                : l10n.sessionTypeAtClinic,
                          ),
                          if (_showStatus(session))
                            StatusTag(
                              label: _statusLabel(session, l10n),
                              tone: sessionStatusTone(session),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Where the visit is, and the fee. Tapping opens the therapist.
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            InkWell(
              onTap: () =>
                  context.push('/patient/therapist/${session.therapistId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.isHomeVisit && session.address.isNotEmpty
                            ? l10n.sessionHomeVisitAt(session.address)
                            : formatCurrency(session.fee, l10n),
                        //maxLines: 1,
                        //overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (session.isHomeVisit && session.address.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(session.fee, l10n),
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.inkMid,
                    ),
                  ],
                ),
              ),
            ),

            if (canAct) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: busy || !session.canReschedule
                            ? null
                            : onReschedule,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.pine,
                          side: const BorderSide(color: AppColors.pine),
                          textStyle: text.titleSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                          ),
                        ),
                        child: Text(l10n.actionReschedule),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: busy || !session.canCancel ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.dangerPale,
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          textStyle: text.titleSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                          ),
                        ),
                        child: Text(l10n.actionCancel),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            switch (reviewState) {
              ReviewOpen() => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: busy ? null : onReview,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.pine,
                      side: const BorderSide(color: AppColors.pine),
                      textStyle: text.titleSmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: Text(l10n.actionLeaveReview),
                  ),
                ),
              ),
              ReviewDone(:final review) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _RatedRow(rating: review.rating),
              ),
              ReviewDoneForTherapist(:final review) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _RatedRow(
                  rating: review.rating,
                  label: l10n.reviewAlreadyTherapist(session.therapistName),
                ),
              ),
              ReviewNone() => const SizedBox.shrink(),
            },

            if (busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.pine,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Mon / 13 / May" in a soft mint block.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final locale = Localizations.localeOf(context).toString();

    String fmt(String pattern) {
      try {
        return DateFormat(pattern, locale).format(date);
      } catch (_) {
        return DateFormat(pattern).format(date);
      }
    }

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Column(
        children: [
          Text(
            fmt('EEE'),
            style: text.bodySmall!.copyWith(color: AppColors.inkMid),
          ),
          Text(
            '${date.day}',
            style: text.titleLarge!.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          Text(
            fmt('MMM'),
            style: text.bodySmall!.copyWith(color: AppColors.inkMid),
          ),
        ],
      ),
    );
  }
}

/// A small outlined pill saying where the visit happens.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.pine.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.pine),
          const SizedBox(width: 5),
          Text(
            label,
            style: text.titleSmall!.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tomorrow" reads better than "Confirmed" when it is, in fact, tomorrow.
String _statusLabel(Session s, AppLocalizations l10n) {
  if (s.status == SessionStatus.scheduled && !s.hasElapsed) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      s.date.year,
      s.date.month,
      s.date.day,
    ).difference(today).inDays;
    if (days == 0) return l10n.statusToday;
    if (days == 1) return l10n.statusTomorrow;
  }
  return sessionLabel(s, l10n).toUpperCase();
}

/// "You rated this visit ★★★★☆" -- the stars are the answer, so they are read
/// out as one phrase rather than five icons.
class _RatedRow extends StatelessWidget {
  const _RatedRow({required this.rating, this.label});

  final int rating;

  /// Overrides "You rated this visit" when the rating was for another visit.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final stars = rating.clamp(0, 5);

    return Semantics(
      container: true,
      label:
          '${label ?? l10n.reviewYouRated}, '
          '${l10n.reviewStarsSemantics(stars)}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? l10n.reviewYouRated,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: i <= stars ? AppColors.amberBrand : AppColors.border,
              ),
          ],
        ),
      ),
    );
  }
}