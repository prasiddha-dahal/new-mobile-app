/// Where a therapist can be seen.
///
/// A BOOKABLE therapist publishes slots and is booked through the app. An
/// INFO_ONLY one is a directory entry: their profile, workplace and opening
/// hours are shown, and the patient visits them there.
enum ListingType {
  bookable('BOOKABLE'),
  infoOnly('INFO_ONLY');

  const ListingType(this.wireValue);
  final String wireValue;

  static ListingType fromWire(String? value) => ListingType.values.firstWhere(
        (t) => t.wireValue == (value ?? '').toUpperCase(),
        // Unknown values default to bookable, matching the server default and
        // keeping existing therapists working if a new type is added.
        orElse: () => ListingType.bookable,
      );

  bool get isBookable => this == ListingType.bookable;
}

/// A therapist's workplace, for an information-only listing.
class Workplace {
  const Workplace({
    required this.id,
    required this.name,
    this.area = '',
    this.city = '',
    this.address = '',
    this.phone = '',
    this.hours = '',
    this.services = const [],
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String area;
  final String city;
  final String address;
  final String phone;

  /// Opening hours as published, e.g. "Sun–Fri: 9:00 AM – 6:00 PM".
  final String hours;
  final List<String> services;
  final double? latitude;
  final double? longitude;

  String get location =>
      [area, city].where((p) => p.isNotEmpty).join(', ');
}

/// A physiotherapist (pure Dart — no JSON or Flutter imports).
class Therapist {
  const Therapist({
    required this.id,
    required this.userId,
    required this.name,
    required this.specialty,
    required this.city,
    required this.gender,
    required this.rating,
    required this.reviewCount,
    required this.fee,
    required this.experienceYears,
    required this.bio,
    this.listingType = ListingType.bookable,
    this.workplace,
    this.latitude,
    this.longitude,
    this.serviceRadiusKm,
    this.photoUrl,
    this.photoThumbUrl,
  });

  /// The Therapist row id — this is what booking and slot endpoints expect,
  /// not [userId].
  final String id;
  final String userId;
  final String name;
  final String specialty;
  final String city;
  final String gender;

  /// 0 when nobody has rated this therapist yet.
  final double rating;
  final int reviewCount;

  /// Fee per session, in NPR. Called `price` on the wire.
  final double fee;
  final int experienceYears;
  final String bio;

  /// Whether this therapist is booked through the app at all.
  final ListingType listingType;

  /// Set for an information-only listing; null for a home-visit therapist.
  final Workplace? workplace;

  /// Home-visit coverage. Null until geocoded.
  final double? latitude;
  final double? longitude;
  final int? serviceRadiusKm;

  /// The profile photo, for a detail view, and its 256px square for a card.
  /// Draw the thumbnail wherever the photo is small: it is a fraction of the
  /// bytes. Null when the therapist has not set one.
  final String? photoUrl;
  final String? photoThumbUrl;

  bool get isBookable => listingType.isBookable;

  bool get isRated => reviewCount > 0;

  String get initials {
    final cleaned = name.replaceFirst(RegExp(r'^(Dr\.?|Mr\.?|Ms\.?)\s+'), '');
    final parts = cleaned
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// One slot on a therapist's calendar.
class TherapistSlot {
  const TherapistSlot({
    required this.date,
    required this.time,
    required this.isOpen,
    this.fee,
  });

  /// `YYYY-MM-DD`.
  final String date;

  /// `HH:MM`.
  final String time;
  final bool isOpen;
  final double? fee;
}

/// Aggregated counts for the patient home screen.
class PatientDashboard {
  const PatientDashboard({
    required this.name,
    required this.totalSessions,
    required this.completedSessions,
    required this.upcomingSessions,
    this.nextSession,
    this.referralCode = '',
  });

  final String name;
  final int totalSessions;
  final int completedSessions;
  final int upcomingSessions;
  final NextSessionSummary? nextSession;
  final String referralCode;
}

/// The "next session" card on the home screen. Dates arrive as strings here,
/// unlike the full session model.
class NextSessionSummary {
  const NextSessionSummary({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.date,
    required this.time,
    required this.type,
    required this.status,
    this.therapistPhotoUrl,
    this.therapistPhotoThumbUrl,
  });

  final String id;
  final String therapistId;
  final String therapistName;
  final String date;
  final String time;
  final String type;
  final String status;
  final String? therapistPhotoUrl;
  final String? therapistPhotoThumbUrl;
}
