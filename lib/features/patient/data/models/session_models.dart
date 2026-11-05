import 'package:json_annotation/json_annotation.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/network/json_converters.dart';
import '../../domain/entities/session.dart';

part 'session_models.g.dart';

/// Mirrors `SessionResponse` (and `SessionPaymentResponse`, which is identical).
@JsonSerializable()
class SessionDto {
  const SessionDto({
    required this.id,
    required this.therapistId,
    this.therapistName = '',
    required this.patientId,
    this.patientName = '',
    this.patientPhone = '',
    required this.date,
    required this.time,
    required this.type,
    required this.status,
    this.address = '',
    this.latitude,
    this.longitude,
    this.landmark,
    required this.fee,
    this.notes,
    this.therapistPhoto,
    this.therapistPhotoThumb,
    this.patientPhoto,
    this.patientPhotoThumb,
  });

  final String id;
  final String therapistId;

  /// The therapist's public photo. Null when they have none.
  final String? therapistPhoto;
  final String? therapistPhotoThumb;

  /// The patient's photo, sent only on a therapist's own views. Null for
  /// everyone else and for a patient who has not set one.
  final String? patientPhoto;
  final String? patientPhotoThumb;

  /// Never null, but `""` when the relation was not joined.
  @JsonKey(defaultValue: '')
  final String therapistName;

  final String patientId;

  @JsonKey(defaultValue: '')
  final String patientName;

  @JsonKey(defaultValue: '')
  final String patientPhone;

  @FlexibleDateTimeConverter()
  final DateTime date;

  final String time;
  final String type;
  final String status;

  @JsonKey(defaultValue: '')
  final String address;

  /// The pinned point of a home visit. Both or neither; null when the patient
  /// only typed an address, and null on a cancelled or unpaid session.
  final double? latitude;
  final double? longitude;

  /// Directions the address cannot give, e.g. "blue gate opposite the temple".
  final String? landmark;

  @FlexibleDoubleConverter()
  final double fee;

  final String? notes;

  factory SessionDto.fromJson(Map<String, dynamic> json) =>
      _$SessionDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SessionDtoToJson(this);

  Session toEntity() => Session(
    id: id,
    therapistId: therapistId,
    therapistName: therapistName,
    patientId: patientId,
    patientName: patientName,
    patientPhone: patientPhone,
    date: date,
    time: time,
    type: type,
    status: SessionStatus.fromWire(status),
    address: address,
    point: latitude != null && longitude != null
        ? GeoPoint(latitude!, longitude!)
        : null,
    landmark: landmark,
    fee: fee,
    notes: notes,
    therapistPhotoUrl: therapistPhoto,
    therapistPhotoThumbUrl: therapistPhotoThumb,
    patientPhotoUrl: patientPhoto,
    patientPhotoThumbUrl: patientPhotoThumb,
  );
}

/// The wrapper key is `sessions`, not `items`.
@JsonSerializable()
class SessionListDto {
  const SessionListDto({this.sessions = const [], this.total = 0});

  final List<SessionDto> sessions;
  final int total;

  factory SessionListDto.fromJson(Map<String, dynamic> json) =>
      _$SessionListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SessionListDtoToJson(this);
}

/// Body for `PATCH /sessions/{id}/reschedule`.
@JsonSerializable()
class RescheduleRequestDto {
  const RescheduleRequestDto({required this.newDate, required this.newTime});

  /// `YYYY-MM-DD`.
  final String newDate;

  /// `HH:MM`.
  final String newTime;

  factory RescheduleRequestDto.fromJson(Map<String, dynamic> json) =>
      _$RescheduleRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$RescheduleRequestDtoToJson(this);
}

/// Body for `POST /payments/process` — the real booking call, which creates the
/// session and its payment together.
@JsonSerializable(includeIfNull: false)
class BookingPaymentRequestDto {
  const BookingPaymentRequestDto({
    required this.therapistId,
    required this.date,
    required this.time,
    this.type = 'HOME_VISIT',
    required this.address,
    this.latitude,
    this.longitude,
    this.landmark,
    required this.fee,
    this.notes,
    this.pointsToUse = 0,
    this.currency = 'NPR',
    this.paymentMethod = 'CASH',
    this.paymentType,
    this.platformFee = 0,
    this.walletMobile,
  });

  final String therapistId;

  /// A full ISO-8601 datetime — not a bare date.
  @FlexibleDateTimeConverter()
  final DateTime date;

  final String time;
  final String type;
  final String address;

  /// The pinned point, when the patient used their current location. The API
  /// refuses one without the other, or one outside Nepal.
  final double? latitude;
  final double? longitude;
  final String? landmark;
  final double fee;
  final String? notes;

  /// Spent on this booking by the server, which charges what is left.
  final int pointsToUse;
  final String currency;

  /// `CASH`, `ESEWA`, or `KHALTI`; uppercased server-side either way.
  final String paymentMethod;
  final String? paymentType;
  final double platformFee;
  final String? walletMobile;

  factory BookingPaymentRequestDto.fromJson(Map<String, dynamic> json) =>
      _$BookingPaymentRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BookingPaymentRequestDtoToJson(this);
}

@JsonSerializable()
class PaymentDto {
  const PaymentDto({
    required this.id,
    required this.amount,
    this.method = 'CASH',
    this.status = 'PENDING',
    this.sessionId,
    this.currency = 'NPR',
  });

  final String id;

  @FlexibleDoubleConverter()
  final double amount;

  final String method;
  final String status;
  final String? sessionId;
  final String currency;

