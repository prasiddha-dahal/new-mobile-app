import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/models/points_models.dart';
import '../providers/points_providers.dart';

/// Balance, referral invite, referral history and the ledger.
class MyPointsScreen extends ConsumerWidget {
  const MyPointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppTypography.textTheme;
    final balance = ref.watch(pointBalanceProvider);
    final referrals = ref.watch(referralSummaryProvider);
    final activity = ref.watch(pointTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pointBalanceProvider);
            ref.invalidate(referralSummaryProvider);
            ref.invalidate(pointTransactionsProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              40,
            ),
            children: [
              // Back arrow
              AppBackButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/patient/account'),
                    gutter: false,
              ),
              Text(
                context.l10n.rewardsTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              balance.when(
                loading: () => const SkeletonBox(height: 168),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(pointBalanceProvider),
                ),
                data: (b) => _BalanceCard(balance: b),
              ),

              const SizedBox(height: AppSpacing.xl),
              referrals.when(
                loading: () => const SizedBox.shrink(),
                // This card used to vanish on a failed load — code, copy
                // button, earnings figure and all — leaving a screen that
                // looked like a user who had never referred anyone. The
                // history block below stays silent on purpose: one retry for
                // one provider is enough, and it refills both.
                error: (_, _) => InlineRetry(
                  message: context.l10n.rewardsCouldNotLoadReferral,
                  onRetry: () => ref.invalidate(referralSummaryProvider),
                ),
                data: (summary) => _InviteCard(summary: summary),
              ),

              const SizedBox(height: AppSpacing.xxl),
              _Heading(context.l10n.rewardsHowToUse),
              const SizedBox(height: AppSpacing.md),
              const _HowToUseCard(),

              const SizedBox(height: AppSpacing.xxl),
              referrals.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (summary) => summary.referrals.isEmpty
                    ? const SizedBox.shrink()
                    : _ReferralHistory(entries: summary.referrals),
              ),

              const SizedBox(height: AppSpacing.xxl),
              _Heading(context.l10n.rewardsRecentActivity),
              const SizedBox(height: AppSpacing.md),
              activity.when(
                loading: () => const SkeletonList(count: 3, itemHeight: 64),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(pointTransactionsProvider),
                ),
                data: (list) => list.transactions.isEmpty
                    ? EmptyStateView(
                        title: context.l10n.rewardsNothingYet,
                        description: context.l10n.rewardsNothingYetDesc,
                        icon: Icons.receipt_long_outlined,
                      )
                    : _ActivityList(rows: list.transactions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading: bold Inter 18, in place of the mono small-caps label.
class _Heading extends StatelessWidget {
  const _Heading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.textTheme.titleMedium!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: AppColors.ink,
      ),
    );
  }
}

/// White card with the thin border.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final PointBalanceDto balance;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.pine, AppColors.pineLight],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.rewardsYourBalance,
            style: text.bodyMedium!.copyWith(
              fontSize: 13,
              letterSpacing: 0,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.rewardsPoints(balance.balance),
            style: text.titleLarge!.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.rewardsCreditValue(
              formatCurrency(balance.creditValue, context.l10n),
            ),
            style: text.bodyMedium!.copyWith(
              fontSize: 13,
              letterSpacing: 0,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (balance.pending > 0) ...[
            const SizedBox(height: 6),
            Text(
              // Held points are the commonest support question, so they are
              // stated rather than silently missing from the balance.
              context.l10n.rewardsPending(balance.pending),
              style: text.bodySmall!.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Stat(
                value: '${balance.earned}',
                label: context.l10n.rewardsStatEarned,
              ),
              _Stat(
                value: '${balance.used}',
                label: context.l10n.rewardsStatUsed,
              ),
              _Stat(
                value: '${balance.referred}',
                label: context.l10n.rewardsStatReferred,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: text.titleMedium!.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(
              fontSize: 12,
              letterSpacing: 0,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.summary});
  final ReferralSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final amount = formatCurrency(summary.awardPoints.toDouble(), context.l10n);
    final earned = formatCurrency(summary.totalEarned.toDouble(), context.l10n);

    TextStyle label() => text.bodyMedium!.copyWith(
      fontSize: 13,
      letterSpacing: 0,
      color: AppColors.inkMid,
    );

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.referralTotalEarned, style: label()),
          const SizedBox(height: 4),
          Text(
            earned,
            style: text.titleLarge!.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // One-sided, and the trigger is a completed booking rather than a
            // signup -- both as the prototype states them.
            context.l10n.therapistReferralPitch(amount),
            style: text.bodyMedium!.copyWith(
              fontSize: 13,
              height: 1.45,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(context.l10n.referralYourCode, style: label()),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                AppColors.pinePale.withAlpha(150),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary.code.isEmpty ? '—' : summary.code,
                    style: text.titleMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                // Pine, not amber: amber is for commercial actions.
                TextButton(
                  onPressed: summary.code.isEmpty
                      ? null
                      : () => _copy(context, summary.code),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pine,
                    textStyle: text.titleSmall!.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(context.l10n.actionCopy),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: summary.link.isEmpty
                  ? null
                  : () => _copy(
                      context,
                      summary.link,
                      message: context.l10n.referralLinkCopied,
                    ),
              // Copies rather than opening a share sheet: no share plugin is
              // in the project, and a copied link works in every app people
              // actually send invites through here.
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pine,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.pine.withAlpha(90),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                // Buttons default to labelLarge (mono, spaced).
                textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: Text(context.l10n.rewardsCopyInviteLink),
            ),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value, {String? message}) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message ?? context.l10n.rewardsCodeCopied)),
      );
  }
}

