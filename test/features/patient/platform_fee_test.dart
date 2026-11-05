import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/providers/core_providers.dart';
import 'package:sahayatri_care_connect/core/utils/formatters.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Future<double> _percent(int status, String body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = _Adapter(status, body);
  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  addTearDown(container.dispose);
  return container.read(platformFeePercentProvider.future);
}

/// QA FIN-02: the app showed no platform fee while the web added 5%. The app
/// now reads the admin's percentage and must arrive at the same rupees the
/// server charges, so the button never quotes a different amount.
void main() {
  group('platformFeeFor matches the server', () {
    test('whole rupees', () {
      expect(platformFeeFor(1300, 5), 65);
      expect(platformFeeFor(1500, 15), 225);
    });

    test('rounds half up', () {
      expect(platformFeeFor(1010, 5), 51); // 50.5
      expect(platformFeeFor(1009, 5), 50); // 50.45
    });

    test('zero percent is no fee', () {
      expect(platformFeeFor(1500, 0), 0);
    });
  });

  group('bookingTotal', () {
    test('session plus the fee', () {
      expect(bookingTotal(sessionFee: 1700, percent: 5), 1785);
    });

    test('points come off the session, not the fee', () {
      expect(bookingTotal(sessionFee: 1700, percent: 5, points: 700), 1085);
    });

    test('points can never make the session negative', () {
      expect(bookingTotal(sessionFee: 100, percent: 5, points: 500), 5);
    });
  });

  test('formatPercent drops a trailing zero', () {
    expect(formatPercent(5), '5');
    expect(formatPercent(7.5), '7.5');
    expect(formatPercent(12.25), '12.25');
  });

  // A server without the setting charges no fee: booking must not be blocked
  // on a route that does not exist there.
  group('reading the setting', () {
    test("reads the admin's percentage", () async {
      expect(await _percent(200, jsonEncode({'percent': 5})), 5);
    });

    test('a server without the setting means no fee', () async {
      expect(await _percent(404, jsonEncode({'detail': 'Not Found'})), 0);
    });

    test('an empty answer means no fee', () async {
      expect(await _percent(200, ''), 0);
    });

    test('a server error still blocks, rather than guessing', () async {
      expect(_percent(500, '{}'), throwsA(anything));
    });
  });
}
