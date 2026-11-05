import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/shop_models.dart';

part 'shop_api.g.dart';

/// Catalogue and cart endpoints.
///
/// Checkout is absent on purpose: the backend has no order entity, so there is
/// nothing to call. See TODO(api) A6 in docs/TODO_REGISTER.md.
@RestApi()
abstract class ShopApi {
  factory ShopApi(Dio dio, {String baseUrl}) = _ShopApi;

  @GET('/products')
  Future<ProductListDto> listProducts({
    @Query('category') String? category,
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  @GET('/cart')
  Future<CartDto> getCart();

  /// Returns the created line, not the whole cart — refetch after calling.
  @POST('/cart')
  Future<CartItemDto> addToCart(@Body() CartItemCreateDto body);

  @PUT('/cart/{id}')
  Future<CartItemDto> updateCartItem(
    @Path('id') String id,
    @Body() CartItemUpdateDto body,
  );

  @DELETE('/cart/{id}')
  Future<void> removeCartItem(@Path('id') String id);

  @DELETE('/cart')
  Future<void> clearCart();
}
