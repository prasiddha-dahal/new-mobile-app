import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/patient/data/datasources/patient_api.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/session_models.dart';
import 'package:sahayatri_care_connect/features/patient/data/repositories/patient_repository_impl.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/booking_outcome.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';

/// A gateway booking is not a booking until the money settles.
///
/// `POST /payments/process` returns three things — the session, the payment,
/// and an `initiation` describing the checkout the patient still has to go
/// through. The repository kept the first and dropped the rest. So picking
/// eSewa produced a `PENDING_HOLD` session with its slot deliberately left
/// unlocked, the app showed the booking-confirmed screen, and twenty minutes
/// later the server's sweep cancelled it. The patient believed they had an
/// appointment; nobody was coming.
///
/// These pin the parsing and the shape that carries it, which is where the
/// information was being lost. The screen that uses it needs a real WebView
/// and is exercised by hand against a live gateway.
class _FakeApi implements PatientApi {
  _FakeApi({this.response, this.confirmResult = 'COMPLETED'});

  final BookingPaymentResponseDto? response;
  final String confirmResult;

  BookingPaymentRequestDto? booked;
  String? confirmedId;
  Map<String, dynamic>? confirmedParams;

  @override
  Future<BookingPaymentResponseDto> bookAndPay(
    BookingPaymentRequestDto body,
  ) async {
    booked = body;
    return response!;
  }

  @override
  Future<PaymentConfirmResponseDto> confirmPayment(
    String id,
    PaymentConfirmRequestDto body,
  ) async {
    confirmedId = id;
    confirmedParams = body.params;
    return PaymentConfirmResponseDto(
      payment: const PaymentDto(id: 'pay-1', amount: 1575, status: 'COMPLETED'),
      result: confirmResult,
    );
  }