/// Points are spent during booking, not minted into vouchers here — so this
/// explains where they apply instead of offering a Redeem button that would
/// have nothing to attach to.
class _HowToUseCard extends StatelessWidget {
  const _HowToUseCard();

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in place of the gift emoji.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                AppColors.pinePale.withAlpha(150),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.card_giftcard_outlined,
              size: 22,
              color: AppColors.pine,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.rewardsUsePoints,
                  style: text.titleSmall!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.rewardsUsePointsDesc,
                  style: text.bodyMedium!.copyWith(
                    fontSize: 13,
                    height: 1.45,
                    letterSpacing: 0,
                    color: AppColors.inkMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralHistory extends StatelessWidget {
  const _ReferralHistory({required this.entries});
  final List<ReferralEntryDto> entries;

  static (String, TagTone) _badge(String state, AppLocalizations l10n) =>
      switch (state) {
        'REWARDED' => (l10n.referralStateRewarded, TagTone.green),
        'PENDING' => (l10n.referralStatePending, TagTone.amber),
        'REVERSED' => (l10n.referralStateReversed, TagTone.red),
        'INVITED' => (l10n.referralStateInvited, TagTone.neutral),
        _ => (l10n.referralStateJoined, TagTone.neutral),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(context.l10n.rewardsReferralHistory),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _ReferralRow(entry: entries[i], tintIndex: i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow({required this.entry, required this.tintIndex});
  final ReferralEntryDto entry;
  final int tintIndex;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final (label, tone) = _ReferralHistory._badge(entry.state, context.l10n);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          AppAvatar(
            initials: getInitials(entry.name),
            tint: tintIndex.isEven ? AppColors.pinePale : AppColors.amberPale,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
          ),
          StatusTag(label: label, tone: tone),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            child: Text(
              entry.points == null
                  ? '—'
                  : context.l10n.rewardsPointsGain(entry.points!),
              textAlign: TextAlign.right,
              style: text.titleSmall!.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: entry.points == null
                    ? AppColors.inkMute
                    : AppColors.pine,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.rows});
  final List<PointTransactionDto> rows;

  /// `row.reason` is the server's own sentence and wins when it is set; it
  /// arrives in English, like every other server string.
  static String _label(PointTransactionDto row, AppLocalizations l10n) {
    if ((row.reason ?? '').isNotEmpty) return row.reason!;
    return switch (row.type) {
      'REFERRAL_EARN' => l10n.rewardsReasonReferral,
      'PROMO_GRANT' => l10n.rewardsReasonBonus,
      'REDEMPTION' => l10n.rewardsReasonRedeemed,
      'ADJUSTMENT' => l10n.rewardsReasonAdjustment,
      'EXPIRY' => l10n.rewardsReasonExpired,
      _ => l10n.rewardsReasonOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _ActivityRow(row: rows[i], label: _label(rows[i], context.l10n)),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.row, required this.label});
  final PointTransactionDto row;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.titleSmall!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
                if (row.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatShortDate(row.createdAt!, context.l10n),
                    style: text.bodySmall!.copyWith(
                      fontSize: 12,
                      letterSpacing: 0,
                      color: AppColors.inkMid,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.l10n.rewardsPointsDelta(
                  row.isCredit ? '+' : '',
                  row.delta,
                ),
                style: text.titleSmall!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: row.isCredit ? AppColors.pine : AppColors.danger,
                ),
              ),
              if (row.isHeld)
                Text(
                  // The shared key is uppercase because it is a badge
                  // everywhere else; here it is a whispered footnote under an
                  // amount, and Devanagari has no case to lose.
                  context.l10n.referralStatePending.toLowerCase(),
                  style: text.bodySmall!.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    color: AppColors.inkMid,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
