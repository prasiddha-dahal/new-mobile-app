import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/json_converters.dart';
import '../../domain/entities/package_purchase.dart';
import '../../domain/entities/therapy_package.dart';

part 'package_models.g.dart';

/// `price`, `sessionCount` and the rest are `Int` columns, but a few responses
/// (and the API's own test fixtures) hand them back as `24000.0`. Reading them
/// through one tolerant converter keeps a stray float from failing the parse of
/// an otherwise perfectly good catalogue.
class _FlexibleIntConverter implements JsonConverter<int, dynamic> {
  const _FlexibleIntConverter();

  @override
  int fromJson(dynamic json) {
    if (json is int) return json;
    if (json is num) return json.round();
    if (json is String) return int.tryParse(json) ?? num.tryParse(json)?.round() ?? 0;
    return 0;
  }

  @override
  dynamic toJson(int object) => object;
}

/// Mirrors `PackageResponse`.
@JsonSerializable()
class PackageDto {
  const PackageDto({
    required this.id,
    required this.name,
    this.tag = '',
    this.icon = 'Brain',
    required this.price,
    this.cadence = '',
    this.blurb = '',
    this.points = const [],
    this.sessionCount = 0,
    this.validityDays = 0,
    this.featured = false,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  @JsonKey(defaultValue: '')
  final String tag;

  @JsonKey(defaultValue: 'Brain')
  final String icon;

  @_FlexibleIntConverter()
  final int price;

  @JsonKey(defaultValue: '')
  final String cadence;

  @JsonKey(defaultValue: '')
  final String blurb;

  @JsonKey(defaultValue: <String>[])
  final List<String> points;

  @_FlexibleIntConverter()
  final int sessionCount;

  @_FlexibleIntConverter()
  final int validityDays;

  @JsonKey(defaultValue: false)
  final bool featured;

  @_FlexibleIntConverter()
  final int sortOrder;

  @JsonKey(defaultValue: true)
  final bool isActive;

  @FlexibleDateTimeNullableConverter()
  final DateTime? createdAt;

  @FlexibleDateTimeNullableConverter()
  final DateTime? updatedAt;

  factory PackageDto.fromJson(Map<String, dynamic> json) =>
      _$PackageDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PackageDtoToJson(this);

  TherapyPackage toEntity() => TherapyPackage(
    id: id,
    name: name,
    tag: tag,
    icon: icon,
    price: price,
    cadence: cadence,
    blurb: blurb,
    points: points,
    sessionCount: sessionCount,
    validityDays: validityDays,
    featured: featured,
    sortOrder: sortOrder,
    isActive: isActive,
  );
}

/// Mirrors `PackageListResponse`.
@JsonSerializable()
class PackageListDto {
  const PackageListDto({this.packages = const [], this.total = 0});

  @JsonKey(defaultValue: <PackageDto>[])
  final List<PackageDto> packages;

  @JsonKey(defaultValue: 0)
  final int total;

  factory PackageListDto.fromJson(Map<String, dynamic> json) =>
      _$PackageListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PackageListDtoToJson(this);
}

/// Body of `POST /packages/{id}/purchase`.
@JsonSerializable()
class PackagePurchaseRequestDto {
  const PackagePurchaseRequestDto({this.paymentMethod = 'CASH'});

  /// `CASH`, `ESEWA` or `KHALTI`; the backend uppercases it either way.
  final String paymentMethod;

  factory PackagePurchaseRequestDto.fromJson(Map<String, dynamic> json) =>
      _$PackagePurchaseRequestDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PackagePurchaseRequestDtoToJson(this);
}

/// One session already booked against a purchase, as embedded in the `/active`
/// detail response. Untyped on the wire (`list[dict]`), so every field is
/// optional here.
@JsonSerializable()
class PackageSessionDto {
  const PackageSessionDto({
    this.id = '',
    this.date = '',
    this.time = '',
    this.therapistName = '',
    this.status = '',
  });

  @JsonKey(defaultValue: '')
  final String id;

  /// `YYYY-MM-DD` — the service formats it, it is not an ISO datetime.
  @JsonKey(defaultValue: '')
  final String date;

  @JsonKey(defaultValue: '')
  final String time;

  @JsonKey(defaultValue: '')
  final String therapistName;

  @JsonKey(defaultValue: '')
  final String status;

  factory PackageSessionDto.fromJson(Map<String, dynamic> json) =>
      _$PackageSessionDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PackageSessionDtoToJson(this);

  PackageSessionRef toEntity() => PackageSessionRef(
    id: id,
    rawDate: date,
    date: DateTime.tryParse(date),
    time: time,
    therapistName: therapistName,
    status: status,
  );
}

/// Mirrors `PackagePurchaseResponse`, widened to also read
/// `PackagePurchaseDetailResponse` — the detail response is the same object
/// plus `payment` and `sessions`, so one DTO covers both and list rows simply
/// arrive with an empty `sessions`.
@JsonSerializable()
class PackagePurchaseDto {
  const PackagePurchaseDto({
    required this.id,
    this.userId = '',
    required this.packageId,
    this.packageName = '',
    this.packageTag = '',
    this.sessionsTotal = 0,
    this.sessionsUsed = 0,
    this.sessionsRemaining = 0,
    this.status = '',
    this.purchasedAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.sessions = const [],
  });

  final String id;

  @JsonKey(defaultValue: '')
  final String userId;

  final String packageId;

  @JsonKey(defaultValue: '')
  final String packageName;

  @JsonKey(defaultValue: '')
  final String packageTag;

  @_FlexibleIntConverter()
  final int sessionsTotal;

  @_FlexibleIntConverter()
  final int sessionsUsed;

  /// Sent by the server. The entity recomputes it rather than trusting it, so
  /// the three numbers on the card can never contradict one another.
  @_FlexibleIntConverter()
  final int sessionsRemaining;

  @JsonKey(defaultValue: '')
  final String status;

  @FlexibleDateTimeNullableConverter()
  final DateTime? purchasedAt;

  @FlexibleDateTimeNullableConverter()
  final DateTime? expiresAt;

  @FlexibleDateTimeNullableConverter()
  final DateTime? createdAt;

  @FlexibleDateTimeNullableConverter()
  final DateTime? updatedAt;

  /// Detail responses only.
  @JsonKey(defaultValue: <PackageSessionDto>[])
  final List<PackageSessionDto> sessions;

  factory PackagePurchaseDto.fromJson(Map<String, dynamic> json) =>
      _$PackagePurchaseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PackagePurchaseDtoToJson(this);

  PackagePurchase toEntity() => PackagePurchase(
    id: id,
    packageId: packageId,
    packageName: packageName,
    packageTag: packageTag,
    sessionsTotal: sessionsTotal,
    sessionsUsed: sessionsUsed,
    status: status,
    purchasedAt: purchasedAt,
    expiresAt: expiresAt,
    sessions: sessions.map((s) => s.toEntity()).toList(),
  );
}

/// Mirrors `PackagePurchaseListResponse`.
@JsonSerializable()
class PackagePurchaseListDto {
  const PackagePurchaseListDto({this.purchases = const [], this.total = 0});

  @JsonKey(defaultValue: <PackagePurchaseDto>[])
  final List<PackagePurchaseDto> purchases;

  @JsonKey(defaultValue: 0)
  final int total;

  factory PackagePurchaseListDto.fromJson(Map<String, dynamic> json) =>
      _$PackagePurchaseListDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PackagePurchaseListDtoToJson(this);
}
