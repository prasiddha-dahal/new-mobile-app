import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/care_providers.dart';

/// Refer & earn.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final referral = ref.watch(referralProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            PageHeader(
              title: l10n.referralTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/patient/account'),
            ),
            const SizedBox(height: 16),

            // --- Earnings ----------------------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.pine, Color(0xFF3B7364)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.referralTotalEarned,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // TODO(api): there is no referral earnings ledger — only the
                  // code and link are returned. A real total needs A14.
                  Text(
                    // Zero is still a currency amount: through the formatter
                    // it reads `Rs ०` in Nepali rather than a Latin `Rs 0`
                    // in the middle of a Devanagari card.
                    formatCurrency(0, context.l10n),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontSerif,
                      fontSize: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.referralPitch,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Code + share -------------------------------------------------
            referral.when(
              loading: () => const SkeletonBox(height: 188),
              error: (e, _) => AppCard(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(referralProvider),
                  compact: true,
                ),
              ),
              data: (data) => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.referralYourCode,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pinePale,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(
                          color: AppColors.pine.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.code.isEmpty ? '—' : data.code,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.6,
                                color: AppColors.pine,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: data.code.isEmpty
                                ? null
                                : () => _copy(context, data.code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pine,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.actionCopy,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ShareTile(
                          emoji: '📱',
                          label: l10n.shareViaSms,
                          onTap: () => _copy(context, data.link, isLink: true),
                        ),
                        const SizedBox(width: 8),
                        _ShareTile(
                          emoji: '💬',
                          label: l10n.shareViaWhatsapp,
                          onTap: () => _copy(context, data.link, isLink: true),
                        ),
                        const SizedBox(width: 8),
                        _ShareTile(
                          emoji: '🔗',
                          label: l10n.shareGeneric,
                          onTap: () => _copy(context, data.link, isLink: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Invites ------------------------------------------------------
            Text(
              l10n.referralYourInvites,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            AppCard(
              child: ApiTodoState(
                title: l10n.referralInvitesSoonTitle,
                description: l10n.referralInvitesSoonDesc,
                endpoint: 'GET /patients/me/referral (invites + earnings)',
                icon: Icons.group_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sharing needs a share/url-launcher plugin that is not a dependency yet, so
  /// the value is copied to the clipboard instead of silently doing nothing.
  /// TODO(design): decide whether to add share_plus for native share sheets.
  static void _copy(BuildContext context, String value, {bool isLink = false}) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isLink
                ? context.l10n.referralLinkCopied
                : context.l10n.referralCodeCopied,
          ),
        ),
      );
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