  factory PaymentDto.fromJson(Map<String, dynamic> json) =>
      _$PaymentDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentDtoToJson(this);
}

/// How the client is meant to start a payment on the gateway's own page.
///
/// `type` is the whole contract:
///   `redirect` — open [url] (Khalti's hosted checkout).
///   `form`     — POST [formFields] to [url] (eSewa takes a signed form, and
///                the signature covers the amount, so the fields cannot be
///                rebuilt on this side).
///   `manual`   — nothing to pay online; the booking is already final.
@JsonSerializable()
class GatewayInitiationDto {
  const GatewayInitiationDto({
    required this.type,
    this.url,
    this.formFields,
    this.expiresAt,
  });

  final String type;
  final String? url;
  final Map<String, dynamic>? formFields;
  final DateTime? expiresAt;

  factory GatewayInitiationDto.fromJson(Map<String, dynamic> json) =>
      _$GatewayInitiationDtoFromJson(json);
  Map<String, dynamic> toJson() => _$GatewayInitiationDtoToJson(this);
}

/// Response of `POST /payments/process`.
@JsonSerializable()
class BookingPaymentResponseDto {
  const BookingPaymentResponseDto({
    required this.session,
    required this.payment,
    this.initiation,
  });

  final SessionDto session;
  final PaymentDto payment;

  /// Present only for a gateway method. Null for cash, which is settled on
  /// the visit and whose session is `SCHEDULED` the moment it is created.
  ///
  /// Ignoring this was the bug: a gateway booking comes back as
  /// `PENDING_HOLD` with the slot deliberately unlocked, so a patient who
  /// picked eSewa was shown a booking confirmation for a session the server
  /// would cancel twenty minutes later.
  final GatewayInitiationDto? initiation;

  factory BookingPaymentResponseDto.fromJson(Map<String, dynamic> json) =>
      _$BookingPaymentResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BookingPaymentResponseDtoToJson(this);
}

/// Body for `POST /payments/{id}/confirm`.
///
/// [params] is whatever the gateway put on the return URL. eSewa needs its
/// `data` blob (the response signature is inside it); Khalti reads `pidx` but
/// falls back to the one stored at initiate-time, so an empty map still
/// verifies.
@JsonSerializable()
class PaymentConfirmRequestDto {
  const PaymentConfirmRequestDto({this.params = const {}});

  final Map<String, dynamic> params;

  factory PaymentConfirmRequestDto.fromJson(Map<String, dynamic> json) =>
      _$PaymentConfirmRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentConfirmRequestDtoToJson(this);
}

/// Response of `POST /payments/{id}/confirm`.
///
/// [result] is the settled payment status (`COMPLETED`, `FAILED`,
/// `CANCELLED`, `PENDING`), or one of two words the endpoint uses for
/// outcomes a status cannot express: `already_completed`, and `CONFLICT` when
/// the money settled but somebody else took the slot while the hold was open.
@JsonSerializable()
class PaymentConfirmResponseDto {
  const PaymentConfirmResponseDto({
    required this.payment,
    required this.result,
  });

  final PaymentDto payment;
  final String result;

  factory PaymentConfirmResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PaymentConfirmResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentConfirmResponseDtoToJson(this);
}

/// Body for `POST /reviews`. `therapistId` is derived from the session.
@JsonSerializable(includeIfNull: false)
class ReviewCreateDto {
  const ReviewCreateDto({
    required this.sessionId,
    required this.rating,
    this.comment,
  });

  final String sessionId;

  /// 1–5.
  final int rating;
  final String? comment;

  factory ReviewCreateDto.fromJson(Map<String, dynamic> json) =>
      _$ReviewCreateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewCreateDtoToJson(this);
}

@JsonSerializable()
class ReviewDto {
  const ReviewDto({
    required this.id,
    required this.sessionId,
    required this.therapistId,
    required this.rating,
    this.comment,
  });

  final String id;
  final String sessionId;
  final String therapistId;
  final int rating;
  final String? comment;

  factory ReviewDto.fromJson(Map<String, dynamic> json) =>
      _$ReviewDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewDtoToJson(this);
}

/// `GET /reviews`: the signed-in patient's own reviews, newest first.
@JsonSerializable()
class ReviewListDto {
  const ReviewListDto({this.reviews = const [], this.total = 0});

  final List<ReviewDto> reviews;
  final int total;

  factory ReviewListDto.fromJson(Map<String, dynamic> json) =>
      _$ReviewListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewListDtoToJson(this);
}

/// A session the signed-in patient can still review, from
/// `GET /reviews/therapists-to-rate`.
///
/// The server decides what is reviewable, and its rule is stricter than "the
/// session is completed and has no review": a patient may review a therapist
/// **once**, so every other session with a therapist they have already
/// reviewed is excluded too. Reading this list instead of re-deriving the rule
/// on the device is what keeps the two from disagreeing.
@JsonSerializable()
class TherapistToRateDto {
  const TherapistToRateDto({
    required this.sessionId,
    required this.therapistId,
    this.therapistName = '',
  });

  final String sessionId;
  final String therapistId;
  final String therapistName;

  factory TherapistToRateDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistToRateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistToRateDtoToJson(this);
}

/// `GET /settings/platform-fee`.
@JsonSerializable()
class PlatformFeeDto {
  const PlatformFeeDto({this.percent = 0});

  @FlexibleDoubleConverter()
  final double percent;

  factory PlatformFeeDto.fromJson(Map<String, dynamic> json) =>
      _$PlatformFeeDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PlatformFeeDtoToJson(this);
}
