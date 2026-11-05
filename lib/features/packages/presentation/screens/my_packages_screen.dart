import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nav_bars.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/package_purchase.dart';
import '../providers/package_providers.dart';
import '../widgets/active_package_card.dart';

/// The patient's package: one active purchase, plus what they bought before.
///
/// Shell-safe (no [Scaffold] of its own) — mount it under the patient
/// `ShellRoute`. See docs/packages_integration.md.
class MyPackagesScreen extends ConsumerWidget {
  const MyPackagesScreen({super.key, this.onBack, this.onBrowsePackages});

  final VoidCallback? onBack;

  /// Opens the catalogue — used by the empty state and the "buy another" path.
  final VoidCallback? onBrowsePackages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePackageProvider);
    final history = ref.watch(myPackagePurchasesProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: context.l10n.packagesMyTitle, onBack: onBack),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(packageActionsProvider).refreshPurchases(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  navBarReservedHeight,
                ),
                children: [
                  active.when(
                    loading: () => const SkeletonBox(height: 168),
                    // Only a genuine fault reaches here: "no active package" is
                    // a 404 the repository already turns into a null value.
                    error: (e, _) => ErrorStateView(
                      failure: e is Failure ? e : const UnknownFailure(),
                      onRetry: () => ref.invalidate(activePackageProvider),
                    ),
                    data: (purchase) => purchase == null
                        ? _EmptyState(onBrowse: onBrowsePackages)
                        : PackagePurchaseCard(purchase: purchase),
                  ),
                  ..._history(context, ref, history, active.valueOrNull),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Past purchases, if any — expired and used-up packages the patient bought
  /// before. Silently absent while loading or on error: the active card above
  /// is the point of the screen, and a second error box under it would only add
  /// noise.
  List<Widget> _history(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<PackagePurchase>> history,
    PackagePurchase? active,
  ) {
    final all = history.valueOrNull ?? const <PackagePurchase>[];
    final past = all.where((p) => p.id != active?.id).toList();
    if (past.isEmpty) return const [];

    return [
      const SizedBox(height: 24),
      Text(
        context.l10n.packagesPast,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 8),
      for (final purchase in past) ...[
        _PastPurchaseRow(purchase: purchase),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: EmptyStateView(
        title: context.l10n.packagesNoActiveTitle,
        description: context.l10n.packagesNoActiveDesc,
        icon: Icons.card_giftcard_outlined,
        action: onBrowse == null
            ? null
            : AppButton.text(
                context.l10n.packagesBrowse,
                onPressed: onBrowse,
              ),
      ),
    );
  }
}

class _PastPurchaseRow extends StatelessWidget {
  const _PastPurchaseRow({required this.purchase});

  final PackagePurchase purchase;

  @override
  Widget build(BuildContext context) {
    final expiresAt = purchase.expiresAt;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  purchase.packageName.isEmpty
                      ? context.l10n.packagesFallbackName
                      : purchase.packageName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.packagesSessionsUsed(
                        purchase.sessionsUsed,
                        purchase.sessionsTotal,
                      ) +
                      (expiresAt == null
                          ? ''
                          : ' · ${context.l10n.packagesExpiredOn(formatShortDate(expiresAt, context.l10n))}'),
                  style: const TextStyle(fontSize: 11, color: AppColors.inkMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusTag(
            label: purchase.status.isEmpty
                ? context.l10n.packagesClosed
                : purchase.status,
            tone: TagTone.neutral,
          ),
        ],
      ),
    );
  }
}
