import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/shop_api.dart';
import '../../data/repositories/shop_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/shop_repository.dart';

final shopApiProvider = Provider<ShopApi>((ref) {
  return ShopApi(ref.watch(dioProvider));
});

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepositoryImpl(ref.watch(shopApiProvider));
});

Future<T> _unwrap<T>(Future<AppResult<T>> future) async {
  final result = await future;
  return result.fold((failure) => throw failure, (value) => value);
}

/// Category tab currently selected on the shop screen.
final shopCategoryProvider = StateProvider<ProductCategory>(
  (_) => ProductCategory.equipment,
);

final productListProvider = FutureProvider<List<Product>>((ref) {
  final category = ref.watch(shopCategoryProvider);
  return _unwrap(ref.watch(shopRepositoryProvider).listProducts(category));
});

final cartProvider = FutureProvider<Cart>((ref) {
  return _unwrap(ref.watch(shopRepositoryProvider).getCart());
});

/// Item count for the shop header badge; 0 while the cart is loading.
final cartCountProvider = Provider<int>((ref) {
  return ref
      .watch(cartProvider)
      .maybeWhen(data: (cart) => cart.itemCount, orElse: () => 0);
});

final shopActionsProvider = Provider<ShopActions>((ref) => ShopActions(ref));

class ShopActions {
  ShopActions(this._ref);
  final Ref _ref;

  ShopRepository get _repo => _ref.read(shopRepositoryProvider);

  Future<AppResult<void>> add(Product product) async {
    final result = await _repo.addToCart(
      productId: product.id,
      type: product.cartType,
      rentalDays: product.category.isRental ? 7 : 1,
    );
    result.match((_) {}, (_) => _ref.invalidate(cartProvider));
    return result;
  }

  Future<AppResult<void>> setQuantity({
    required String itemId,
    required int quantity,
  }) async {
    // The stepper never goes below one; removal is its own action.
    if (quantity < 1) return remove(itemId);
    final result = await _repo.updateCartItem(
      itemId: itemId,
      quantity: quantity,
    );
    result.match((_) {}, (_) => _ref.invalidate(cartProvider));
    return result;
  }

  Future<AppResult<void>> setRentalDays({
    required String itemId,
    required int days,
  }) async {
    final result = await _repo.updateCartItem(itemId: itemId, rentalDays: days);
    result.match((_) {}, (_) => _ref.invalidate(cartProvider));
    return result;
  }

  Future<AppResult<void>> remove(String itemId) async {
    final result = await _repo.removeCartItem(itemId);
    result.match((_) {}, (_) => _ref.invalidate(cartProvider));
    return result;
  }

  Future<AppResult<String>> checkout() => _repo.checkout();
}
