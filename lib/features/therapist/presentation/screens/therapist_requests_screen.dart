import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../../patient/domain/entities/session.dart';
import '../../../patient/presentation/session_labels.dart';
import '../providers/therapist_providers.dart';
import '../widgets/navigate_button.dart';
import '../widgets/visit_map_preview.dart';
import '../widgets/session_notes_sheet.dart';

/// A visit still marked confirmed or in progress whose day has passed.
///
/// Today's visits are not overdue however late it is: the therapist may be on
/// the way. From tomorrow they need closing.
bool isOverdue(Session s) =>
    s.hasElapsed &&
    (s.status == SessionStatus.scheduled ||
        s.status == SessionStatus.inProgress);

/// The four tabs from the prototype, mapped onto the backend's session
/// lifecycle.
///
/// A patient booking lands as SCHEDULED — the API has no "pending request"
/// state — so "Requests" holds the sessions that actually need a decision from
/// the therapist: the ones a patient has asked to move or call off.
enum _Tab {
  requests,
  upcoming,
  completed,
  cancelled;

  String label(AppLocalizations l10n) => switch (this) {
    _Tab.requests => l10n.requestsTitle,
    _Tab.upcoming => l10n.requestsTabUpcoming,
    _Tab.completed => l10n.requestsTabCompleted,
    _Tab.cancelled => l10n.sessionTabCancelled,
  };

  bool matches(Session s) => switch (this) {
    _Tab.requests =>
      s.status == SessionStatus.rescheduleRequested ||
          s.status == SessionStatus.declineRequested ||
          isOverdue(s),
    _Tab.upcoming =>
      s.status.isUpcoming &&
          s.status != SessionStatus.rescheduleRequested &&
          s.status != SessionStatus.declineRequested &&
          !isOverdue(s),
    _Tab.completed => s.status == SessionStatus.completed,
    _Tab.cancelled => s.isCancelled,
  };

  String emptyMessage(AppLocalizations l10n) => switch (this) {
    _Tab.requests => l10n.requestsEmptyWaiting,
    _Tab.upcoming => l10n.requestsEmptyUpcoming,
    _Tab.completed => l10n.sessionsEmptyPast,
    _Tab.cancelled => l10n.sessionsEmptyCancelled,
  };
}

class TherapistRequestsScreen extends ConsumerStatefulWidget {
  const TherapistRequestsScreen({super.key});

  @override
  ConsumerState<TherapistRequestsScreen> createState() =>
      _TherapistRequestsScreenState();
}

