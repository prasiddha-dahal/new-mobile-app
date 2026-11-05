import '../../../../core/error/failures.dart';
import '../entities/product.dart';

abstract class ShopRepository {
  /// Catalogue, optionally filtered to one category.
  Future<AppResult<List<Product>>> listProducts(ProductCategory? category);

  Future<AppResult<Cart>> getCart();

  Future<AppResult<void>> addToCart({
    required String productId,
    required String type,
    int quantity,
    int rentalDays,
  });

  Future<AppResult<void>> updateCartItem({
    required String itemId,
    int? quantity,
    int? rentalDays,
  });

  Future<AppResult<void>> removeCartItem(String itemId);

  Future<AppResult<void>> clearCart();

  /// Places the order.
  ///
  /// Always fails with [NotImplementedFailure] today — the backend has no order
  /// entity. Kept in the interface so the UI flow is complete and switching it
  /// on is a one-line change here.
  Future<AppResult<String>> checkout();
}
