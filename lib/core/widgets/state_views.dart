import 'package:flutter/material.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

import '../error/failures.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Shown where a screen is finished but its backend endpoint is not.
///
/// The API-TODO convention (docs/DEVELOPMENT_PLAN.md §0.2). The point is honesty:
/// the user sees that the feature is coming rather than a crash, an endless
/// spinner, or — worst — a fake success.
class ApiTodoState extends StatelessWidget {
  const ApiTodoState({
    super.key,
    required this.title,
    required this.description,
    this.endpoint,
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final String description;

  /// The missing route, e.g. 'GET /notifications'. Shown in debug builds only.
  final String? endpoint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.amberPale,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.amberBrand),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.inkMid,
              ),
            ),
            if (endpoint != null) ...[
              const SizedBox(height: AppSpacing.md),
              _DebugOnly(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(AppRadii.cell),
                  ),
                  child: Text(
                    'TODO(api): $endpoint',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.inkMute,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry affordance, phrased from the [Failure] type.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.failure,
    this.onRetry,
    this.compact = false,
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // The heading is ours and is chosen by failure type, so it translates.
    // `failure.message` below is not: it is whatever the API said, which
    // arrives in English. Localising that is a backend change — see
    // docs/localization.md.
    final (icon, title) = switch (failure) {
      TimeoutFailure() => (Icons.hourglass_empty, l10n.errorTitleTimeout),
      ServerUnavailableFailure() => (
        Icons.cloud_off_outlined,
        l10n.errorTitleServerUnavailable,
      ),
      NetworkFailure() => (
        Icons.wifi_off_outlined,
        l10n.errorTitleNoConnection,
      ),
      UnauthorizedFailure() => (
        Icons.lock_outline,
        l10n.errorTitleUnauthorized,
      ),
      NotFoundFailure() => (Icons.search_off_outlined, l10n.errorTitleNotFound),
      _ => (Icons.error_outline, l10n.errorTitleGeneric),
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 28 : 40, color: AppColors.inkMute),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                height: 1.4,
                color: AppColors.inkMid,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.actionTryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Neutral empty state for a list with nothing in it.
///
/// The only one. There used to be a second — `EmptyState` in
/// `shared_widgets.dart`, one line of grey `bodyMedium` — and the split
/// between them ran exactly the wrong way: the bare sentence was on the four
/// highest-traffic patient surfaces (Home, Find, **Sessions**, Cart) and the
/// designed state on the fifteen quieter ones. A patient with nothing booked
/// got a grey line; a shop category with nothing in stock got an icon, a
/// title and a description.
///
/// [compact] is the same knob [ErrorStateView] already carries, and it is
/// what makes one component enough: a dashboard *section* among five cannot
/// give a 40dp icon and two paragraphs the whole viewport, which is why
/// those sections reached for the bare version in the first place.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Widget? action;

  /// Sized for a card or a section rather than a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 28 : 40, color: AppColors.inkMute),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  height: 1.4,
                  color: AppColors.inkMid,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A one-line failure notice with a Retry, sized for a section rather than a
/// screen.
///
/// [ErrorStateView] centres an icon and two paragraphs and wants the whole
/// viewport; a card that holds one list among five on a dashboard cannot give
/// it that, and the alternative every such section had reached for was to
/// show nothing — which reads as "no data" rather than "we could not ask".
/// Promoted here from `patient_home_screen.dart`, which wrote it first.
class InlineRetry extends StatelessWidget {
  const InlineRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMid),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(context.l10n.actionRetry)),
      ],
    );
  }
}

/// Explains that a control's backend does not exist yet.
///
/// The modal twin of [ApiTodoState], for the case where the *screen* works
/// and one button on it has nowhere to send anything. Six screens had each
/// written this dialog out by hand — same amber `construction_outlined`
/// glyph, same title-and-body, same lone `Got it` — and twelve further
/// controls never got it at all and simply did nothing when tapped.
///
/// A button that looks live and is not is a small lie told every time
/// somebody presses it. This is the house answer to that, and it is only the
/// right answer where there is genuinely nothing to wire to: where a
/// destination exists, wire it, and where the control should never have been
/// drawn, take it out.

Future<void> showUnavailableDialog(
  BuildContext context, {
  required String title,
  required String body,
}) {
  final text = AppTypography.textTheme;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
      icon: const Icon(
        Icons.construction_outlined,
        color: AppColors.amberBrand,
      ),

      title: Text(title, textAlign: TextAlign.center),
      titleTextStyle: text.titleLarge,
      content: Text(body, textAlign: TextAlign.center),
      contentTextStyle: text.bodyMedium!.copyWith(height: 1.45),

      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.pine,
            textStyle: text.titleSmall,
          ),
          child: Text(ctx.l10n.actionGotIt),
        ),
      ],
    ),
  );
}

/// A soft block standing where content is about to be.
///
/// The loading state this file was missing. [ApiTodoState], [ErrorStateView]
/// and [EmptyStateView] cover every other outcome of a fetch; the fourth one
/// was written thirty-nine times instead, almost always as
/// `SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))`
/// — and three screens went further and wrote a private skeleton:
/// `_BalanceSkeleton`, `_SelectSkeleton` and `_CardPlaceholder`, all three a
/// `mist` box with a rounded corner, all three spelled differently. This is
/// that box, once.
///
/// **Deliberately not animated.** A shimmer is the usual reach and it would
/// be wrong twice here: the three skeletons this replaces are static, so
/// animating would be a redesign rather than a consolidation; and an
/// unbounded animation never lets `tester.pumpAndSettle()` return, which is
/// what most of this suite is built on.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 48,
    this.radius = AppRadii.card,
    this.announce = true,
  });

  /// Null means "as wide as the parent allows" — what a list row, a card and
  /// a full-width control all want.
  final double? width;
  final double height;
  final double radius;

  /// Whether this box announces itself to a screen reader.
  ///
  /// False inside [SkeletonList], which announces once for the whole stack:
  /// a reader that says "loading" five times for five placeholder rows is
  /// worse than the silence the spinners left behind.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return announce
        ? Semantics(label: context.l10n.loadingSemantics, child: box)
        : ExcludeSemantics(child: box);
  }
}

/// [count] stacked [SkeletonBox]es, at the gap the lists in this app use.
///
/// Every list that waits is waiting for rows, so the shape of the wait is
/// known and can be drawn — where a centred spinner says only that some time
/// is passing. [count] is the caller's, because three rows and a full page
/// are different claims about how much is coming.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 3,
    this.itemHeight = 72,
    this.gap = AppSpacing.md,
    this.padding = EdgeInsets.zero,
  });

  final int count;
  final double itemHeight;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loadingSemantics,
      container: true,
      // A `ListView`, not a `Column`, and that is the whole reason this is a
      // widget rather than a helper function. Half the loading branches in
      // the app sit inside an `Expanded` and half inside a scroll view, so
      // this is asked for a fixed height in one place and an intrinsic one in
      // the other. A Column overflows the first — four 96dp rows into a 308dp
      // slot is a striped bar, which is what the first run of this found. A
      // shrink-wrapped viewport sizes to its content where there is room and
      // clips where there is not, which is the right answer both times.
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (_, _) => SkeletonBox(height: itemHeight, announce: false),
      ),
    );
  }
}

/// Renders its child only in debug builds.
class _DebugOnly extends StatelessWidget {
  const _DebugOnly({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug ? child : const SizedBox.shrink();
  }
}