class _TherapistRequestsScreenState
    extends ConsumerState<TherapistRequestsScreen> {
  _Tab _tab = _Tab.requests;
  final _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final sessions = ref.watch(therapistSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Page title. The mono eyebrow (`requestsEyebrow`) is dropped.
            // No back arrow: this is a tab, with the app header above it.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Text(
                l10n.requestsHeading,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: _Tab.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final tab = _Tab.values[i];
                  final active = _tab == tab;
                  final count = sessions.valueOrNull?.where(tab.matches).length;
                  return GestureDetector(
                    onTap: () => setState(() => _tab = tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: active ? AppColors.ink : AppColors.mist,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count == null || count == 0
                            ? tab.label(l10n)
                            : l10n.sessionTabWithCount(tab.label(l10n), count),
                        style: text.titleSmall!.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: active ? Colors.white : AppColors.inkMid,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: sessions.when(
                loading: () => const SkeletonList(
                  count: 3,
                  itemHeight: 148,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(therapistSessionsProvider),
                ),
                data: (all) {
                  final items = all.where(_tab.matches).toList()
                    ..sort(
                      (a, b) => _tab == _Tab.upcoming || _tab == _Tab.requests
                          ? a.date.compareTo(b.date)
                          : b.date.compareTo(a.date),
                    );
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(therapistSessionsProvider),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.page,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _RequestCard(
                              key: ValueKey(items[i].id),
                              session: items[i],
                              tab: _tab,
                              busy: _busy.contains(items[i].id),
                              onAccept: () => _approve(items[i]),
                              onDecline: () => _refuse(items[i]),
                              onMarkComplete: () => _markComplete(items[i]),
                              onNotes: () => _editNotes(items[i]),
                              onDidNotHappen: () => _didNotHappen(items[i]),
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

  /// Grant what the patient asked for.
  Future<void> _approve(Session session) {
    final isCancellation = session.status == SessionStatus.declineRequested;
    return _setStatus(
      session,
      isCancellation ? SessionStatus.cancelled : SessionStatus.scheduled,
      message: isCancellation
          ? context.l10n.requestCancellationApproved
          : context.l10n.requestNewTimeConfirmed,
    );
  }

  /// Refuse it and put the session back to its confirmed state.
  Future<void> _refuse(Session session) {
    final isCancellation = session.status == SessionStatus.declineRequested;
    return _setStatus(
      session,
      isCancellation ? SessionStatus.scheduled : SessionStatus.cancelled,
      message: isCancellation
          ? context.l10n.requestSessionKept
          : context.l10n.requestDeclined,
    );
  }

  Future<void> _setStatus(
    Session session,
    SessionStatus status, {
    required String message,
  }) async {
    setState(() => _busy.add(session.id));
    final result = await ref
        .read(therapistActionsProvider)
        .setSessionStatus(sessionId: session.id, status: status);
    if (!mounted) return;
    setState(() => _busy.remove(session.id));
    result.match((f) => _toast(f.message, isError: true), (_) => _toast(message));
  }

  /// Closes an overdue visit in one tap: starts it first when it was never
  /// started, then ends it, so the therapist never sees those two steps.
  Future<void> _markComplete(Session session) async {
    setState(() => _busy.add(session.id));
    final actions = ref.read(therapistActionsProvider);

    if (session.status != SessionStatus.inProgress) {
      final started = await actions.startSession(session.id);
      final failure = started.match((f) => f, (_) => null);
      if (failure != null) {
        if (!mounted) return;
        setState(() => _busy.remove(session.id));
        _toast(failure.message, isError: true);
        return;
      }
    }

    final ended = await actions.endSession(session.id);
    if (!mounted) return;
    setState(() => _busy.remove(session.id));
    ended.match(
      (f) => _toast(f.message, isError: true),
      (_) => _toast(context.l10n.sessionStatusDone),
    );
  }

  /// Closes an overdue visit that never took place. Cancelling it also
  /// cancels any payment still pending against it, so nothing is earned.
  Future<void> _didNotHappen(Session session) async {
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
        title: Text(l10n.requestDidNotHappenTitle),
        titleTextStyle: text.titleLarge!.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        content: Text(l10n.requestDidNotHappenBody),
        contentTextStyle: text.bodyMedium!.copyWith(
          height: 1.45,
          letterSpacing: 0,
          color: AppColors.inkMid,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMid,
              textStyle: text.titleSmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              textStyle: text.titleSmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(l10n.requestDidNotHappen),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _setStatus(
      session,
      SessionStatus.cancelled,
      message: l10n.requestRecordedNotHappened,
    );
  }

  Future<void> _editNotes(Session session) async {
    final saved = await showSessionNotesSheet(context, session: session);
    if (saved == true && mounted) ref.invalidate(therapistSessionsProvider);
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.session,
    required this.tab,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onMarkComplete,
    required this.onNotes,
    required this.onDidNotHappen,
  });

  final Session session;
  final _Tab tab;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onMarkComplete;
  final VoidCallback onNotes;
  final VoidCallback onDidNotHappen;

  bool get _isCancellation => session.status == SessionStatus.declineRequested;
  bool get _overdue => isOverdue(session);

  TagTone get _tone => _overdue
      ? TagTone.red
      : switch (session.status) {
          SessionStatus.cancelled => TagTone.red,
          SessionStatus.completed => TagTone.neutral,
          SessionStatus.rescheduleRequested ||
          SessionStatus.declineRequested => TagTone.amber,
          _ => TagTone.green,
        };

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: text.titleSmall!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.isHomeVisit
                            ? session.address
                            : context.l10n.sessionTypeAtClinic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(
                          fontSize: 13,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusTag(
                  label: _overdue
                      ? context.l10n.requestOverdue.toUpperCase()
                      : sessionStatusLabel(
                          session.status,
                          context.l10n,
                        ).toUpperCase(),
                  tone: _tone,
                ),
              ],
            ),
            VisitLandmark(session: session),
            const SizedBox(height: AppSpacing.md),
            // Date and time on the left with an icon, the fee on the right.
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.inkMid,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatDateTime(session.date, session.time, context.l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      fontSize: 13,
                      letterSpacing: 0,
                      color: AppColors.inkMid,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  formatCurrency(session.fee, context.l10n),
                  style: text.titleSmall!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            if (tab == _Tab.requests && _overdue) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.requestOverdueHint,
                style: text.bodySmall!.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryButton(
                      onPressed: busy ? null : onMarkComplete,
                      label: context.l10n.requestMarkComplete,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SecondaryButton(
                      onPressed: busy ? null : onDidNotHappen,
                      label: context.l10n.requestDidNotHappen,
                    ),
                  ),
                ],
              ),
            ] else if (tab == _Tab.requests) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryButton(
                      onPressed: busy ? null : onAccept,
                      label: _isCancellation
                          ? context.l10n.requestApprove
                          : context.l10n.requestAccept,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SecondaryButton(
                      onPressed: busy ? null : onDecline,
                      label: _isCancellation
                          ? context.l10n.requestKeepSession
                          : context.l10n.requestDecline,
                    ),
                  ),
                ],
              ),
            ],
            if (tab == _Tab.upcoming && canNavigateTo(session)) ...[
              if (session.point != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _VisitMap(session: session),
              ],
              const SizedBox(height: AppSpacing.lg),
              NavigateButton(session: session),
            ],
            if (tab == _Tab.completed) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: _SecondaryButton(
                  onPressed: busy ? null : onNotes,
                  label: (session.notes ?? '').isEmpty
                      ? context.l10n.requestAddNotes
                      : context.l10n.requestEditNotes,
                ),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.pine,
                  backgroundColor: AppColors.mist,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pine fill, white text. Buttons default to labelLarge (mono, spaced), so the
/// text style is given explicitly.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pine,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.pine.withAlpha(90),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: AppTypography.textTheme.titleSmall!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.row),
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// White with a pine outline.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.pine,
          disabledForegroundColor: AppColors.inkMute,
          side: BorderSide(
            color: onPressed == null ? AppColors.border : AppColors.pine,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: AppTypography.textTheme.titleSmall!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.row),
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _VisitMap extends ConsumerWidget {
  const _VisitMap({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VisitMapPreview(
    session: session,
    onOpen: () => openDirections(context, ref, session),
  );
}