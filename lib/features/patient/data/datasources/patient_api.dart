import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/care_models.dart';
import '../models/session_models.dart';
import '../models/therapist_models.dart';

part 'patient_api.g.dart';

/// Patient-facing endpoints: discovery, booking, sessions, reviews.
@RestApi()
abstract class PatientApi {
  factory PatientApi(Dio dio, {String baseUrl}) = _PatientApi;

  // --- Discovery -----------------------------------------------------------

  @GET('/therapists')
  Future<TherapistListDto> listTherapists({
    @Query('search') String? search,
    @Query('city') String? city,
    @Query('specialty') String? specialty,
    @Query('gender') String? gender,
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  @GET('/therapists/{id}')
  Future<TherapistDto> getTherapist(@Path('id') String id);

  /// The booking calendar. Both date params are snake_case and `YYYY-MM-DD`.
  @GET('/therapists/{id}/slots')
  Future<SlotRangeDto> getSlots(
    @Path('id') String id, {
    @Query('from_date') required String fromDate,
    @Query('to_date') required String toDate,
  });

  // --- Dashboard -----------------------------------------------------------

  @GET('/patients/me/dashboard')
  Future<PatientDashboardDto> getDashboard();

  // --- Sessions ------------------------------------------------------------

  @GET('/sessions')
  Future<SessionListDto> listSessions({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  @GET('/sessions/{id}')
  Future<SessionDto> getSession(@Path('id') String id);

  @PATCH('/sessions/{id}/reschedule')
  Future<SessionDto> reschedule(
    @Path('id') String id,
    @Body() RescheduleRequestDto body,
  );

  /// Marks the session CANCELLED.
  ///
  /// `DELETE /sessions/{id}` also exists, but it hard-deletes the row: the
  /// booking vanishes, so the patient's Cancelled tab could never show it and
  /// there is no record either side can refer back to. `PUT` keeps the row,
  /// and the route allows a patient to update their own session.
  @PUT('/sessions/{id}')
  Future<void> cancelSession(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // --- Booking -------------------------------------------------------------

  /// Creates the session and its payment in one call. This is the booking
  /// endpoint — `POST /sessions` skips the slot-conflict check.
  @POST('/payments/process')
  Future<BookingPaymentResponseDto> bookAndPay(
    @Body() BookingPaymentRequestDto body,
  );

  /// Settles a gateway payment and, if it settled, promotes the PENDING_HOLD
  /// session to a real booking. Idempotent: a second call on a completed
  /// payment returns `already_completed` rather than failing.
  @POST('/payments/{id}/confirm')
  Future<PaymentConfirmResponseDto> confirmPayment(
    @Path('id') String id,
    @Body() PaymentConfirmRequestDto body,
  );

  /// The stored status, without asking the gateway. Used to recover a payment
  /// whose checkout was abandoned or interrupted.
  @GET('/payments/{id}/status')
  Future<PaymentDto> getPaymentStatus(@Path('id') String id);

  // --- Pricing -------------------------------------------------------------

  /// The admin-set platform fee, as a percentage of the session fee.
  @GET('/settings/platform-fee')
  Future<PlatformFeeDto> getPlatformFee();

  // --- Profile -------------------------------------------------------------

  @GET('/patients/me/profile')
  Future<PatientProfileDto> getMyProfile();

  /// The care fields live here, not on `PUT /auth/me`.
  @PUT('/patients/me/profile')
  Future<PatientProfileDto> updateMyProfile(
    @Body() PatientProfileUpdateDto body,
  );

  // --- Reviews -------------------------------------------------------------

  @POST('/reviews')
  Future<ReviewDto> createReview(@Body() ReviewCreateDto body);

  /// The reviews this patient has written. 200 is the server's page ceiling.
  @GET('/reviews')
  Future<ReviewListDto> getMyReviews({@Query('limit') int limit = 200});

  /// Completed sessions this patient can still review.
  @GET('/reviews/therapists-to-rate')
  Future<List<TherapistToRateDto>> getTherapistsToRate();
}
