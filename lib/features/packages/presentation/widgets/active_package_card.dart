import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../domain/entities/package_purchase.dart';
import '../providers/package_providers.dart';
import 'package_visuals.dart';

/// Drop-in card for the patient home screen: "if a patient has a package
/// enabled, it should be displayed on the home page".
///
/// Self-contained — it reads [activePackageProvider] itself, so mounting it is
/// one line with no plumbing. It renders **nothing** while loading, when the
/// patient has no active package, and when the call fails: the home screen is
/// not the place to argue about a missing optional endpoint (and `/active`
/// answers 404 for "no package", which the repository already turns into an
/// empty success). My packages is where the error is worth showing.
class ActivePackageCard extends ConsumerWidget {
  const ActivePackageCard({super.key, this.onOpen});

  /// Wired by the integrator to open My packages.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(activePackageProvider).valueOrNull;
    if (purchase == null) return const SizedBox.shrink();
    if (!purchase.isUsableAt(DateTime.now())) return const SizedBox.shrink();

    return PackagePurchaseCard(
      purchase: purchase,
      compact: true,
      onTap: onOpen,
    );
  }
}

/// The purchase itself, rendered.
///
/// [compact] is the home-screen form (name, progress, sessions left). The full
/// form adds the start/end dates and the next booked session, which is what the
/// My packages screen shows.
class PackagePurchaseCard extends StatelessWidget {
  const PackagePurchaseCard({
    super.key,
    required this.purchase,
    this.compact = false,
    this.onTap,
  });

  final PackagePurchase purchase;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final expired = purchase.isExpiredAt(now);
    final nextSession = purchase.nextSessionAt(now);

    final (String statusLabel, TagTone statusTone) = switch (purchase) {
      _ when expired => (l10n.packageStatusExpired, TagTone.red),
      _ when purchase.isActive => (l10n.packageStatusActive, TagTone.green),
      _ when purchase.isDepleted => (
        l10n.packageStatusUsedUp,
        TagTone.neutral,
      ),
      _ => (
        purchase.status.isEmpty ? l10n.packageStatusUnknown : purchase.status,
        TagTone.neutral,
      ),
    };

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.packageName.isEmpty
                          ? l10n.packagesFallbackName
                          : purchase.packageName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _validityLine(purchase, now, expired, l10n),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                l10n.packagesSessionsUsed(
                  purchase.sessionsUsed,
                  purchase.sessionsTotal,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                l10n.packagesProgressPercent(purchase.progressPercent),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PackageProgressBar(value: purchase.progress),
          const SizedBox(height: 8),
          Text(
            l10n.packagesSessionsRemaining(purchase.sessionsRemaining),
            style: const TextStyle(fontSize: 11, color: AppColors.inkMid),
          ),
          if (!compact) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetaBlock(
                    label: 'STARTED',
                    value: _dateOrDash(purchase.purchasedAt, context.l10n),
                  ),
                ),
                Expanded(
                  child: _MetaBlock(
                    label: 'ENDS',
                    value: _dateOrDash(purchase.expiresAt, context.l10n),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Row(
                children: [
                  Icon(
                    nextSession == null
                        ? Icons.event_available_outlined
                        : Icons.event_outlined,
                    size: 16,
                    color: AppColors.pine,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextSession == null
                          // The detail response carries every session booked
                          // against the purchase; none of them being upcoming
                          // is a real, common state, not missing data.
                          ? l10n.packagesNoUpcoming
                          : l10n.packagesNextSession(
                                  formatDayLabelFromString(
                                    nextSession.rawDate,
                                    l10n,
                                  ),
                                ) +
                                (nextSession.time.isEmpty
                                    ? ''
                                    : ' · ${nextSession.time}') +
                                (nextSession.therapistName.isEmpty
                                    ? ''
                                    : ' · ${nextSession.therapistName}'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateOrDash(DateTime? date, AppLocalizations l10n) =>
      date == null ? '—' : formatShortDate(date, l10n);

  /// "Valid until Tue, 7 Jul · 12 days left", degrading to whatever is known.
  static String _validityLine(
    PackagePurchase purchase,
    DateTime now,
    bool expired,
    AppLocalizations l10n,
  ) {
    final end = purchase.expiresAt;
    if (end == null) return l10n.packagesValidityUnset;
    if (expired) {
      return l10n.packagesExpiredOn(formatShortDate(end, l10n));
    }
    final days = purchase.daysRemainingAt(now);
    final left = days == 0
        ? l10n.packagesExpiresToday
        : l10n.packagesDaysLeft(days);
    return l10n.packagesValidUntil(formatShortDate(end, l10n), left);
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