  @override
  Future<PaymentDto> getPaymentStatus(String id) async =>
      PaymentDto(id: id, amount: 1575, status: 'PENDING');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

SessionDto _session(String status) => SessionDto(
      id: 'sess-1',
      therapistId: 't-1',
      patientId: 'p-1',
      date: DateTime(2026, 10, 1, 10),
      time: '10:00',
      type: 'HOME_VISIT',
      status: status,
      fee: 1500,
    );

Future<BookingOutcome> _book(_FakeApi api) async {
  final repo = PatientRepositoryImpl(api);
  final result = await repo.bookSession(
    therapistId: 't-1',
    date: DateTime(2026, 10, 1, 10),
    time: '10:00',
    address: 'Jhamsikhel, Lalitpur',
    fee: 1500,
    paymentMethod: 'ESEWA',
  );
  return result.getRight().toNullable()!;
}

void main() {
  group('the booking response keeps its checkout', () {
    test('an eSewa booking comes back needing a form POST', () async {
      final api = _FakeApi(
        response: BookingPaymentResponseDto(
          session: _session('PENDING_HOLD'),
          payment: const PaymentDto(
            id: 'pay-1',
            amount: 1575,
            status: 'PENDING',
            method: 'ESEWA',
          ),
          initiation: const GatewayInitiationDto(
            type: 'form',
            url: 'https://rc-epay.esewa.com.np/api/epay/main/v2/form',
            formFields: {
              'amount': '1575',
              'transaction_uuid': 'pay-1',
              'signature': 'sig',
            },
          ),
        ),
      );

      final outcome = await _book(api);

      expect(outcome.needsCheckout, isTrue);
      expect(outcome.isConfirmed, isFalse,
          reason: 'a hold must never read as a confirmed booking');
      expect(outcome.checkout!.kind, CheckoutKind.form);
      expect(outcome.checkout!.paymentId, 'pay-1');
      expect(
        outcome.checkout!.formFields['signature'],
        'sig',
        reason: 'the signature covers the amount, so the fields can only be '
            'forwarded, never rebuilt on this side',
      );
      expect(outcome.checkout!.isUsable, isTrue);
    });

    test('a Khalti booking comes back needing a redirect', () async {
      final api = _FakeApi(
        response: BookingPaymentResponseDto(
          session: _session('PENDING_HOLD'),
          payment: const PaymentDto(id: 'pay-2', amount: 1575, method: 'KHALTI'),
          initiation: const GatewayInitiationDto(
            type: 'redirect',
            url: 'https://test-pay.khalti.com/?pidx=abc',
          ),
        ),
      );

      final outcome = await _book(api);

      expect(outcome.checkout!.kind, CheckoutKind.redirect);
      expect(outcome.checkout!.url, contains('khalti'));
      expect(outcome.checkout!.isUsable, isTrue);
    });

    test('a cash booking has no checkout and is final', () async {
      final api = _FakeApi(
        response: BookingPaymentResponseDto(
          session: _session('SCHEDULED'),
          payment: const PaymentDto(
            id: 'pay-3',
            amount: 1500,
            status: 'COMPLETED',
            method: 'CASH',
          ),
        ),
      );

      final outcome = await _book(api);

      expect(outcome.needsCheckout, isFalse);
      expect(outcome.isConfirmed, isTrue);
      expect(outcome.checkout, isNull);
    });

    test('a gateway that returns nothing to open is not usable', () async {
      // A misconfigured gateway: the server said "form" and gave no url. The
      // screen has to say so rather than sit on a blank page.
      final api = _FakeApi(
        response: BookingPaymentResponseDto(
          session: _session('PENDING_HOLD'),
          payment: const PaymentDto(id: 'pay-4', amount: 1575),
          initiation: const GatewayInitiationDto(type: 'form'),
        ),
      );

      final outcome = await _book(api);

      expect(outcome.needsCheckout, isTrue);
      expect(outcome.checkout!.isUsable, isFalse);
    });
  });

  group('the held session', () {
    test('PENDING_HOLD is a status the app knows', () {
      // It was missing from the enum, so a hold read as `unknown` and every
      // list that filters on status silently dropped it.
      expect(SessionStatus.fromWire('PENDING_HOLD'), SessionStatus.pendingHold);
    });

    test('and is not counted as upcoming', () async {
      const held = SessionStatus.pendingHold;
      expect(held.isAwaitingPayment, isTrue);
      expect(held.isUpcoming, isFalse,
          reason: 'showing a hold beside confirmed bookings is how a patient '
              'comes to believe they have an appointment they do not have');
      expect(held.canCancel, isFalse);
      expect(held.canReschedule, isFalse);
    });
  });

  group('confirming', () {
    test('forwards the gateway params verbatim', () async {
      // eSewa's response signature lives inside `data`; re-encoding it would
      // break verification.
      final api = _FakeApi();
      final repo = PatientRepositoryImpl(api);

      final result = await repo.confirmPayment(
        paymentId: 'pay-1',
        params: {'data': 'eyJzdGF0dXMiOiJDT01QTEVURSJ9'},
      );

      expect(result.getRight().toNullable(), 'COMPLETED');
      expect(api.confirmedId, 'pay-1');
      expect(api.confirmedParams!['data'], 'eyJzdGF0dXMiOiJDT01QTEVURSJ9');
    });

    test('an empty params map is still a valid confirm', () async {
      // Khalti falls back to the pidx stored at initiate-time, which is what
      // makes a "check again" button work after an interrupted checkout.
      final api = _FakeApi(confirmResult: 'PENDING');
      final repo = PatientRepositoryImpl(api);

      final result = await repo.confirmPayment(paymentId: 'pay-2');

      expect(result.getRight().toNullable(), 'PENDING');
      expect(api.confirmedParams, isEmpty);
    });

    test('CONFLICT is passed through rather than read as success', () async {
      // Paid, but the slot went to somebody else while the hold was open.
      final api = _FakeApi(confirmResult: 'CONFLICT');
      final repo = PatientRepositoryImpl(api);

      final result = await repo.confirmPayment(paymentId: 'pay-1');

      expect(result.getRight().toNullable(), 'CONFLICT');
    });

    test('a failure is a Left, not a swallowed success', () async {
      final api = _ThrowingApi();
      final repo = PatientRepositoryImpl(api);

      final result = await repo.confirmPayment(paymentId: 'pay-1');

      expect(result.isLeft(), isTrue);
    });
  });
}

class _ThrowingApi extends _FakeApi {
  @override
  Future<PaymentConfirmResponseDto> confirmPayment(
    String id,
    PaymentConfirmRequestDto body,
  ) async {
    final options = RequestOptions(path: '/payments/$id/confirm');
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionTimeout,
    );
  }
}
