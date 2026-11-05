import '../../../core/l10n/l10n.dart';
import '../domain/entities/product.dart';

/// What a shop category is called on screen.
///
/// In the presentation layer, not on [ProductCategory], for the same reason
/// `sessionStatusLabel` is: the domain layer is pure Dart and
/// [AppLocalizations] is not. [ProductCategory.label] stays as the English
/// default; anything a shopper reads goes through here.
String productCategoryLabel(ProductCategory category, AppLocalizations l10n) =>
    switch (category) {
      ProductCategory.equipment => l10n.shopCategoryEquipment,
      ProductCategory.medicine => l10n.shopCategoryMedicines,
      ProductCategory.nutrition => l10n.shopCategoryNutrition,
    };
