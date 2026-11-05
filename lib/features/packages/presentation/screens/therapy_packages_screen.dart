import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nav_bars.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/package_providers.dart';
import '../widgets/package_card.dart';
import '../widgets/package_detail_sheet.dart';

/// The package catalogue.
///
/// Shell-safe: returns no [Scaffold] of its own because `PatientShell` already
/// provides one. Mount it under the patient `ShellRoute` — see
/// docs/packages_integration.md.
class TherapyPackagesScreen extends ConsumerStatefulWidget {
  const TherapyPackagesScreen({super.key, this.onBack, this.onViewMyPackages});

  /// Back affordance. Null hides the arrow, for a tab-mounted use.
  final VoidCallback? onBack;

  /// Opens My packages after a successful purchase.
  final VoidCallback? onViewMyPackages;

  @override
  ConsumerState<TherapyPackagesScreen> createState() =>
      _TherapyPackagesScreenState();
}

class _TherapyPackagesScreenState extends ConsumerState<TherapyPackagesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(packageSearchProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Filtering is local, but the debounce still earns its keep: it keeps every
  /// keystroke from rebuilding the whole list.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref.read(packageSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final catalogue = ref.watch(packageCatalogueProvider);
    final query = ref.watch(packageSearchProvider);
    final activeTag = ref.watch(packageTagFilterProvider);
    final activePurchase = ref.watch(activePackageProvider).valueOrNull;

    final tags = catalogue.valueOrNull?.tags ?? const <String>[];
    final showChips = catalogue.valueOrNull?.hasUsefulTagFilter ?? false;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IconButton(
                onPressed: widget.onBack,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: AppColors.ink,
                ),
              ),
            )
          else
            const SizedBox(height: 8),

          // Title and the door to My packages. That pill is the only way to
          // `/patient/packages/mine`, so it stays on this screen.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.packagesCatalogueTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge!.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.onViewMyPackages != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: _MyPackagesPill(onTap: widget.onViewMyPackages!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.packagesCatalogueSubtitle,
                  style: text.bodyMedium!.copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),

          if (showChips) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: tags.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final label = i == 0 ? l10n.filterAll : tags[i - 1];
                  final selected = i == 0
                      ? activeTag == null
                      : activeTag == tags[i - 1];
                  return _TagChip(
                    label: label,
                    selected: selected,
                    onTap: () =>
                        ref.read(packageTagFilterProvider.notifier).state =
                            i == 0 ? null : tags[i - 1],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),

          Expanded(
            child: catalogue.when(
              loading: () => const SkeletonList(
                count: 3,
                itemHeight: 196,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
              ),
              // A 404 here means the packages endpoints are not deployed yet;
              // it reads as "Not found" with a retry rather than a crash.
              error: (e, _) => ErrorStateView(
                failure: e is Failure ? e : const UnknownFailure(),
                onRetry: () => ref.invalidate(packageCatalogueProvider),
              ),
              data: (_) {
                final items = ref.watch(filteredPackagesProvider);
                if (items.isEmpty) {
                  return EmptyStateView(
                    title: query.isEmpty
                        ? l10n.packagesEmptyTitle
                        : l10n.packagesNoMatch(query),
                    description: query.isEmpty
                        ? l10n.packagesEmptyDesc
                        : l10n.packagesNoMatchDesc,
                    icon: query.isEmpty
                        ? Icons.card_giftcard_outlined
                        : Icons.search_off_outlined,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    navBarReservedHeight,
                  ),
                  children: [
                    // One active package at a time is a backend rule: a second
                    // purchase is refused with 400. Saying so up front beats
                    // letting the patient reach the confirm step and bounce.
                    if (activePurchase != null &&
                        activePurchase.isUsableAt(DateTime.now())) ...[
                      _ActivePackageNotice(
                        name: activePurchase.packageName,
                        sessionsRemaining: activePurchase.sessionsRemaining,
                        onView: widget.onViewMyPackages,
                      ),
                      const SizedBox(height: 14),
                    ],
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      PackageCard(
                        package: items[i],
                        tintIndex: i,
                        onView: () => showPackageDetailSheet(
                          context,
                          package: items[i],
                          tintIndex: i,
                          onViewMyPackages: widget.onViewMyPackages,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── My packages pill ─────────────────────────────────────────────────

class _MyPackagesPill extends StatelessWidget {
  const _MyPackagesPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.pinePale,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              // Shrinks rather than ellipsises, so a long Nepali phrase stays
              // whole at a slightly smaller size. At an ordinary size
              // `scaleDown` does nothing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: AppColors.pine,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.packagesMyTitle,
                      maxLines: 1,
                      softWrap: false,
                      style: text.titleSmall!.copyWith(
                        fontSize: 13,
                        color: AppColors.pine,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Active package notice ────────────────────────────────────────────

class _ActivePackageNotice extends StatelessWidget {
  const _ActivePackageNotice({
    required this.name,
    required this.sessionsRemaining,
    this.onView,
  });

  final String name;
  final int sessionsRemaining;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.amberPale,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.amberBrand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.packagesAlreadyActive(name, sessionsRemaining),
              style: text.bodyMedium!.copyWith(
                fontSize: 13,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
          ),
          if (onView != null)
            TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pine,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: text.titleSmall,
              ),
              child: Text(context.l10n.actionView),
            ),
        ],
      ),
    );
  }
}

// ── Search ───────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 22, color: AppColors.inkMid),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: text.bodyMedium!.copyWith(color: AppColors.ink),
              decoration: InputDecoration(
                hintText: context.l10n.packagesSearchHint,
                hintStyle: text.bodyMedium!.copyWith(color: AppColors.inkMid),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                fillColor: Colors.transparent,
                filled: false,
              ),
            ),
          ),
          // Clear button. Listens to the controller so it appears as soon as
          // there is text.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 8);
              return GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.mist,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Text(
          label,
          style: text.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.inkMid,
          ),
        ),
      ),
    );
  }
}