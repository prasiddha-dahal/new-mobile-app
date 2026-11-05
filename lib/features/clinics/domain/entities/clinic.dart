/// A physiotherapy clinic, mirroring `ClinicResponse`.
///
/// The prototype's clinic cards carry a star rating, a "from Rs …" price and a
/// distance. None of the three exists on the backend model, so none of them is
/// rendered — see TODO(api) A12 in docs/TODO_REGISTER.md.
class Clinic {
  const Clinic({
    required this.id,
    required this.name,
    required this.area,
    required this.city,
    required this.address,
    required this.services,
    required this.phone,
    required this.hours,
  });

  final String id;
  final String name;

  /// Neighbourhood, e.g. `Jhamsikhel`.
  final String area;
  final String city;

  /// Full street address; longer than [locationLabel] and only shown on detail.
  final String address;

  /// Free-text service names the clinic offers; rendered as badges.
  final List<String> services;
  final String phone;

  /// Opening hours as one display string, e.g. `Sun–Fri · 7:00 – 19:00`.
  final String hours;

  /// `Jhamsikhel, Lalitpur`. The prototype appends a distance here, which the
  /// API cannot supply.
  String get locationLabel {
    final parts = [area, city].where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? '—' : parts.join(', ');
  }
}
