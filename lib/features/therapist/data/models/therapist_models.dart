import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/json_converters.dart';

part 'therapist_models.g.dart';

/// `GET /therapists/me/dashboard`.
@JsonSerializable()
class TherapistDashboardDto {
  const TherapistDashboardDto({
    this.name = '',
    this.sessionsThisWeek = 0,
    this.totalPatients = 0,
    this.earningsThisMonth = 0,
    this.averageRating = 0,
    this.todaySessions = const [],
    this.referralCode = '',
    this.referralLink = '',
  });

  final String name;
  final int sessionsThisWeek;
  final int totalPatients;

  @FlexibleDoubleConverter()
  final double earningsThisMonth;

  @FlexibleDoubleConverter()
  final double averageRating;

  final List<TodaySessionDto> todaySessions;
  final String referralCode;

  /// The shareable invite URL built around [referralCode].
  final String referralLink;

  factory TherapistDashboardDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistDashboardDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistDashboardDtoToJson(this);
}

@JsonSerializable()
class TodaySessionDto {
  const TodaySessionDto({
    required this.id,
    this.time = '',
    this.patient = '',
    this.patientId = '',
    this.address = '',
    this.type = '',
    this.status = '',
    this.patientPhoto,
    this.patientPhotoThumb,
  });

  final String id;
  final String time;

  /// The patient's photo and 256px thumbnail; null when not set.
  final String? patientPhoto;
  final String? patientPhotoThumb;

  /// The patient's display name — the field is `patient`, not `patientName`.
  final String patient;
  final String patientId;
  final String address;
  final String type;
  final String status;

  factory TodaySessionDto.fromJson(Map<String, dynamic> json) =>
      _$TodaySessionDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TodaySessionDtoToJson(this);
}

