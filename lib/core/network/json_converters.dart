import 'package:json_annotation/json_annotation.dart';

/// Parses a date/time that may arrive as an ISO datetime, a bare `YYYY-MM-DD`,
/// or already-parsed value.
///
/// The backend is inconsistent: `SessionResponse.date` and the `createdAt` on
/// most models are real datetimes, while `PatientProfileResponse`,
/// `RecurringPatternResponse`, `BlockInfoResponse` and the untyped dict
/// endpoints hand back ISO strings. One converter accepting both keeps every
/// DTO from having to care which it is.
class FlexibleDateTimeConverter implements JsonConverter<DateTime, dynamic> {
  const FlexibleDateTimeConverter();

  @override
  DateTime fromJson(dynamic json) =>
      _parse(json) ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  dynamic toJson(DateTime object) => object.toIso8601String();
}

/// Nullable twin of [FlexibleDateTimeConverter].
class FlexibleDateTimeNullableConverter
    implements JsonConverter<DateTime?, dynamic> {
  const FlexibleDateTimeNullableConverter();

  @override
  DateTime? fromJson(dynamic json) => _parse(json);

  @override
  dynamic toJson(DateTime? object) => object?.toIso8601String();
}

DateTime? _parse(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }
  return null;
}

/// Reads a number that the API may send as int, double, or numeric string.
class FlexibleDoubleConverter implements JsonConverter<double, dynamic> {
  const FlexibleDoubleConverter();

  @override
  double fromJson(dynamic json) {
    if (json is num) return json.toDouble();
    if (json is String) return double.tryParse(json) ?? 0;
    return 0;
  }

  @override
  dynamic toJson(double object) => object;
}
