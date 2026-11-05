/// Product categories, mirroring the backend `ProductCategory` enum.
enum ProductCategory {
  equipment('EQUIPMENT', 'Equipment'),
  medicine('MEDICINE', 'Medicines'),
  nutrition('NUTRITION', 'Nutrition');

  const ProductCategory(this.wireValue, this.label);

  final String wireValue;

  /// Tab label from the prototype — note the plural on medicines.
  final String label;

  static ProductCategory fromWire(String? value) {
    final v = (value ?? '').toUpperCase();
    return ProductCategory.values.firstWhere(
      (c) => c.wireValue == v,
      orElse: () => ProductCategory.equipment,
    );
  }

  /// Equipment is rented by the day; everything else is bought outright.
  bool get isRental => this == ProductCategory.equipment;
}

/// A shop item.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.rentPerDay,
    required this.inStock,
    required this.emoji,
    this.description,
    this.imageUrl,
  });

  final String id;
  final String name;
  final ProductCategory category;

  /// Outright purchase price.
  final double price;

  /// Daily rental rate; only meaningful for equipment.
  final double rentPerDay;

  /// Units available. Zero means the card shows "Out of stock".
  final int inStock;

  /// The backend stores a display emoji per product; `""` when unset.
  final String emoji;
  final String? description;
  final String? imageUrl;

  bool get isAvailable => inStock > 0;

  /// What the card shows as the headline price.
  double get displayPrice => category.isRental ? rentPerDay : price;

  /// Suffix beside the price — `/day` for rentals, nothing otherwise.
  String get priceSuffix => category.isRental ? '/day' : '';

  /// The cart line type this product should be added as.
  String get cartType => switch (category) {
    ProductCategory.equipment => 'RENT',
    ProductCategory.medicine => 'MEDICINE',
    ProductCategory.nutrition => 'NUTRITION',
  };
}

/// One line in the cart, with its product embedded.
class CartLine {
  const CartLine({
    required this.id,
    required this.product,
    required this.type,
    required this.quantity,
    required this.rentalDays,
  });

  final String id;
  final Product product;

  /// `BUY`, `RENT`, `MEDICINE` or `NUTRITION`.
  final String type;
  final int quantity;
  final int rentalDays;

  bool get isRental => type.toUpperCase() == 'RENT';

  /// Mirrors the backend's arithmetic: rentals multiply by days.
  double get lineTotal => isRental
      ? product.rentPerDay * quantity * rentalDays
      : product.price * quantity;
}

/// The cart with the totals the backend computed.
///
/// [subtotal] arrives as `total`, which is a misleading name — [grandTotal] is
/// the amount actually owed.
class Cart {
  const Cart({
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.grandTotal,
  });

  const Cart.empty()
    : lines = const [],
      subtotal = 0,
      deliveryFee = 0,
      grandTotal = 0;

  final List<CartLine> lines;
  final double subtotal;
  final double deliveryFee;
  final double grandTotal;

  bool get isEmpty => lines.isEmpty;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}
