import 'package:json_annotation/json_annotation.dart';

part 'points_models.g.dart';

/// `GET /points/me` — the figures above the fold on the rewards screen.
@JsonSerializable()
class PointBalanceDto {
  const PointBalanceDto({
    this.balance = 0,
    this.pending = 0,
    this.earned = 0,
    this.used = 0,
    this.referred = 0,
    this.pointToNpr = 1.0,
  });

  /// Spendable now. Excludes held and expired points.
  final int balance;

  /// Awarded but still inside the hold window.
  final int pending;

  /// Lifetime figures — spending does not reduce [earned].
  final int earned;
  final int used;

  final int referred;

  /// Rupees per point, from server config rather than hardcoded.
  final double pointToNpr;

  double get creditValue => balance * pointToNpr;

  factory PointBalanceDto.fromJson(Map<String, dynamic> json) =>
      _$PointBalanceDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PointBalanceDtoToJson(this);
}

/// One ledger row, rendered in "Recent activity".
@JsonSerializable()
class PointTransactionDto {
  const PointTransactionDto({
    required this.id,
    this.delta = 0,
    this.type = '',
    this.status = '',
    this.reason,
    this.refType,
    this.refId,
    this.expiresAt,
    this.createdAt,
  });

  final String id;

  /// Positive to earn, negative to spend.
  final int delta;
  final String type;
  final String status;
  final String? reason;
  final String? refType;
  final String? refId;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isCredit => delta > 0;
  bool get isHeld => status == 'PENDING';

  factory PointTransactionDto.fromJson(Map<String, dynamic> json) =>
      _$PointTransactionDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PointTransactionDtoToJson(this);
}

@JsonSerializable()
class PointTransactionListDto {
  const PointTransactionListDto({this.transactions = const [], this.total = 0});

  final List<PointTransactionDto> transactions;
  final int total;

  factory PointTransactionListDto.fromJson(Map<String, dynamic> json) =>
      _$PointTransactionListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PointTransactionListDtoToJson(this);
}

/// One row of the referral history list.
@JsonSerializable()
class ReferralEntryDto {
  const ReferralEntryDto({
    required this.id,
    this.name = '',
    this.state = 'JOINED',
    this.points,
    this.joinedAt,
  });

  final String id;
  final String name;

  /// INVITED, JOINED, PENDING, REWARDED or REVERSED.
  final String state;
  final int? points;
  final DateTime? joinedAt;

  factory ReferralEntryDto.fromJson(Map<String, dynamic> json) =>
      _$ReferralEntryDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReferralEntryDtoToJson(this);
}

@JsonSerializable()
class ReferralSummaryDto {
  const ReferralSummaryDto({
    this.code = '',
    this.link = '',
    this.awardPoints = 0,
    this.totalEarned = 0,
    this.referrals = const [],
  });

  final String code;
  final String link;
  /// The headline rate for this user's role, not a flat platform-wide figure.
  final int awardPoints;

  /// Everything earned from referrals so far -- "TOTAL EARNED" on the design.
  final int totalEarned;

  final List<ReferralEntryDto> referrals;

  factory ReferralSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ReferralSummaryDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ReferralSummaryDtoToJson(this);
}

/// Body and result of applying points to a booking.
@JsonSerializable()
class ApplyPointsRequestDto {
  const ApplyPointsRequestDto({required this.points});
  final int points;
  Map<String, dynamic> toJson() => _$ApplyPointsRequestDtoToJson(this);
  factory ApplyPointsRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ApplyPointsRequestDtoFromJson(json);
}

@JsonSerializable()
class ApplyPointsResponseDto {
  const ApplyPointsResponseDto({
    this.pointsApplied = 0,
    this.discountAmount = 0,
    this.sessionFee = 0,
    this.payable = 0,
  });

  final int pointsApplied;
  final double discountAmount;

  /// The gross fee. The therapist is still paid this in full — the platform
  /// funds the discount — so both figures are shown rather than one.
  final double sessionFee;
  final double payable;

  factory ApplyPointsResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ApplyPointsResponseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ApplyPointsResponseDtoToJson(this);
}
