import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/network/error_mapper.dart';

DioException _response(int status, dynamic body) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  group('mapDioErrorToFailure', () {
    test('timeouts are distinct from connection errors', () {
      final timeout = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      );
      final offline = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

      expect(mapDioErrorToFailure(timeout), isA<TimeoutFailure>());
      expect(mapDioErrorToFailure(offline), isA<ServerUnavailableFailure>());
    });

    test('401 carries the server message', () {
      final failure = mapDioErrorToFailure(
        _response(401, {'detail': 'Invalid email or password'}),
      );

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.message, 'Invalid email or password');
    });

    test('403 "under review" becomes a pending-account failure', () {
      final failure = mapDioErrorToFailure(
        _response(403, {
          'detail':
              'Your application is under review. You will be able to '
              'log in once it is approved.',
        }),
      );

      expect(failure, isA<AccountPendingFailure>());
      expect((failure as AccountPendingFailure).status, 'PENDING');
      expect(failure.isRejected, isFalse);
    });

    test('403 "not approved" is treated as rejected', () {
      final failure = mapDioErrorToFailure(
        _response(403, {
          'detail':
              'Your application was not approved. Please contact support.',
        }),
      );

      expect(failure, isA<AccountPendingFailure>());
      expect((failure as AccountPendingFailure).isRejected, isTrue);
    });

    test('an ordinary 403 stays an authorization failure', () {
      final failure = mapDioErrorToFailure(
        _response(403, {'detail': 'Not enough permissions'}),
      );

      expect(failure, isA<UnauthorizedFailure>());
    });

    test('422 collects per-field validation messages', () {
      final failure = mapDioErrorToFailure(
        _response(422, {
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'value is not a valid email address',
            },
          ],
        }),
      );

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).fieldErrors['email'],
        'value is not a valid email address',
      );
    });

    test('429 maps to a rate-limit failure', () {
      final failure = mapDioErrorToFailure(
        _response(429, {'detail': 'Please wait 60 seconds'}),
      );

      expect(failure, isA<RateLimitFailure>());
    });

    test('503 reads as unavailable, not a generic server error', () {
      expect(
        mapDioErrorToFailure(_response(503, null)),
        isA<ServerUnavailableFailure>(),
      );
    });
  });

  group('wrapped error envelope (live API format)', () {
    // The API wraps every error as
    // {success, message, requestId, timestamp} — not FastAPI's {detail}.
    test('reads `message` instead of `detail`', () {
      final failure = mapDioErrorToFailure(
        _response(401, {
          'success': false,
          'message': 'Invalid email or password',
          'requestId': 'abc123',
          'timestamp': '2026-08-24T15:05:05Z',
        }),
      );

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.message, 'Invalid email or password');
    });

    test('still recognises a pending therapist through the new envelope', () {
      final failure = mapDioErrorToFailure(
        _response(403, {
          'success': false,
          'message':
              'Your application is under review. You will be able to '
              'log in once it is approved.',
        }),
      );

      expect(failure, isA<AccountPendingFailure>());
      expect((failure as AccountPendingFailure).status, 'PENDING');
    });

    test(
      'a 401 "pending approval" is a pending account, not a dead session',
      () {
        // get_current_user rejects unapproved therapists with 401, unlike the
        // login route which uses 403.
        final failure = mapDioErrorToFailure(
          _response(401, {
            'success': false,
            'message': 'Your account is pending approval',
          }),
        );

        expect(failure, isA<AccountPendingFailure>());
      },
    );

    test('reads the new per-field validation shape', () {
      final failure = mapDioErrorToFailure(
        _response(422, {
          'success': false,
          'message': 'Validation error',
          'errors': [
            {
              'field': 'body → email',
              'message': 'value is not a valid email address',
            },
            {'field': 'body → password', 'message': 'Field required'},
          ],
        }),
      );

      expect(failure, isA<ValidationFailure>());
      final fields = (failure as ValidationFailure).fieldErrors;
      // The "body → " prefix is stripped so the UI can key by field name.
      expect(fields['email'], 'value is not a valid email address');
      expect(fields['password'], 'Field required');
    });

    test('the old {detail} shape still parses', () {
      final failure = mapDioErrorToFailure(
        _response(409, {'detail': 'Email already registered'}),
      );

      expect(failure, isA<ConflictFailure>());
      expect(failure.message, 'Email already registered');
    });

    test('an envelope with no message falls back to sensible copy', () {
      final failure = mapDioErrorToFailure(
        _response(404, {'success': false, 'requestId': 'x'}),
      );

      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, isNotEmpty);
    });
  });
}
