import 'geo_point.dart';

/// The cities the platform serves, as the server stores them.
///
/// A detected place is snapped to one of these when it can be: the therapist
/// search matches `city` as text, so "Kathmandu Metropolitan City" -- which is
/// what a geocoder calls it -- would match nothing the platform has.
const supportedCities = [
  'Kathmandu',
  'Lalitpur',
  'Bhaktapur'
];

/// Where the device is, in the words a form field wants.
class DetectedLocation {
  const DetectedLocation({
    required this.city,
    this.area,
    this.point,
    this.accuracyMeters,
  });

  final String city;

  /// The neighbourhood or street, when the geocoder knew one.
  final String? area;

  /// The fix the names were worked out from, and how far off it may be.
  /// Null when the lookup did not keep one.
  final GeoPoint? point;
  final double? accuracyMeters;

  /// Close enough to send a therapist to: a fix worse than this lands on the
  /// wrong lane, or the wrong side of a river, in a dense neighbourhood.
  static const pinnableWithinMeters = 100.0;

  /// The point, when it is good enough to navigate to.
  GeoPoint? get pinnablePoint {
    final p = point;
    final accuracy = accuracyMeters;
    if (p == null || accuracy == null) return null;
    return accuracy <= pinnableWithinMeters ? p : null;
  }

  DetectedLocation withFix(GeoPoint point, double accuracyMeters) =>
      DetectedLocation(
        city: city,
        area: area,
        point: point,
        accuracyMeters: accuracyMeters,
      );

  /// For a city field: `Kathmandu`.
  String get cityLabel => city;

  /// For an address field: `Baneshwor, Kathmandu`. Falls back to the city
  /// alone, which is a starting point the person completes rather than a
  /// wrong answer.
  String get addressLabel => area == null ? city : '$area, $city';

  @override
  bool operator ==(Object other) =>
      other is DetectedLocation &&
      other.city == city &&
      other.area == area &&
      other.point == point &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(city, area, point, accuracyMeters);
}

final _adminSuffix = RegExp(
  r'\s+(sub[- ]?metropolitan|metropolitan|rural|municipality|city|district|province)\b.*$',
  caseSensitive: false,
);

final _plusCode = RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]{2,}');

String _clean(String? value) {
  var v = (value ?? '').trim();
  // "Kathmandu Metropolitan City", "Lalitpur Sub-Metropolitan City",
  // "Godawari Municipality": the administrative label is not part of the name
  // anyone would type.
  v = v.replaceAll(_adminSuffix, '').trim();
  return v;
}

/// Turns a geocoder's placemark into a [DetectedLocation].
///
/// Pure, and takes plain strings, so the part that is guesswork -- which of
/// the placemark's fields holds the city in Nepal -- can be tested without a
/// device. The fields are read in order of how specific they are, and the
/// first one that names a supported city wins: Bharatpur, say, is a
/// municipality in Chitwan district, and Chitwan is what the platform serves.
DetectedLocation? describePlace({
  String? thoroughfare,
  String? subLocality,
  String? locality,
  String? subAdministrativeArea,
  String? administrativeArea,
}) {
  final candidates = [
    locality,
    subAdministrativeArea,
    administrativeArea,
  ].map((c) => (c ?? '').trim()).where((c) => c.isNotEmpty).toList();

  String? city;
  for (final candidate in candidates) {
    for (final known in supportedCities) {
      if (candidate.toLowerCase().contains(known.toLowerCase())) {
        city = known;
        break;
      }
    }
    if (city != null) break;
  }
  city ??= candidates.isEmpty ? null : _clean(candidates.first);
  if (city == null || city.isEmpty) return null;

  final parts = <String>[];
  void add(String? raw) {
    final v = _clean(raw);
    if (v.isEmpty || _plusCode.hasMatch(v)) return;
    // A bare house number is not an area.
    if (RegExp(r'^\d+$').hasMatch(v)) return;
    final lower = v.toLowerCase();
    if (lower == city!.toLowerCase()) return;
    if (parts.any((p) => p.toLowerCase() == lower)) return;
    parts.add(v);
  }

  add(thoroughfare);
  add(subLocality);

  return DetectedLocation(
    city: city,
    area: parts.isEmpty ? null : parts.join(', '),
  );
}
