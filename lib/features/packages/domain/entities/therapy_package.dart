/// One purchasable plan from `GET /packages`.
///
/// The backend models a *tier catalogue*: a single price, a single
/// [sessionCount] and a single [validityDays] per row. There is no variant
/// model, so there is nothing behind the design's `1 Week / 2 Weeks / 3 Weeks /
/// 4 Weeks` duration picker — see docs/packages_integration.md ("API gaps").
class TherapyPackage {
  const TherapyPackage({
    required this.id,
    required this.name,
    this.tag = '',
    this.icon = 'Brain',
    required this.price,
    this.cadence = '',
    this.blurb = '',
    this.points = const [],
    this.sessionCount = 0,
    this.validityDays = 0,
    this.featured = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;

  /// A marketing badge — "Most requested from abroad", "Return to play".
  ///
  /// Explicitly **not** a category: the seeded values are sentences, not the
  /// design's `Orthopedic / Neurological / Sports Injury` taxonomy. Nothing in
  /// the schema carries a category.
  final String tag;

  /// A lucide-react icon *name* (e.g. `Brain`), which is what the web app
  /// consumes. Flutter has no icon set keyed by those names, so the UI maps the
  /// few known values and falls back to a neutral glyph.
  final String icon;

  /// Whole rupees.
  final int price;

  /// A display string the backend composes, e.g. `per month · 12 sessions`.
  final String cadence;

  final String blurb;
  final List<String> points;

  /// Sessions granted by one purchase.
  final int sessionCount;

  /// Days the purchase stays usable, counted from the purchase moment.
  final int validityDays;

  final bool featured;
  final int sortOrder;
  final bool isActive;

  /// Client-side free-text match over the fields a patient would search by.
  ///
  /// `GET /packages` takes no `q` parameter, so search cannot be pushed to the
  /// server. Cheap while the catalogue is three rows; see the integration doc.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (name.toLowerCase().contains(needle)) return true;
    if (blurb.toLowerCase().contains(needle)) return true;
    if (tag.toLowerCase().contains(needle)) return true;
    return points.any((p) => p.toLowerCase().contains(needle));
  }
}

/// The catalogue as a whole, with the filtering rules the screen applies.
///
/// Lives in the domain layer so the search and chip decisions are unit-testable
/// without a widget tree.
class PackageCatalogue {
  const PackageCatalogue(this.packages);

  final List<TherapyPackage> packages;

  /// Distinct, non-blank [TherapyPackage.tag] values, in catalogue order.
  List<String> get tags {
    final seen = <String>[];
    for (final p in packages) {
      final tag = p.tag.trim();
      if (tag.isNotEmpty && !seen.contains(tag)) seen.add(tag);
    }
    return seen;
  }

  /// Whether the filter row is worth showing.
  ///
  /// The design's chips (`All / Orthopedic / Neurological / …`) have no field
  /// behind them, so the row is built from the real `tag` values instead. That
  /// is only a filter if a tag actually groups more than one package — with one
  /// tag per package every chip selects exactly one card, which is a worse copy
  /// of the list underneath it. In that case the row is hidden rather than
  /// faked.
  bool get hasUsefulTagFilter =>
      tags.length >= 2 && tags.length < packages.length;

  /// Packages matching [query] and, when given, [tag].
  List<TherapyPackage> filter({String query = '', String? tag}) {
    final wanted = tag?.trim();
    return packages.where((p) {
      if (wanted != null && wanted.isNotEmpty && p.tag.trim() != wanted) {
        return false;
      }
      return p.matches(query);
    }).toList();
  }
}
