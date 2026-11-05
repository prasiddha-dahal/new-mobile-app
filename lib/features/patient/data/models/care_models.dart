import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/json_converters.dart';

part 'care_models.g.dart';

/// A document a therapist shared with the patient.
@JsonSerializable()
class ReportDto {
  const ReportDto({
    required this.id,
    required this.patientId,
    this.therapistId,
    this.sessionId,
    required this.title,
    this.content = '',
    this.fileUrl,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String? therapistId;
  final String? sessionId;
  final String title;

  @JsonKey(defaultValue: '')
  final String content;

  /// Comma-separated when a report carries more than one file.
  final String? fileUrl;

  @FlexibleDateTimeConverter()
  final DateTime createdAt;

  factory ReportDto.fromJson(Map<String, dynamic> json) =>
      _$ReportDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReportDtoToJson(this);

  List<String> get fileUrls => (fileUrl ?? '')
      .split(',')
      .map((u) => u.trim())
      .where((u) => u.isNotEmpty)
      .toList();
}

/// Body for `POST /admin/complaints`.
///
/// The endpoint sits under `/admin` but accepts any bearer token, and it does
/// **not** derive the complainant from the token — the client has to send both
/// the id and the name.
@JsonSerializable(includeIfNull: false)
class ComplaintCreateDto {
  const ComplaintCreateDto({
    required this.type,
    required this.complainantId,
    required this.complainantName,
    required this.againstId,
    required this.againstName,
    required this.category,
    this.priority = 'Normal',
    required this.description,
    this.bookingId,
    this.preferredOutcome,
  });

  /// `Therapist` or `Patient` — who the complaint is about.
  final String type;
  final String complainantId;
  final String complainantName;
  final String againstId;
  final String againstName;
  final String category;

  /// Title case, unlike most enums in this API.
  final String priority;
  final String description;
  final String? bookingId;
  final String? preferredOutcome;

  factory ComplaintCreateDto.fromJson(Map<String, dynamic> json) =>
      _$ComplaintCreateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ComplaintCreateDtoToJson(this);
}

@JsonSerializable()
class ComplaintDto {
  const ComplaintDto({
    required this.id,
    required this.category,
    this.status = 'Open',
    this.description = '',
  });

  final String id;
  final String category;
  final String status;

  @JsonKey(defaultValue: '')
  final String description;

  factory ComplaintDto.fromJson(Map<String, dynamic> json) =>
      _$ComplaintDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ComplaintDtoToJson(this);
}

/// `GET /patients/me/referral`.
@JsonSerializable()
class ReferralDto {
  const ReferralDto({this.code = '', this.link = ''});

  final String code;
  final String link;

  factory ReferralDto.fromJson(Map<String, dynamic> json) =>
      _$ReferralDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReferralDtoToJson(this);
}

/// `PatientProfileResponse` — the patient's own profile record.
///
/// Distinct from the `User` the auth endpoints return: this carries the care
/// fields (condition, history, emergency contact) and a separate `address`,
/// none of which `PUT /auth/me` accepts.
@JsonSerializable()
class PatientProfileDto {
  const PatientProfileDto({
    this.name = '',
    this.phone = '',
    this.city = '',
    this.photo,
    this.photoThumb,
    this.address,
    this.history,
    this.dob,
    this.gender = 'Any',
    this.condition,
    this.emergencyName,
    this.emergencyRelation,
    this.emergencyPhone,
  });

  final String name;
  final String phone;
  final String city;

  /// Server-relative URL of the profile photo, served behind the bearer token,
  /// and of its 256px square thumbnail.
  final String? photo;
  final String? photoThumb;
  final String? address;
  final String? history;

  /// Set at signup and admin-only from there — read-only to the patient.
  final String? dob;
  final String gender;

  final String? condition;
  final String? emergencyName;
  final String? emergencyRelation;
  final String? emergencyPhone;

  factory PatientProfileDto.fromJson(Map<String, dynamic> json) =>
      _$PatientProfileDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PatientProfileDtoToJson(this);
}

/// Body for `PUT /patients/me/profile`.
///
/// Deliberately omits phone, email, dob and gender: the API stopped accepting
/// them from the patient themselves, so sending them is a 422 waiting to
/// happen. Phone still changes through `PUT /auth/me`.
@JsonSerializable(includeIfNull: false)
class PatientProfileUpdateDto {
  const PatientProfileUpdateDto({
    this.name,
    this.city,
    this.address,
    this.history,
    this.condition,
    this.emergencyName,
    this.emergencyRelation,
    this.emergencyPhone,
  });

  final String? name;
  final String? city;
  final String? address;
  final String? history;
  final String? condition;
  final String? emergencyName;
  final String? emergencyRelation;
  final String? emergencyPhone;

  factory PatientProfileUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$PatientProfileUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PatientProfileUpdateDtoToJson(this);
}
