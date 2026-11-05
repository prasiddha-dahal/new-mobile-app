/// A point on the map, in degrees. Pure Dart, so the domain layer can hold one.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// `27.691500,85.342000` -- six decimals is about 10 cm, more than any phone
  /// fix is worth, and the form map apps accept as a destination.
  String get query =>
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($query)';
}
