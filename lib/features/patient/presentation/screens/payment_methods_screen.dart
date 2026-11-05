import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';

/// Manage wallets.
///
/// There is no per-user payment-method vault — `/settings/payment-methods` is
/// platform-level configuration, not the caller's saved wallets. Nothing is
/// stored today, and no payment is actually captured either, so this screen
/// says so instead of showing invented masked numbers.
/// TODO(api): per-user payment methods (A10), real gateway capture (A18).
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            PageHeader(
              title: l10n.paymentMethodsTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/patient/account'),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: ApiTodoState(
                title: l10n.paymentWalletsSoonTitle,
                description: l10n.paymentWalletsSoonDesc,
                endpoint: 'per-user payment methods',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amberPale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: Color(0xFF8A5A14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.paymentRecordedOnly,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Color(0xFF8A5A14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
