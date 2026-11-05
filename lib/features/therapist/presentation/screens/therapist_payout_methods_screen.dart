import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';

class TherapistPayoutMethodsScreen extends StatelessWidget {
  const TherapistPayoutMethodsScreen({super.key});

  /// TODO(api): therapist payout methods (A15 in docs/TODO_REGISTER.md).
  /// Payouts are arranged with the admin team today, which is what the
  /// Earnings screen's own request button already says.
  static void _payoutUnavailable(BuildContext context) =>
      showUnavailableDialog(
        context,
        title: context.l10n.payoutAddUnavailableTitle,
        body: context.l10n.payoutAddUnavailableBody,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              PageHeader(
                title: l10n.payoutMethodsTitle,
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              // There is no payout store yet (the Add buttons below say so),
              // so nothing here can be a real account. This slot used to show
              // a configured eSewa wallet -- 98XXXXXXXX21, green tick, "paid
              // automatically every Friday" -- which is exactly the thing a
              // therapist would rely on and never think to check.
              SectionHeader(title: l10n.payoutPrimaryMethod),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: EmptyStateView(
                    compact: true,
                    icon: Icons.account_balance_wallet_outlined,
                    title: l10n.payoutNoneTitle,
                    description: l10n.payoutNoneBody,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.payoutOtherMethods),
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.mist,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🏦', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.payoutBankTransfer,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _payoutUnavailable(context),
                        child: Text(
                          l10n.actionAdd,
                          style: const TextStyle(color: AppColors.pine),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _payoutUnavailable(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.payoutAddNew),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
