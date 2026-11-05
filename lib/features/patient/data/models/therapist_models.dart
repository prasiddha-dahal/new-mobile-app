import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/json_converters.dart';
import '../../domain/entities/therapist.dart';

part 'therapist_models.g.dart';

/// Mirrors `TherapistResponse`.
///
/// Two traps worth remembering: `id` is the **Therapist** row id, not the
/// user's, and the session fee is called `price` here (it is `fee` on a
/// session). `reviews` is a count, not a list.
@JsonSerializable()
class TherapistDto {
  const TherapistDto({
    required this.id,
    required this.userId,
    required this.name,
    required this.specialty,
    required this.city,
    required this.gender,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.experience,
    required this.bio,
    this.listingType = 'BOOKABLE',
    this.clinic,
    this.latitude,
    this.longitude,
    this.serviceRadiusKm,
    this.photo,
    this.photoThumb,
  });

  final String id;
  final String userId;
  final String name;
  final String specialty;
  final String city;
  final String gender;

  /// Server-relative URLs of the profile photo (at most 1024px) and its 256px
  /// square thumbnail. Null when the therapist has not set one.
  final String? photo;
  final String? photoThumb;

  /// BOOKABLE or INFO_ONLY. Defaults to bookable, matching the server.
  final String listingType;

  /// Workplace for an information-only listing.
  final ClinicBriefDto? clinic;

  final double? latitude;
  final double? longitude;
  final int? serviceRadiusKm;

  @FlexibleDoubleConverter()
  final double rating;

  final int reviews;

  @FlexibleDoubleConverter()
  final double price;

  final int experience;
  final String bio;

  factory TherapistDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistDtoToJson(this);

  Therapist toEntity() => Therapist(
    id: id,
    userId: userId,
    name: name,
    specialty: specialty,
    city: city,
    gender: gender,
    rating: rating,
    reviewCount: reviews,
    fee: price,
    experienceYears: experience,
    bio: bio,
    listingType: ListingType.fromWire(listingType),
    workplace: clinic?.toEntity(),
    latitude: latitude,
    longitude: longitude,
    serviceRadiusKm: serviceRadiusKm,
    photoUrl: photo,
    photoThumbUrl: photoThumb,
  );
}

/// The list wrapper key is `therapists`, not `items`.
/// A therapist's workplace, sent alongside an information-only listing so
/// hours and services need no second request.
@JsonSerializable()
class ClinicBriefDto {
  const ClinicBriefDto({
    required this.id,
    this.name = '',
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
  final String hours;
  final List<String> services;

  final double? latitude;
  final double? longitude;

  factory ClinicBriefDto.fromJson(Map<String, dynamic> json) =>
      _$ClinicBriefDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ClinicBriefDtoToJson(this);

  Workplace toEntity() => Workplace(
        id: id,
        name: name,
        area: area,
        city: city,
        address: address,
        phone: phone,
        hours: hours,
        services: services,
        latitude: latitude,
        longitude: longitude,
      );
}

@JsonSerializable()
class TherapistListDto {
  const TherapistListDto({this.therapists = const [], this.total = 0});

  final List<TherapistDto> therapists;
  final int total;

  factory TherapistListDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistListDtoToJson(this);
}

/// One bookable slot from `GET /therapists/{id}/slots`.
@JsonSerializable()
class SlotDto {
  const SlotDto({
    required this.date,
    required this.time,
    required this.status,
    this.fee,
    this.sessionId,
    this.sessionType = '',
  });

  /// `YYYY-MM-DD`.
  final String date;

  /// `HH:MM`.
  final String time;

  /// `open`, `booked`, or `off`.
  final String status;

  @FlexibleDoubleConverter()
  @JsonKey(defaultValue: 0)
  final double? fee;

  final String? sessionId;
  final String sessionType;

  bool get isOpen => status == 'open';

  factory SlotDto.fromJson(Map<String, dynamic> json) =>
      _$SlotDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SlotDtoToJson(this);

  TherapistSlot toEntity() =>
      TherapistSlot(date: date, time: time, isOpen: isOpen, fee: fee);
}

@JsonSerializable()
class SlotRangeDto {
  const SlotRangeDto({this.slots = const []});

  final List<SlotDto> slots;

  factory SlotRangeDto.fromJson(Map<String, dynamic> json) =>
      _$SlotRangeDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SlotRangeDtoToJson(this);
}

/// Mirrors `PatientDashboardResponse`.
@JsonSerializable()
class PatientDashboardDto {
  const PatientDashboardDto({
    this.name = '',
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.upcomingSessions = 0,
    this.nextSession,
    this.referralCode = '',
    this.referralLink = '',
  });

  final String name;
  final int totalSessions;
  final int completedSessions;
  final int upcomingSessions;
  final NextSessionDto? nextSession;
  final String referralCode;
  final String referralLink;

  factory PatientDashboardDto.fromJson(Map<String, dynamic> json) =>
      _$PatientDashboardDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PatientDashboardDtoToJson(this);

  PatientDashboard toEntity() => PatientDashboard(
    name: name,
    totalSessions: totalSessions,
    completedSessions: completedSessions,
    upcomingSessions: upcomingSessions,
    nextSession: nextSession?.toEntity(),
    referralCode: referralCode,
  );
}

@JsonSerializable()
class NextSessionDto {
  const NextSessionDto({
    required this.id,
    this.therapistName = '',
    this.therapistId = '',
    this.date = '',
    this.time = '',
    this.type = '',
    this.status = '',
    this.therapistPhoto,
    this.therapistPhotoThumb,
  });

  final String id;
  final String therapistName;
  final String therapistId;
  final String date;
  final String time;
  final String type;
  final String status;
  final String? therapistPhoto;
  final String? therapistPhotoThumb;

  factory NextSessionDto.fromJson(Map<String, dynamic> json) =>
      _$NextSessionDtoFromJson(json);
  Map<String, dynamic> toJson() => _$NextSessionDtoToJson(this);

  NextSessionSummary toEntity() => NextSessionSummary(
    id: id,
    therapistId: therapistId,
    therapistName: therapistName,
    date: date,
    time: time,
    type: type,
    status: status,
    therapistPhotoUrl: therapistPhoto,
    therapistPhotoThumbUrl: therapistPhotoThumb,
  );
}
