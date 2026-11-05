import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/json_converters.dart';
import '../../domain/entities/product.dart';

part 'shop_models.g.dart';

@JsonSerializable()
class ProductDto {
  const ProductDto({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.rentPerDay,
    required this.inStock,
    this.emoji = '',
    this.description,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String category;

  @FlexibleDoubleConverter()
  final double price;

  @FlexibleDoubleConverter()
  final double rentPerDay;

  final int inStock;

  @JsonKey(defaultValue: '')
  final String emoji;

  final String? description;
  final String? imageUrl;

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ProductDtoToJson(this);

  Product toEntity() => Product(
    id: id,
    name: name,
    category: ProductCategory.fromWire(category),
    price: price,
    rentPerDay: rentPerDay,
    inStock: inStock,
    emoji: emoji,
    description: description,
    imageUrl: imageUrl,
  );
}

@JsonSerializable()
class ProductListDto {
  const ProductListDto({this.products = const [], this.total = 0});

  final List<ProductDto> products;
  final int total;

  factory ProductListDto.fromJson(Map<String, dynamic> json) =>
      _$ProductListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ProductListDtoToJson(this);
}

@JsonSerializable()
class CartItemDto {
  const CartItemDto({
    required this.id,
    required this.productId,
    required this.product,
    required this.type,
    required this.quantity,
    required this.rentalDays,
  });

  final String id;
  final String productId;

  /// Always present — the backend embeds the whole product on every line.
  final ProductDto product;

  final String type;
  final int quantity;
  final int rentalDays;

  factory CartItemDto.fromJson(Map<String, dynamic> json) =>
      _$CartItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CartItemDtoToJson(this);

  CartLine toEntity() => CartLine(
    id: id,
    product: product.toEntity(),
    type: type,
    quantity: quantity,
    rentalDays: rentalDays,
  );
}

/// Mirrors `CartResponse`. `total` is the subtotal despite the name.
@JsonSerializable()
class CartDto {
  const CartDto({
    this.items = const [],
    this.total = 0,
    this.deliveryFee = 0,
    this.grandTotal = 0,
  });

  final List<CartItemDto> items;

  @FlexibleDoubleConverter()
  final double total;

  @FlexibleDoubleConverter()
  final double deliveryFee;

  @FlexibleDoubleConverter()
  final double grandTotal;

  factory CartDto.fromJson(Map<String, dynamic> json) =>
      _$CartDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CartDtoToJson(this);

  Cart toEntity() => Cart(
    lines: items.map((i) => i.toEntity()).toList(),
    subtotal: total,
    deliveryFee: deliveryFee,
    grandTotal: grandTotal,
  );
}

@JsonSerializable(includeIfNull: false)
class CartItemCreateDto {
  const CartItemCreateDto({
    required this.productId,
    this.type = 'BUY',
    this.quantity = 1,
    this.rentalDays = 7,
  });

  final String productId;
  final String type;
  final int quantity;
  final int rentalDays;

  factory CartItemCreateDto.fromJson(Map<String, dynamic> json) =>
      _$CartItemCreateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CartItemCreateDtoToJson(this);
}

@JsonSerializable(includeIfNull: false)
class CartItemUpdateDto {
  const CartItemUpdateDto({this.quantity, this.rentalDays, this.type});

  final int? quantity;
  final int? rentalDays;
  final String? type;

  factory CartItemUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$CartItemUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CartItemUpdateDtoToJson(this);
}
