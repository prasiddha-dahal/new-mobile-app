import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/shop/data/models/shop_models.dart';
import 'package:sahayatri_care_connect/features/shop/domain/entities/product.dart';

Map<String, dynamic> _product({
  String id = 'prd_1',
  String category = 'EQUIPMENT',
  num price = 7500,
  num rentPerDay = 250,
  int inStock = 12,
}) =>
    {
      'id': id,
      'name': 'TENS unit',
      'category': category,
      'price': price,
      'rentPerDay': rentPerDay,
      'inStock': inStock,
      'emoji': '⚡',
      'description': 'Pain relief electrotherapy',
    };

void main() {
  group('ProductCategory', () {
    test('maps the backend values and defaults safely', () {
      expect(ProductCategory.fromWire('EQUIPMENT'), ProductCategory.equipment);
      expect(ProductCategory.fromWire('MEDICINE'), ProductCategory.medicine);
      expect(ProductCategory.fromWire('NUTRITION'), ProductCategory.nutrition);
      expect(ProductCategory.fromWire('WHAT'), ProductCategory.equipment);
    });

    test('only equipment is rented', () {
      expect(ProductCategory.equipment.isRental, isTrue);
      expect(ProductCategory.medicine.isRental, isFalse);
      expect(ProductCategory.nutrition.isRental, isFalse);
    });
  });

  group('Product', () {
    test('equipment shows the daily rate with a /day suffix', () {
      final p = ProductDto.fromJson(_product()).toEntity();
      expect(p.displayPrice, 250.0);
      expect(p.priceSuffix, '/day');
      expect(p.cartType, 'RENT');
      expect(p.isAvailable, isTrue);
    });

    test('a medicine shows its outright price with no suffix', () {
      final p = ProductDto.fromJson(
        _product(category: 'MEDICINE', price: 320, rentPerDay: 0),
      ).toEntity();
      expect(p.displayPrice, 320.0);
      expect(p.priceSuffix, '');
      expect(p.cartType, 'MEDICINE');
    });

    test('zero stock is unavailable', () {
      final p = ProductDto.fromJson(_product(inStock: 0)).toEntity();
      expect(p.isAvailable, isFalse);
    });
  });

  group('CartLine', () {
    test('a rental multiplies rate by quantity and days', () {
      final line = CartItemDto.fromJson({
        'id': 'cit_1',
        'productId': 'prd_1',
        'product': _product(),
        'type': 'RENT',
        'quantity': 2,
        'rentalDays': 7,
      }).toEntity();

      expect(line.isRental, isTrue);
      expect(line.lineTotal, 250.0 * 2 * 7);
    });

    test('a purchase ignores rentalDays', () {
      final line = CartItemDto.fromJson({
        'id': 'cit_2',
        'productId': 'prd_4',
        'product': _product(category: 'MEDICINE', price: 450, rentPerDay: 0),
        'type': 'MEDICINE',
        'quantity': 2,
        'rentalDays': 7,
      }).toEntity();

      expect(line.isRental, isFalse);
      expect(line.lineTotal, 900.0);
    });
  });

  group('Cart', () {
    test('reads the backend totals, including the misnamed subtotal', () {
      final cart = CartDto.fromJson({
        'items': [
          {
            'id': 'cit_1',
            'productId': 'prd_1',
            'product': _product(),
            'type': 'RENT',
            'quantity': 1,
            'rentalDays': 7,
          },
        ],
        // `total` is the SUBTOTAL on the wire.
        'total': 1750,
        'deliveryFee': 150,
        'grandTotal': 1900,
      }).toEntity();

      expect(cart.subtotal, 1750.0);
      expect(cart.deliveryFee, 150.0);
      expect(cart.grandTotal, 1900.0);
      expect(cart.itemCount, 1);
      expect(cart.isEmpty, isFalse);
    });

    test('an empty cart reports zero', () {
      const cart = Cart.empty();
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
    });

    test('item count sums quantities, not lines', () {
      final cart = CartDto.fromJson({
        'items': [
          {
            'id': 'a',
            'productId': 'prd_1',
            'product': _product(),
            'type': 'RENT',
            'quantity': 2,
            'rentalDays': 7,
          },
          {
            'id': 'b',
            'productId': 'prd_4',
            'product': _product(id: 'prd_4', category: 'MEDICINE'),
            'type': 'MEDICINE',
            'quantity': 3,
            'rentalDays': 1,
          },
        ],
        'total': 0,
        'deliveryFee': 0,
        'grandTotal': 0,
      }).toEntity();

      expect(cart.itemCount, 5);
    });
  });

  group('CartItemCreateDto', () {
    test('sends camelCase keys', () {
      final json = const CartItemCreateDto(
        productId: 'prd_1',
        type: 'RENT',
        quantity: 1,
        rentalDays: 14,
      ).toJson();

      expect(json['productId'], 'prd_1');
      expect(json['rentalDays'], 14);
    });
  });
}
