import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart'; // AppColors, AppSpacing, AppRadii
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../patient/domain/entities/session.dart';
import '../providers/therapist_providers.dart';

/// Hint text inside notes editor (Figma #66766F).
const Color _inkHint = Color(0xFF66766F);

/// Border for notes editor (Figma `semantic-border-subtle`).
const Color _borderSubtle = Color(0xFFDEE8E2);

const double _backIconSize = 24;
const double _photoSize = 52; // includes the 2px ring
const double _photoRing = 2;

const int _defaultSessionMinutes = 60;

String sessionInProgressPath(String sessionId) =>
    '/therapist/session/$sessionId';

bool canOpenSessionInProgress(Session s) =>
    s.status == SessionStatus.scheduled || s.status == SessionStatus.inProgress;

final Set<String> _startingIds = <String>{};

/// Starts [session] on the server
///
/// A failure is shown in a snackbar and the screen is NOT opened
Future<void> openSessionInProgress(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  // TODO: pass the real `startedAt` . check api data for started time.
  if (session.status == SessionStatus.inProgress) {
    await context.push<void>(sessionInProgressPath(session.id));
    return;
  }

  if (!_startingIds.add(session.id)) return;
  try {
    final result = await ref
        .read(therapistActionsProvider)
        .startSession(session.id);
    if (!context.mounted) return;
    result.match((failure) => _complain(context, failure), (_) {
      context.push<void>(
        sessionInProgressPath(session.id),
        extra: DateTime.now(),
      );
    });
  } finally {
    _startingIds.remove(session.id);
  }
}

void _complain(BuildContext context, Failure failure) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.danger,
      ),
    );
}

/// `mm:ss`, or `h:mm:ss`
@visibleForTesting
String formatElapsed(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "HH:MM" and add [minutes]
String _addMinutes(String hhmm, int minutes) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  final total = (h * 60 + m + minutes) % (24 * 60);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(total ~/ 60)}:${two(total % 60)}';
}

class SessionInProgressScreen extends ConsumerStatefulWidget {
  const SessionInProgressScreen({
    super.key,
    required this.sessionId,
    this.startedAt,
  });

  final String sessionId;
  final DateTime? startedAt;

  /// Keys so tests can address controls without matching on copy.
  static const Key timerKey = Key('sessionInProgress.timer');
  static const Key pauseKey = Key('sessionInProgress.pause');
  static const Key notesKey = Key('sessionInProgress.notes');
  static const Key completeKey = Key('sessionInProgress.complete');
  static const Key backKey = Key('sessionInProgress.back');

  @override
  ConsumerState<SessionInProgressScreen> createState() =>
      _SessionInProgressScreenState();
}

class _SessionInProgressScreenState
    extends ConsumerState<SessionInProgressScreen> {
  final TextEditingController _notes = TextEditingController();
  final FocusNode _notesFocus = FocusNode();

  late final ValueNotifier<Duration> _elapsed;
  late final DateTime _startedAt;
  Timer? _ticker;

  bool _paused = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startedAt = widget.startedAt ?? now;
    final since = now.difference(_startedAt);
    _elapsed = ValueNotifier<Duration>(
      Duration(seconds: since.isNegative ? 0 : since.inSeconds),
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return;
      _elapsed.value += const Duration(seconds: 1);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _elapsed.dispose();
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/therapist/home');
    }
  }

  void _togglePause() => setState(() => _paused = !_paused);

  /// Saves the notes, ends the session.
  Future<void> _complete(Session session) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final actions = ref.read(therapistActionsProvider);
    final notes = _notes.text.trim();

    if (notes.isNotEmpty) {
      final saved = await actions.saveSessionNotes(
        sessionId: session.id,
        notes: notes,
      );
      if (!mounted) return;
      final Failure? saveFailure = saved.fold<Failure?>((f) => f, (_) => null);
      if (saveFailure != null) {
        _complain(context, saveFailure);
        setState(() => _submitting = false);
        return;
      }
    }

    final ended = await actions.endSession(session.id);
    if (!mounted) return;
    final Failure? endFailure = ended.fold<Failure?>((f) => f, (_) => null);
    if (endFailure != null) {
      _complain(context, endFailure);
      setState(() => _submitting = false);
      return;
    }

    context.go('/therapist/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessions = ref.watch(therapistSessionsProvider);

    final all = sessions.valueOrNull;
    Session? session;
    if (all != null) {
      for (final s in all) {
        if (s.id == widget.sessionId) {
          session = s;
          break;
        }
      }
    }

    final Widget content;
    if (session != null) {
      content = _buildSession(context, session);
    } else if (all == null && sessions.hasError) {
      content = _CenteredMessage(
        message: l10n.therapistTodayLoadFailed,
        actionLabel: l10n.actionRetry,
        onAction: () => ref.invalidate(therapistSessionsProvider),
        onBack: _goBack,
      );
    } else if (all == null) {
      content = _CenteredMessage(onBack: _goBack, loading: true);
    } else {
      content = _CenteredMessage(
        message: l10n.sessionNotFound,
        onBack: _goBack,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(bottom: false, child: content),
    );
  }

  Widget _buildSession(BuildContext context, Session session) {
    final l10n = context.l10n;

    final end = _addMinutes(session.time, _defaultSessionMinutes);
    final subtitle = session.isHomeVisit
        ? l10n.sessionTypeHomeVisit
        : l10n.sessionTypeAtClinic;
    final when =
        '${formatFullDate(session.date, l10n)} • '
        '${formatTime12h(session.time)} – ${formatTime12h(end)}';

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final footerBottom = math.max(AppSpacing.lg, AppSpacing.xxxl - bottomInset);

    final startedClock = formatTime12h(
      '${_startedAt.hour.toString().padLeft(2, '0')}:'
      '${_startedAt.minute.toString().padLeft(2, '0')}',
    );

    return Column(
      children: [
        Container(
          color: AppColors.pine,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(width: AppSpacing.md),
              //  patient header
              _PatientHeader(
                session: session,
                subtitle: subtitle,
                when: when,
                onBack: _goBack,
              ),
              const SizedBox(height: AppSpacing.sm),

              //  status wrap
              _StatusWrap(
                title: _paused
                    ? l10n.sessionPausedTitle
                    : l10n.sessionInProgressTitle,
                startedAt: l10n.sessionStartedAt(startedClock),
                elapsed: _elapsed,
                paused: _paused,
                onTogglePause: _togglePause,
              ),
            ],
          ),
        ),

        //  body
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xl,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            child: _NotesEditor(controller: _notes, focusNode: _notesFocus),
          ),
        ),

        //  footer
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            footerBottom,
          ),
          child: _CompleteButton(
            submitting: _submitting,
            onPressed: _submitting ? null : () => _complete(session),
          ),
        ),
      ],
    );
  }
}

