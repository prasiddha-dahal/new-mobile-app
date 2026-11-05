import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/product.dart';
import '../providers/shop_providers.dart';
import '../shop_labels.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  /// Product id showing the transient "✓ Added" confirmation.
  String? _justAdded;

  /// Ids with an add-to-cart request in flight.
  final _adding = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final category = ref.watch(shopCategoryProvider);
    final products = ref.watch(productListProvider);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back arrow + cart.
            //
            // The shop is a root route: it owns the whole viewport and the
            // bottom bar is not under it, so Back must always lead somewhere.
            // Same fallback `ClinicListScreen` uses.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/patient/home'),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.push('/cart'),
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 26,
                          color: AppColors.ink,
                        ),
                      ),
                      // Badge reflects the server-side cart, so it survives a
                      // restart and matches what the cart screen shows.
                      if (cartCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(
                                AppRadii.full,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$cartCount',
                              style: text.bodySmall!.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                color: AppColors.mist,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Title. The mono eyebrow (`shopEyebrow`) is dropped: the settled
            // look has no eyebrow labels.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: Text(
                l10n.shopTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
            ),

            // Category chips: selected = ink fill, unselected = mist.
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: ProductCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = ProductCategory.values[i];
                  final active = category == c;
                  return GestureDetector(
                    onTap: () =>
                        ref.read(shopCategoryProvider.notifier).state = c,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: active ? AppColors.ink : AppColors.mist,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        productCategoryLabel(c, l10n),
                        style: text.titleSmall!.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: active ? Colors.white : AppColors.inkMid,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            // Products grid
            Expanded(
              child: products.when(
                loading: () => const SkeletonList(
                  count: 3,
                  itemHeight: 172,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(productListProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyStateView(
                      title: l10n.shopNothingHere,
                      description: l10n.shopNothingHereDesc(
                        productCategoryLabel(category, l10n).toLowerCase(),
                      ),
                      icon: Icons.inventory_2_outlined,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productListProvider);
                      ref.invalidate(cartProvider);
                    },
                    child: GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.xxl,
                      ),
                      // A fixed row height instead of an aspect ratio: the
                      // card now holds an image, two text blocks and a
                      // button, and a ratio clips them on narrow phones or
                      // large text sizes.
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 266,
                          ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: items[i],
                        busy: _adding.contains(items[i].id),
                        justAdded: _justAdded == items[i].id,
                        onAdd: () => _add(items[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(Product product) async {
    setState(() => _adding.add(product.id));
    final result = await ref.read(shopActionsProvider).add(product);
    if (!mounted) return;
    setState(() => _adding.remove(product.id));

    result.match(
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.danger,
          ),
        ),
      (_) {
        setState(() => _justAdded = product.id);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted && _justAdded == product.id) {
            setState(() => _justAdded = null);
          }
        });
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.busy,
    required this.justAdded,
    required this.onAdd,
  });

  final Product product;
  final bool busy;
  final bool justAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area, mint tint. Stock tag sits on its corner.
          Stack(
            children: [
              Container(
                height: 104,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColors.pinePale.withAlpha(150),
                    Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                alignment: Alignment.center,
                // TODO(design): products carry an imageUrl but there is no
                // asset pipeline for them yet, so the emoji stands in as the
                // placeholder.
                child: Text(p.emoji, style: const TextStyle(fontSize: 40)),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: StatusTag(
                  label: p.isAvailable ? l10n.shopInStock : l10n.shopOut,
                  tone: p.isAvailable ? TagTone.green : TagTone.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              p.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(
                fontSize: 12,
                height: 1.35,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  formatCurrency(p.displayPrice, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (p.priceSuffix.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  p.priceSuffix,
                  style: text.bodySmall!.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: (!p.isAvailable || busy) ? null : onAdd,
              style: ElevatedButton.styleFrom(
                // Pine primary; the brief "added" state flips to pale mint.
                backgroundColor: justAdded
                    ? AppColors.pinePale
                    : AppColors.pine,
                foregroundColor: justAdded ? AppColors.pine : Colors.white,
                disabledBackgroundColor: AppColors.pine.withAlpha(90),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                textStyle: text.titleSmall!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.row),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      justAdded
                          ? l10n.shopAdded
                          : p.category.isRental
                          ? l10n.shopRent
                          : l10n.shopAddToCart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}