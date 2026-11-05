import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/json_converters.dart';
import '../../../patient/data/models/therapist_models.dart';

part 'coverage_models.g.dart';

/// One area chip on the map screen.
@JsonSerializable()
class ServiceAreaDto {
  const ServiceAreaDto({
    required this.id,
    this.name = '',
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;

  /// Null until the area is geocoded — coverage then falls back to the
  /// admin-managed therapist/area links.
  final double? latitude;
  final double? longitude;

  factory ServiceAreaDto.fromJson(Map<String, dynamic> json) =>
      _$ServiceAreaDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceAreaDtoToJson(this);
}

@JsonSerializable()
class ServiceAreaListDto {
  const ServiceAreaListDto({this.areas = const []});
  final List<ServiceAreaDto> areas;

  factory ServiceAreaListDto.fromJson(Map<String, dynamic> json) =>
      _$ServiceAreaListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceAreaListDtoToJson(this);
}

@JsonSerializable()
class CoverageTherapistDto {
  const CoverageTherapistDto({
    required this.id,
    this.name = '',
    this.specialty = '',
    this.city = '',
    this.price = 0,
    this.listingType = 'BOOKABLE',
    this.serviceRadiusKm,
    this.distanceKm,
    this.covers = false,
    this.clinic,
    this.photo,
    this.photoThumb,
  });

  final String id;
  final String name;

  /// The therapist's public photo and 256px thumbnail; null when not set.
  final String? photo;
  final String? photoThumb;
  final String specialty;
  final String city;

  @FlexibleDoubleConverter()
  final double price;

  final String listingType;
  final int? serviceRadiusKm;

  /// Null when either side has not been geocoded.
  final double? distanceKm;

  /// Whether this therapist can actually reach the chosen area.
  final bool covers;

  final ClinicBriefDto? clinic;

  bool get isBookable => listingType.toUpperCase() != 'INFO_ONLY';

  factory CoverageTherapistDto.fromJson(Map<String, dynamic> json) =>
      _$CoverageTherapistDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CoverageTherapistDtoToJson(this);
}

@JsonSerializable()
class CoverageClinicDto {
  const CoverageClinicDto({
    required this.id,
    this.name = '',
    this.area = '',
    this.city = '',
    this.address = '',
    this.hours = '',
    this.distanceKm,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String area;
  final String city;
  final String address;
  final String hours;

  final double? distanceKm;

  /// The clinic's pin on the coverage map. Null until it is geocoded.
  final double? latitude;
  final double? longitude;

  factory CoverageClinicDto.fromJson(Map<String, dynamic> json) =>
      _$CoverageClinicDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CoverageClinicDtoToJson(this);
}

@JsonSerializable()
class CoverageDto {
  const CoverageDto({
    this.area,
    this.therapists = const [],
    this.clinics = const [],
    this.coveringCount = 0,
  });

  final ServiceAreaDto? area;
  final List<CoverageTherapistDto> therapists;
  final List<CoverageClinicDto> clinics;
  final int coveringCount;

  factory CoverageDto.fromJson(Map<String, dynamic> json) =>
      _$CoverageDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CoverageDtoToJson(this);
}
