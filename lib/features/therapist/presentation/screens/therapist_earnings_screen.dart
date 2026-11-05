import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';

class TherapistEarningsScreen extends ConsumerWidget {
  const TherapistEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboard = ref.watch(therapistDashboardProvider);
    final transactions = ref.watch(transactionsProvider);
    final payouts = ref.watch(payoutsProvider);

    final payoutList = payouts.valueOrNull ?? const <PayoutDto>[];
    // Payout rows are synthesized per month server-side; "pending" is whatever
    // has not been settled, and lifetime is every month added up.
    final pending = payoutList
        .where((p) => p.status.toUpperCase() == 'PENDING')
        .fold<double>(0, (sum, p) => sum + p.earnings);
    final lifetime = payoutList.fold<double>(0, (sum, p) => sum + p.earnings);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(therapistDashboardProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(payoutsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.therapistKpiEarnings.toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.earningsTitle,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Earnings summary card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.pine, AppColors.pineLight],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.earningsThisMonth,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dashboard.valueOrNull == null
                              ? '—'
                              : formatCurrency(
                                  dashboard.value!.earningsThisMonth,
                                  context.l10n,
                                ),
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryStat(
                                label: l10n.earningsPending,
                                value: payouts.valueOrNull == null
                                    ? '—'
                                    : formatCurrency(pending, context.l10n),
                              ),
                            ),
                            Expanded(
                              child: _SummaryStat(
                                label: l10n.earningsLifetime,
                                value: payouts.valueOrNull == null
                                    ? '—'
                                    : formatCurrency(lifetime, context.l10n),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _payoutUnavailable(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amberBrand,
                              foregroundColor: AppColors.ink,
                            ),
                            child: Text(l10n.earningsRequestPayout),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SectionHeader(title: l10n.earningsTransactions),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: transactions.when(
                    loading: () => const SkeletonList(count: 3, itemHeight: 64),
                    error: (e, _) => ErrorStateView(
                      failure: e is Failure ? e : const UnknownFailure(),
                      onRetry: () => ref.invalidate(transactionsProvider),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return EmptyStateView(
                          title: l10n.earningsNoTransactions,
                          description: l10n.earningsNoTransactionsDesc,
                          icon: Icons.receipt_long_outlined,
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                              _TransactionRow(tx: list[i]),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                SectionHeader(title: l10n.earningsPayoutMethod),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Text('💚', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // No endpoint stores a payout account, so the
                              // prototype's masked wallet number is gone
                              // rather than shown as if it were real.
                              // TODO(api): payout account on the profile.
                              Text(
                                l10n.earningsNoPayoutMethod,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                l10n.earningsArrangedByAdmin,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push('/therapist/payout-methods'),
                          child: Text(
                            l10n.actionChange,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.pine,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Payouts are settled off-app; there is no request endpoint.
  /// TODO(api): payout request.
  static void _payoutUnavailable(BuildContext context) =>
      showUnavailableDialog(
        context,
        title: context.l10n.earningsPayoutUnavailableTitle,
        body: context.l10n.earningsPayoutUnavailableBody,
      );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});
  final TransactionDto tx;

  @override
  Widget build(BuildContext context) {
    final paid =
        tx.paymentStatus.toUpperCase() == 'COMPLETED' ||
        tx.paymentStatus.toUpperCase() == 'PAID';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ProfileAvatar(
            initials: getInitials(tx.patientName),
            photoUrl: tx.patientPhoto,
            thumbUrl: tx.patientPhotoThumb,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  [
                    if (tx.date.isNotEmpty) formatDayLabelFromString(tx.date, context.l10n),
                    if (tx.paymentMethod.isNotEmpty) tx.paymentMethod,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.l10n.earningsCredit(
                  formatCurrency(tx.fee, context.l10n),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.pine,
                ),
              ),
              if (!paid)
                Text(
                  tx.paymentStatus.toLowerCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.inkMute,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