/// `GET /therapists/me/profile` — the only shape carrying email, phone and docs.
@JsonSerializable()
class TherapistProfileDto {
  const TherapistProfileDto({
    required this.id,
    required this.userId,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.city = '',
    this.specialty = '',
    this.gender = '',
    this.price = 0,
    this.experience = 0,
    this.bio = '',
    this.mediaUrls,
    this.photo,
    this.photoThumb,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String specialty;
  final String gender;

  @FlexibleDoubleConverter()
  final double price;

  final int experience;
  final String bio;

  /// Comma-separated, not an array.
  final String? mediaUrls;
  final String? photo;
  final String? photoThumb;

  factory TherapistProfileDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistProfileDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistProfileDtoToJson(this);
}

@JsonSerializable(includeIfNull: false)
class TherapistProfileUpdateDto {
  const TherapistProfileUpdateDto({
    this.name,
    this.phone,
    this.city,
    this.specialty,
    this.gender,
    this.price,
    this.experience,
    this.bio,
  });

  final String? name;
  final String? phone;
  final String? city;
  final String? specialty;
  final String? gender;
  final double? price;
  final int? experience;
  final String? bio;

  factory TherapistProfileUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistProfileUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistProfileUpdateDtoToJson(this);
}

/// One row of `GET /patients/my-patients`.
@JsonSerializable()
class MyPatientDto {
  const MyPatientDto({
    required this.id,
    this.name = '',
    this.phone = '',
    this.condition = '',
    this.sessions = 0,
    this.last = '',
    this.photo,
    this.photoThumb,
  });

  final String id;
  final String name;
  final String phone;
  final String condition;
  final int sessions;

  /// The patient's photo and its 256px thumbnail. Null when not set.
  final String? photo;
  final String? photoThumb;

  /// ISO datetime, or `""` when the patient has no recorded visit.
  final String last;

  factory MyPatientDto.fromJson(Map<String, dynamic> json) =>
      _$MyPatientDtoFromJson(json);
  Map<String, dynamic> toJson() => _$MyPatientDtoToJson(this);

  DateTime? get lastVisit => last.isEmpty ? null : DateTime.tryParse(last);
}

@JsonSerializable()
class MyPatientListDto {
  const MyPatientListDto({this.patients = const [], this.total = 0});

  final List<MyPatientDto> patients;
  final int total;

  factory MyPatientListDto.fromJson(Map<String, dynamic> json) =>
      _$MyPatientListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$MyPatientListDtoToJson(this);
}

/// One row of `GET /therapists/me/reviews`.
@JsonSerializable()
class TherapistReviewDto {
  const TherapistReviewDto({
    required this.id,
    this.name = '',
    this.stars = 0,
    this.text = '',
    this.createdAt = '',
    this.photo,
    this.photoThumb,
  });

  final String id;

  /// How the reviewer appears: `Asha R.`. The server never sends the surname.
  final String name;
  final int stars;
  final String text;

  /// ISO datetime.
  final String createdAt;

  /// The reviewer's photo and thumbnail, for the therapist they reviewed.
  final String? photo;
  final String? photoThumb;

  factory TherapistReviewDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistReviewDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistReviewDtoToJson(this);

  DateTime? get created => DateTime.tryParse(createdAt);
}

@JsonSerializable()
class TherapistReviewsDto {
  const TherapistReviewsDto({
    this.reviews = const [],
    this.total = 0,
    this.averageRating = 0,
  });

  final List<TherapistReviewDto> reviews;
  final int total;

  @FlexibleDoubleConverter()
  final double averageRating;

  factory TherapistReviewsDto.fromJson(Map<String, dynamic> json) =>
      _$TherapistReviewsDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TherapistReviewsDtoToJson(this);
}

/// One row of `GET /therapist/earnings/transactions`.
///
/// `id` is the **session** id, not a payment id.
@JsonSerializable()
class TransactionDto {
  const TransactionDto({
    required this.id,
    this.patientName = 'Unknown',
    this.date = '',
    this.time = '',
    this.fee = 0,
    this.status = '',
    this.paymentMethod = '',
    this.paymentStatus = 'PENDING',
    this.patientPhoto,
    this.patientPhotoThumb,
  });

  final String id;
  final String patientName;

  /// The patient's photo and 256px thumbnail. Null when they have none, or when
  /// the session was cancelled -- the server withholds it then.
  final String? patientPhoto;
  final String? patientPhotoThumb;
  final String date;
  final String time;

  @FlexibleDoubleConverter()
  final double fee;

  final String status;
  final String paymentMethod;
  final String paymentStatus;

  factory TransactionDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionDtoToJson(this);
}

@JsonSerializable()
class TransactionListDto {
  const TransactionListDto({this.transactions = const [], this.total = 0});

  final List<TransactionDto> transactions;
  final int total;

  factory TransactionListDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionListDtoToJson(this);
}

/// One row of `GET /therapist/earnings/payouts`.
///
/// Synthesized server-side from completed sessions grouped by month, so
/// `status` is title case (`Completed` / `Pending`) unlike every other status.
@JsonSerializable()
class PayoutDto {
  const PayoutDto({
    required this.id,
    this.month = '',
    this.earnings = 0,
    this.sessions = 0,
    this.status = 'Pending',
  });

  final String id;
  final String month;

  @FlexibleDoubleConverter()
  final double earnings;

  final int sessions;
  final String status;

  factory PayoutDto.fromJson(Map<String, dynamic> json) =>
      _$PayoutDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PayoutDtoToJson(this);

  bool get isPaid => status.toLowerCase() == 'completed';
}

@JsonSerializable()
class PayoutListDto {
  const PayoutListDto({this.payouts = const [], this.total = 0});

  final List<PayoutDto> payouts;
  final int total;

  factory PayoutListDto.fromJson(Map<String, dynamic> json) =>
      _$PayoutListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PayoutListDtoToJson(this);
}

/// Body for `PUT /sessions/{id}` — used to accept, decline or complete.
@JsonSerializable(includeIfNull: false)
class SessionUpdateDto {
  const SessionUpdateDto({this.status, this.notes});

  final String? status;
  final String? notes;

  factory SessionUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$SessionUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SessionUpdateDtoToJson(this);
}

/// Body for `POST /availability/slot`.
@JsonSerializable()
class SlotUpdateDto {
  const SlotUpdateDto({
    required this.date,
    required this.time,
    required this.status,
  });

  /// `YYYY-MM-DD`.
  final String date;

  /// `HH:MM`.
  final String time;

  /// `open`, `off`, or `booked`.
  final String status;

  factory SlotUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$SlotUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SlotUpdateDtoToJson(this);
}

/// Body for `POST /availability/recurring`.
@JsonSerializable()
class RecurringPatternCreateDto {
  const RecurringPatternCreateDto({required this.days, required this.sessions});

  /// Weekday indices, Sunday = 0.
  final List<int> days;

  /// Time-block names, e.g. `Morning`.
  final List<String> sessions;

  factory RecurringPatternCreateDto.fromJson(Map<String, dynamic> json) =>
      _$RecurringPatternCreateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$RecurringPatternCreateDtoToJson(this);
}

/// Body for `POST /availability/block-request` (and `/block-range`).
@JsonSerializable(includeIfNull: false)
class BlockRequestDto {
  const BlockRequestDto({
    required this.dateFrom,
    this.dateTo,
    this.daysOfWeek = const [],
    this.partsOfDay = const [],
    this.reason = 'Time off',
    this.notify = true,
  });

  final String dateFrom;
  final String? dateTo;
  final List<String> daysOfWeek;
  final List<String> partsOfDay;
  final String reason;
  final bool notify;

  factory BlockRequestDto.fromJson(Map<String, dynamic> json) =>
      _$BlockRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BlockRequestDtoToJson(this);
}

/// One row of `GET /availability/block-requests` in its THERAPIST shape.
@JsonSerializable()
class BlockRequestItemDto {
  const BlockRequestItemDto({
    required this.id,
    this.dateFrom = '',
    this.dateTo = '',
    this.reason = '',
    this.status = 'pending',
    this.adminNotes,
  });

  final String id;
  final String dateFrom;
  final String dateTo;
  final String reason;
  final String status;
  final String? adminNotes;

  factory BlockRequestItemDto.fromJson(Map<String, dynamic> json) =>
      _$BlockRequestItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BlockRequestItemDtoToJson(this);
}

/// Response of `POST /availability/recurring`.
@JsonSerializable()
class RecurringApplyDto {
  const RecurringApplyDto({
    this.affected = 0,
    this.skippedPast = 0,
    this.patternId = '',
  });

  final int affected;
  final int skippedPast;
  final String patternId;

  factory RecurringApplyDto.fromJson(Map<String, dynamic> json) =>
      _$RecurringApplyDtoFromJson(json);
  Map<String, dynamic> toJson() => _$RecurringApplyDtoToJson(this);
}

/// Response of `POST /availability/block-request`.
@JsonSerializable()
class BlockRequestCreatedDto {
  const BlockRequestCreatedDto({
    this.id = '',
    this.dateFrom = '',
    this.dateTo = '',
    this.status = 'pending',
  });

  final String id;
  final String dateFrom;
  final String dateTo;
  final String status;

  factory BlockRequestCreatedDto.fromJson(Map<String, dynamic> json) =>
      _$BlockRequestCreatedDtoFromJson(json);
  Map<String, dynamic> toJson() => _$BlockRequestCreatedDtoToJson(this);
}

/// `GET /availability/working-hours`, and the shape stored under the
/// `wh_{userId}` setting key.
///
/// Every field is defaulted to the server's own `DEFAULT_WORKING_HOURS`, so a
/// therapist who has never saved — whose record does not exist yet — decodes
/// to the same pattern the server would synthesise a grid from.
@JsonSerializable()
class WorkingHoursDto {
  const WorkingHoursDto({
    this.start = '09:00',
    this.end = '18:00',
    this.slotInterval = 60,
    this.sessionDuration = 60,
    this.breakDuration = 0,
    this.daysOfWeek = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
  });

  /// `HH:MM`, wall clock, no offset.
  final String start;
  final String end;

  /// Stored but unused by the slot grid, which steps by
  /// `sessionDuration + breakDuration`. Read back and echoed so that saving
  /// does not drop it.
  final int slotInterval;

  final int sessionDuration;
  final int breakDuration;

  /// `Sun` … `Sat`. Stored by the API but **not applied** by
  /// `GET /availability/slots`, which emits every calendar date in the range —
  /// see `TherapistAvailabilityRepository` for what that means for saving.
  final List<String> daysOfWeek;

  factory WorkingHoursDto.fromJson(Map<String, dynamic> json) =>
      _$WorkingHoursDtoFromJson(json);
  Map<String, dynamic> toJson() => _$WorkingHoursDtoToJson(this);
}

/// Body for `POST /availability/generate`.
///
/// The one write that makes a weekly pattern real: it saves the working hours
/// *and* writes an `open` row on every selected day and an `off` row on every
/// unselected one, across `dateFrom`–`dateTo`.
///
/// `dateTo` is always sent. Omitting it makes the server default to a year
/// ahead, which is roughly 3,000 individually-written rows in one request.
@JsonSerializable()
class GenerateAvailabilityDto {
  const GenerateAvailabilityDto({
    required this.dateFrom,
    required this.dateTo,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.sessionDuration,
    required this.breakDuration,
  });

  /// `YYYY-MM-DD`, inclusive.
  final String dateFrom;
  final String dateTo;

  /// `Sun` … `Sat`. Days not named here are written `off`.
  final List<String> daysOfWeek;

  /// `HH:MM`.
  final String startTime;
  final String endTime;

  final int sessionDuration;
  final int breakDuration;

  factory GenerateAvailabilityDto.fromJson(Map<String, dynamic> json) =>
      _$GenerateAvailabilityDtoFromJson(json);
  Map<String, dynamic> toJson() => _$GenerateAvailabilityDtoToJson(this);
}

/// `{"updated": n}` — the response of `POST /availability/generate` and of
/// `POST /availability/bulk`.
///
/// `updated` counts only the slots *opened*. The server discards its own
/// count of the ones it closed, so a save that turns a day off and nothing
/// else legitimately reports a smaller number than the therapist changed.
@JsonSerializable()
class SlotUpdateCountDto {
  const SlotUpdateCountDto({this.updated = 0});

  final int updated;

  factory SlotUpdateCountDto.fromJson(Map<String, dynamic> json) =>
      _$SlotUpdateCountDtoFromJson(json);
  Map<String, dynamic> toJson() => _$SlotUpdateCountDtoToJson(this);
}
