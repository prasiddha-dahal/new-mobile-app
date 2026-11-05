import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/user.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});

  final String email;
  final String password;

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestDtoToJson(this);
}

/// Mirrors `SignupRequest` in pv-core-api/app/models/auth.py.
///
/// `password` is nullable because therapists apply without one — the backend
/// generates a temporary password and emails it after an admin approves.
@JsonSerializable(includeIfNull: false)
class SignupRequestDto {
  const SignupRequestDto({
    required this.name,
    required this.email,
    this.password,
    this.role = 'PATIENT',
    this.city,
    this.phone,
    this.specialty,
    this.gender,
    this.dob,
    this.license,
    this.experience,
    this.fee,
    this.bio,
    this.documents,
    this.referralCode,
  });

  final String name;
  final String email;

  /// Code the new user typed, or that arrived on a referral link. Sent only
  /// at signup — attribution is never applied retroactively.
  final String? referralCode;
  final String? password;
  final String role;
  final String? city;
  final String? phone;
  final String? specialty;
  final String? gender;
  final String? dob;
  final String? license;
  final int? experience;
  final double? fee;
  final String? bio;
  final List<VerificationDocDto>? documents;

  factory SignupRequestDto.fromJson(Map<String, dynamic> json) =>
      _$SignupRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SignupRequestDtoToJson(this);
}

@JsonSerializable(includeIfNull: false)
class VerificationDocDto {
  const VerificationDocDto({
    required this.documentType,
    required this.url,
    this.fileName,
    this.fileSize,
  });

  final String documentType;
  final String url;
  final String? fileName;
  final int? fileSize;

  factory VerificationDocDto.fromJson(Map<String, dynamic> json) =>
      _$VerificationDocDtoFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationDocDtoToJson(this);
}

/// Mirrors `TokenResponse`.
///
/// `access_token` is **nullable**: a therapist signup deliberately returns a
/// user with no token, because the account cannot log in until an admin
/// approves it.
@JsonSerializable()
class TokenResponseDto {
  const TokenResponseDto({
    this.accessToken,
    this.tokenType = 'bearer',
    required this.user,
  });

  @JsonKey(name: 'access_token')
  final String? accessToken;

  @JsonKey(name: 'token_type')
  final String tokenType;

  final UserResponseDto user;

  factory TokenResponseDto.fromJson(Map<String, dynamic> json) =>
      _$TokenResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TokenResponseDtoToJson(this);
}

@JsonSerializable()
class UserResponseDto {
  const UserResponseDto({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.city,
    this.phone,
    this.specialty,
    required this.status,
    this.photo,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? city;
  final String? phone;
  final String? specialty;
  final String status;
  final String? photo;
  final bool mustChangePassword;

  factory UserResponseDto.fromJson(Map<String, dynamic> json) =>
      _$UserResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$UserResponseDtoToJson(this);

  User toEntity() => User(
    id: id,
    name: name,
    email: email,
    role: role,
    city: city,
    phone: phone,
    specialty: specialty,
    status: status,
    photo: photo,
    mustChangePassword: mustChangePassword,
  );
}

@JsonSerializable()
class SendOtpRequestDto {
  const SendOtpRequestDto({required this.email, this.name = ''});

  final String email;
  final String name;

  factory SendOtpRequestDto.fromJson(Map<String, dynamic> json) =>
      _$SendOtpRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SendOtpRequestDtoToJson(this);
}

@JsonSerializable()
class VerifyOtpRequestDto {
  const VerifyOtpRequestDto({
    required this.email,
    required this.code,
    this.purpose = 'signup',
  });

  final String email;
  final String code;
  final String purpose;

  factory VerifyOtpRequestDto.fromJson(Map<String, dynamic> json) =>
      _$VerifyOtpRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$VerifyOtpRequestDtoToJson(this);
}

@JsonSerializable()
class ForgotPasswordRequestDto {
  const ForgotPasswordRequestDto({required this.email, this.name = ''});

  final String email;
  final String name;

  factory ForgotPasswordRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ForgotPasswordRequestDtoToJson(this);
}

@JsonSerializable()
class ResetPasswordRequestDto {
  const ResetPasswordRequestDto({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  final String email;
  final String code;

  @JsonKey(name: 'new_password')
  final String newPassword;

  factory ResetPasswordRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ResetPasswordRequestDtoToJson(this);
}

@JsonSerializable()
class UserUpdateDto {
  const UserUpdateDto({this.name, this.city, this.phone, this.specialty});

  final String? name;
  final String? city;
  final String? phone;
  final String? specialty;

  factory UserUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$UserUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$UserUpdateDtoToJson(this);
}

/// `{"message": ..., "resend_after": N}` from the OTP endpoints.
@JsonSerializable()
class OtpSentResponseDto {
  const OtpSentResponseDto({this.message = '', this.resendAfter = 0});

  final String message;

  @JsonKey(name: 'resend_after')
  final int resendAfter;

  factory OtpSentResponseDto.fromJson(Map<String, dynamic> json) =>
      _$OtpSentResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$OtpSentResponseDtoToJson(this);
}
