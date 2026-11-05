import 'package:dio/dio.dart';
import '../error/failures.dart';

/// Maps Dio exceptions to typed [Failure] instances.
Failure mapDioErrorToFailure(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();

    case DioExceptionType.connectionError:
      return const ServerUnavailableFailure();

    case DioExceptionType.badCertificate:
      return const ServerUnavailableFailure(
        'The server certificate could not be verified.',
      );

    case DioExceptionType.badResponse:
      return _mapStatusCode(error.response);

    case DioExceptionType.cancel:
      return const NetworkFailure('Request was cancelled.');

    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();

    case DioExceptionType.unknown:
      return const ServerUnavailableFailure();
  }
}

Failure _mapStatusCode(Response? response) {
  final statusCode = response?.statusCode ?? 0;
  final body = response?.data;
  final detail = _messageString(body);

  switch (statusCode) {
    case 400:
      return ValidationFailure(
        _extractFieldErrors(body),
        detail ?? 'Invalid request',
      );
    case 401:
      // A therapist whose application is still pending is rejected by the
      // dependency layer with 401 rather than 403, so it has to be recognised
      // here too or it would read as an expired session.
      final lower401 = (detail ?? '').toLowerCase();
      if (lower401.contains('pending approval')) {
        return AccountPendingFailure('PENDING', detail!);
      }
      return UnauthorizedFailure(detail ?? 'Session expired. Please log in again.');
    case 403:
      // The backend uses 403 both for "therapist not approved yet" and for
      // ordinary permission errors; the copy is the only thing that separates
      // them, so match on it to route pending therapists to the right screen.
      final text = detail ?? '';
      final lower = text.toLowerCase();
      if (lower.contains('under review')) {
        return AccountPendingFailure('PENDING', text);
      }
      if (lower.contains('not approved')) {
        return AccountPendingFailure('REJECTED', text);
      }
      return UnauthorizedFailure(text.isEmpty ? 'You do not have permission.' : text);
    case 404:
      return NotFoundFailure(detail ?? 'Resource not found');
    case 409:
      return ConflictFailure(detail ?? 'Resource already exists');
    case 422:
      return ValidationFailure(_extractFieldErrors(body), detail ?? 'Validation error');
    case 429:
      return RateLimitFailure(detail ?? 'Too many attempts. Please wait.');
    case 500:
    case 502:
      return const ServerFailure('Server error. Please try again later.');
    case 503:
    case 504:
      return const ServerUnavailableFailure(
        'The server is unavailable right now. Please try again later.',
      );
    default:
      return ServerFailure('Unexpected error (code $statusCode)');
  }
}

/// Pulls the human-readable message out of an error body.
///
/// The API wraps errors in `{success, message, requestId, timestamp}`. Plain
/// FastAPI `{"detail": ...}` is still accepted because a few responses (and any
/// unwrapped handler) can still produce it.
String? _messageString(dynamic body) {
  if (body is! Map) return null;

  final message = body['message'];
  if (message is String && message.isNotEmpty) return message;

  final detail = body['detail'];
  if (detail is String && detail.isNotEmpty) return detail;

  return null;
}

/// Per-field validation messages, keyed by field name.
///
/// New shape: `errors: [{field: "body → email", message: "..."}]`.
/// Old shape: `detail: [{loc: ["body","email"], msg: "..."}]`.
Map<String, String> _extractFieldErrors(dynamic body) {
  if (body is! Map) return {};
  final errors = <String, String>{};

  final wrapped = body['errors'];
  if (wrapped is List) {
    for (final err in wrapped) {
      if (err is Map && err['message'] is String) {
        errors[_fieldName(err['field'])] = err['message'] as String;
      }
    }
    if (errors.isNotEmpty) return errors;
  }

  final detail = body['detail'];
  if (detail is List) {
    for (final err in detail) {
      if (err is Map && err['loc'] is List && err['msg'] is String) {
        final field = (err['loc'] as List).last.toString();
        errors[field] = err['msg'] as String;
      }
    }
  }
  return errors;
}

/// `"body → email"` identifies the field as `email`; the prefix is the request
/// part, which the UI has no use for.
String _fieldName(dynamic raw) {
  final text = raw?.toString() ?? '';
  if (text.isEmpty) return 'unknown';
  final parts = text.split('→').map((p) => p.trim()).where((p) => p.isNotEmpty);
  return parts.isEmpty ? text : parts.last;
}
