import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/shop_api.dart';
import '../models/shop_models.dart';

class ShopRepositoryImpl implements ShopRepository {
  ShopRepositoryImpl(this._api);

  final ShopApi _api;

  Future<AppResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<Product>>> listProducts(ProductCategory? category) =>
      _guard(() async {
        final response = await _api.listProducts(category: category?.wireValue);
        return response.products.map((p) => p.toEntity()).toList();
      });

  @override
  Future<AppResult<Cart>> getCart() =>
      _guard(() async => (await _api.getCart()).toEntity());

  @override
  Future<AppResult<void>> addToCart({
    required String productId,
    required String type,
    int quantity = 1,
    int rentalDays = 7,
  }) => _guard(() async {
    await _api.addToCart(
      CartItemCreateDto(
        productId: productId,
        type: type,
        quantity: quantity,
        rentalDays: rentalDays,
      ),
    );
  });

  @override
  Future<AppResult<void>> updateCartItem({
    required String itemId,
    int? quantity,
    int? rentalDays,
  }) => _guard(() async {
    await _api.updateCartItem(
      itemId,
      CartItemUpdateDto(quantity: quantity, rentalDays: rentalDays),
    );
  });

  @override
  Future<AppResult<void>> removeCartItem(String itemId) =>
      _guard(() => _api.removeCartItem(itemId));

  @override
  Future<AppResult<void>> clearCart() => _guard(() => _api.clearCart());

  @override
  Future<AppResult<String>> checkout() async {
    // There is no order entity or checkout endpoint on the backend. Rather than
    // clear the cart and fake a reference — which would look like a completed
    // purchase nobody can fulfil — the flow stops here with a typed failure the
    // UI turns into an honest message.
    // TODO(api): order create + cart clear (A6 in docs/TODO_REGISTER.md).
    return const Left(
      NotImplementedFailure(
        'POST /orders',
        'Equipment orders cannot be placed from the app until ordering is '
            'switched on.',
      ),
    );
  }
}