// WIDGETS

/// Row with back arrow ,photo, name
class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.session,
    required this.subtitle,
    required this.when,
    required this.onBack,
  });

  final Session session;
  final String subtitle;
  final String when;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              key: SessionInProgressScreen.backKey,
              onPressed: onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back,
                size: _backIconSize,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // 52px including a 2px white ring
            Container(
              width: _photoSize,
              height: _photoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: _photoRing),
              ),
              child: ProfileAvatar(
                initials: getInitials(session.patientName),
                photoUrl: session.patientPhotoUrl,
                thumbUrl: session.patientPhotoThumbUrl,
                size: _photoSize - 2 * _photoRing,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium!.copyWith(
                      fontSize: 17,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // TODO: Figma has "Back Pain Management"). using visit type for now
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      height: 1.0,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    when,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // TODO
            // const IconButton(
            //   onPressed: null,
            //   padding: EdgeInsets.zero,
            //   constraints: BoxConstraints(),
            //   disabledColor: Colors.white,
            //   icon: Icon(Icons.more_vert, size: _backIconSize),
            // ),
          ],
        ),
      ),
    );
  }
}

/// Row with title + "Started at" , clock
class _StatusWrap extends StatelessWidget {
  const _StatusWrap({
    required this.title,
    required this.startedAt,
    required this.elapsed,
    required this.paused,
    required this.onTogglePause,
  });

  final String title;
  final String startedAt;
  final ValueListenable<Duration> elapsed;
  final bool paused;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.page,
        ),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.md),

          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer, size: 24, color: Colors.white),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    startedAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ValueListenableBuilder<Duration>(
              valueListenable: elapsed,
              builder: (_, value, _) => Text(
                formatElapsed(value),
                key: SessionInProgressScreen.timerKey,
                style: text.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                key: SessionInProgressScreen.pauseKey,
                onPressed: onTogglePause,
                tooltip: paused ? l10n.actionResume : l10n.actionPause,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  paused ? Icons.play_arrow : Icons.pause,
                  size: 20,
                  color: AppColors.pine,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesEditor extends StatelessWidget {
  const _NotesEditor({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.sessionNotesHeading,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium!.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: focusNode.requestFocus,
          child: Container(
            constraints: const BoxConstraints(minHeight: 210),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: _borderSubtle),
            ),
            child: TextField(
              key: SessionInProgressScreen.notesKey,
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 9,
              maxLines: null,
              style: text.bodyMedium!.copyWith(
                color: AppColors.ink,
                height: 1.3,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: l10n.sessionNotesHint,
                hintStyle: text.bodyMedium!.copyWith(
                  color: _inkHint,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.submitting, required this.onPressed});

  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        key: SessionInProgressScreen.completeKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pine,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.pine.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          textStyle: text.titleMedium,
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(l10n.actionCompleteSession),
      ),
    );
  }
}

/// Loading / error / not-found
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.onBack,
    this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final VoidCallback onBack;
  final String? message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Column(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              0,
            ),
            child: IconButton(
              key: SessionInProgressScreen.backKey,
              onPressed: onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                size: _backIconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message ?? '',
                          textAlign: TextAlign.center,
                          style: text.bodyLarge!.copyWith(color: Colors.white),
                        ),
                        if (actionLabel != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: onAction,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              textStyle: text.titleSmall,
                            ),
                            child: Text(actionLabel!),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
