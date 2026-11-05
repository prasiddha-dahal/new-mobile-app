import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/booking_outcome.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/therapist.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_api.dart';
import '../models/session_models.dart';

class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl(this._api);

  final PatientApi _api;

  Future<AppResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<Therapist>>> findTherapists({
    String? search,
    String? city,
    String? specialty,
    String? gender,
  }) => _guard(() async {
    final response = await _api.listTherapists(
      search: _blankToNull(search),
      city: _blankToNull(city),
      specialty: _blankToNull(specialty),
      gender: _blankToNull(gender),
    );
    return response.therapists.map((t) => t.toEntity()).toList();
  });

  @override
  Future<AppResult<Therapist>> getTherapist(String id) =>
      _guard(() async => (await _api.getTherapist(id)).toEntity());

  @override
  Future<AppResult<List<TherapistSlot>>> getSlots({
    required String therapistId,
    required String fromDate,
    required String toDate,
  }) => _guard(() async {
    final response = await _api.getSlots(
      therapistId,
      fromDate: fromDate,
      toDate: toDate,
    );
    return response.slots.map((s) => s.toEntity()).toList();
  });

  @override
  Future<AppResult<PatientDashboard>> getDashboard() =>
      _guard(() async => (await _api.getDashboard()).toEntity());

  @override
  Future<AppResult<List<Session>>> getSessions() => _guard(() async {
    final response = await _api.listSessions();
    return response.sessions.map((s) => s.toEntity()).toList();
  });

  @override
  Future<AppResult<BookingOutcome>> bookSession({
    required String therapistId,
    required DateTime date,
    required String time,
    required String address,
    required double fee,
    String type = 'HOME_VISIT',
    String paymentMethod = 'CASH',
    String? notes,
    String? walletMobile,
    GeoPoint? point,
    String? landmark,
    int pointsToUse = 0,
  }) => _guard(() async {
    final response = await _api.bookAndPay(
      BookingPaymentRequestDto(
        therapistId: therapistId,
        date: date,
        time: time,
        type: type,
        address: address,
        latitude: point?.latitude,
        longitude: point?.longitude,
        landmark: _blankToNull(landmark),
        pointsToUse: pointsToUse,
        fee: fee,
        notes: notes,
        paymentMethod: paymentMethod,
        walletMobile: walletMobile,
      ),
    );
    // `response.initiation` used to be dropped on the floor here, which is
    // where the "booked!" screen for an unpaid hold came from.
    final init = response.initiation;
    return BookingOutcome(
      session: response.session.toEntity(),
      paymentId: response.payment.id,
      paymentStatus: response.payment.status,
      checkout: init == null
          ? null
          : GatewayCheckout(
              paymentId: response.payment.id,
              kind: CheckoutKind.fromWire(init.type),
              url: init.url,
              // The gateway signs these; they are posted back verbatim.
              formFields: {
                for (final e in (init.formFields ?? const {}).entries)
                  e.key: '${e.value}',
              },
              expiresAt: init.expiresAt,
            ),
    );
  });

  @override
  Future<AppResult<String>> confirmPayment({
    required String paymentId,
    Map<String, dynamic> params = const {},
  }) => _guard(() async {
    final response = await _api.confirmPayment(
      paymentId,
      PaymentConfirmRequestDto(params: params),
    );
    return response.result;
  });

  @override
  Future<AppResult<String>> paymentStatus(String paymentId) =>
      _guard(() async => (await _api.getPaymentStatus(paymentId)).status);

  @override
  Future<AppResult<Session>> rescheduleSession({
    required String sessionId,
    required String newDate,
    required String newTime,
  }) => _guard(() async {
    final response = await _api.reschedule(
      sessionId,
      RescheduleRequestDto(newDate: newDate, newTime: newTime),
    );
    return response.toEntity();
  });

  @override
  Future<AppResult<void>> cancelSession(String sessionId) =>
      _guard(() => _api.cancelSession(sessionId, {'status': 'CANCELLED'}));

  @override
  Future<AppResult<void>> reviewSession({
    required String sessionId,
    required int rating,
    String? comment,
  }) => _guard(() async {
    await _api.createReview(
      ReviewCreateDto(
        sessionId: sessionId,
        rating: rating,
        comment: _blankToNull(comment),
      ),
    );
  });

  @override
  Future<AppResult<Set<String>>> reviewableSessionIds() => _guard(() async {
    final rows = await _api.getTherapistsToRate();
    return {for (final row in rows) row.sessionId};
  });

  @override
  Future<AppResult<List<MyReview>>> myReviews() => _guard(() async {
    final page = await _api.getMyReviews();
    return [
      for (final r in page.reviews)
        MyReview(
          id: r.id,
          sessionId: r.sessionId,
          therapistId: r.therapistId,
          rating: r.rating,
          comment: r.comment,
        ),
    ];
  });

  /// An empty filter must be omitted, not sent as `""` — the backend treats a
  /// blank string as a real "contains" filter and returns nothing.
  static String? _blankToNull(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
