import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/system_bar_inset.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/product.dart';
import '../providers/shop_providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _busy = <String>{};
  bool _checkingOut = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final cart = ref.watch(cartProvider);
    final lines = cart.valueOrNull?.lines ?? const <CartLine>[];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back arrow.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
              child: IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/shop'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: AppColors.ink,
                ),
              ),
            ),
            // Title, with the item count on the right once the cart loads.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l10n.cartTitle,
                      style: text.titleLarge!.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (cart.valueOrNull != null)
                    Text(
                      l10n.cartItemCount(lines.length),
                      style: text.bodySmall!.copyWith(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: AppColors.inkMid,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cart.when(
                loading: () => const SkeletonList(
                  count: 3,
                  itemHeight: 104,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(cartProvider),
                ),
                data: (c) {
                  if (c.isEmpty) {
                    return EmptyStateView(
                      title: l10n.cartEmpty,
                      icon: Icons.shopping_cart_outlined,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(cartProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      children: [
                        ...c.lines.map(
                          (line) => _CartItemCard(
                            line: line,
                            busy: _busy.contains(line.id),
                            onQtyChanged: (qty) => _setQuantity(line, qty),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              _SummaryRow(
                                label: l10n.cartSubtotal,
                                value: formatCurrency(c.subtotal, l10n),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _SummaryRow(
                                label: l10n.cartDelivery,
                                value: formatCurrency(c.deliveryFee, l10n),
                              ),
                              // The prototype also showed a refundable
                              // deposit. The cart response has no deposit
                              // field, so the row is omitted rather than
                              // showing a number the backend never charges.
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                              ),
                              _SummaryRow(
                                label: l10n.cartTotal,
                                value: formatCurrency(c.grandTotal, l10n),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Mounted only when there is something to check out. It used to be
      // unconditional, so a disabled checkout bar sat over the loading
      // spinner, over the error state with its retry, and over "your cart is
      // empty" — offering an action on a screen with nothing to act on, and
      // covering the one control that was live. Every other fixed CTA in the
      // app (booking, therapist profile) is already conditional.
      bottomSheet: lines.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              color: AppColors.cream,
              child: SystemBarInset(
                inset: SystemBarInset.of(context),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _checkingOut ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pine,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.pine.withAlpha(90),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: _checkingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.cartCheckout),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _setQuantity(CartLine line, int qty) async {
    setState(() => _busy.add(line.id));
    final result = await ref
        .read(shopActionsProvider)
        .setQuantity(itemId: line.id, quantity: qty);
    if (!mounted) return;
    setState(() => _busy.remove(line.id));
    result.match((f) => _toast(f.message, isError: true), (_) {});
  }

  Future<void> _checkout() async {
    setState(() => _checkingOut = true);
    final result = await ref.read(shopActionsProvider).checkout();
    if (!mounted) return;
    setState(() => _checkingOut = false);

    final text = AppTypography.textTheme;

    result.match(
      // Ordering is not switched on server-side; the failure carries the
      // explanation, so nothing here pretends the order went through.
      (failure) => showDialog<void>(
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
          title: Text(context.l10n.cartCheckoutUnavailable),
          titleTextStyle: text.titleLarge!.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: AppColors.ink,
          ),
          content: Text(failure.message),
          contentTextStyle: text.bodyMedium!.copyWith(
            height: 1.45,
            letterSpacing: 0,
            color: AppColors.inkMid,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pine,
                textStyle: text.titleSmall!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              child: Text(context.l10n.actionGotIt),
            ),
          ],
        ),
      ),
      (_) => context.go('/order-success'),
    );
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.line,
    required this.busy,
    required this.onQtyChanged,
  });

  final CartLine line;
  final bool busy;
  final void Function(int) onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Mint-tinted tile; the emoji is product data.
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  AppColors.pinePale.withAlpha(150),
                  Colors.white,
                ),
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              alignment: Alignment.center,
              child: Text(p.emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.description ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      fontSize: 12,
                      letterSpacing: 0,
                      color: AppColors.inkMid,
                    ),
                  ),
                  if (line.isRental)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mist,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        context.l10n.cartRentalDays(line.rentalDays),
                        style: text.bodySmall!.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(line.lineTotal, context.l10n),
                  style: text.titleSmall!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Quantity stepper: mist pill.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: busy
                            ? null
                            : () => onQtyChanged(line.quantity - 1),
                        icon: const Icon(Icons.remove, size: 16),
                        style: _stepperButtonStyle,
                        color: AppColors.ink,
                      ),
                      SizedBox(
                        width: 22,
                        child: Center(
                          child: busy
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.pine,
                                  ),
                                )
                              : Text(
                                  '${line.quantity}',
                                  style: text.titleSmall!.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    color: AppColors.ink,
                                  ),
                                ),
                        ),
                      ),
                      IconButton(
                        onPressed: busy
                            ? null
                            : () => onQtyChanged(line.quantity + 1),
                        icon: const Icon(Icons.add, size: 16),
                        style: _stepperButtonStyle,
                        color: AppColors.ink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final base = (bold ? text.titleMedium! : text.bodyMedium!).copyWith(
      fontSize: bold ? 17 : 14,
      letterSpacing: 0,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: base.copyWith(
            color: bold ? AppColors.ink : AppColors.inkMid,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: base.copyWith(
            color: AppColors.ink,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

final ButtonStyle _stepperButtonStyle = IconButton.styleFrom(
  minimumSize: const Size(38, 38),
  maximumSize: const Size(38, 38),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
);