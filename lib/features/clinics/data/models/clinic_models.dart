import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/clinic.dart';

part 'clinic_models.g.dart';

/// Mirrors `ClinicResponse`.
///
/// `services` is a real Postgres array, not the comma-joined string the other
/// tag-like fields use. There is deliberately no `rating`, `price` or
/// `distance` here — the backend does not send them.
@JsonSerializable()
class ClinicDto {
  const ClinicDto({
    required this.id,
    required this.name,
    this.area = '',
    this.city = '',
    this.address = '',
    this.services = const [],
    this.phone = '',
    this.hours = '',
  });

  final String id;
  final String name;

  @JsonKey(defaultValue: '')
  final String area;

  @JsonKey(defaultValue: '')
  final String city;

  @JsonKey(defaultValue: '')
  final String address;

  @JsonKey(defaultValue: <String>[])
  final List<String> services;

  @JsonKey(defaultValue: '')
  final String phone;

  @JsonKey(defaultValue: '')
  final String hours;

  factory ClinicDto.fromJson(Map<String, dynamic> json) =>
      _$ClinicDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ClinicDtoToJson(this);

  Clinic toEntity() => Clinic(
    id: id,
    name: name,
    area: area,
    city: city,
    address: address,
    services: services,
    phone: phone,
    hours: hours,
  );
}

/// The list wrapper key is `clinics`, not `items`.
@JsonSerializable()
class ClinicListDto {
  const ClinicListDto({this.clinics = const [], this.total = 0});

  final List<ClinicDto> clinics;
  final int total;

  factory ClinicListDto.fromJson(Map<String, dynamic> json) =>
      _$ClinicListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ClinicListDtoToJson(this);
}
