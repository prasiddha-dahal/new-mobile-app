import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../patient/data/models/session_models.dart';
import '../../../patient/data/models/therapist_models.dart' show SlotRangeDto;
import '../models/therapist_models.dart';

part 'therapist_api.g.dart';

/// Therapist-side endpoints.
///
/// Note the earnings prefix is `/therapist` (singular), unlike `/therapists`
/// everywhere else.
@RestApi()
abstract class TherapistApi {
  factory TherapistApi(Dio dio, {String baseUrl}) = _TherapistApi;

  // --- Dashboard and profile ----------------------------------------------

  @GET('/therapists/me/dashboard')
  Future<TherapistDashboardDto> getDashboard();

  @GET('/therapists/me/profile')
  Future<TherapistProfileDto> getProfile();

  @PUT('/therapists/me/profile')
  Future<TherapistProfileDto> updateProfile(
    @Body() TherapistProfileUpdateDto body,
  );

  // --- Sessions -------------------------------------------------------------

  /// Role-scoped server-side: a therapist gets their own sessions, and only
  /// this branch fills `patientName` / `patientPhone`.
  @GET('/sessions')
  Future<SessionListDto> listSessions({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  /// Accept, decline or complete — all are a status change.
  @PUT('/sessions/{id}')
  Future<SessionDto> updateSession(
    @Path('id') String id,
    @Body() SessionUpdateDto body,
  );

  @POST('/sessions/{id}/start')
  Future<SessionDto> startSession(@Path('id') String id);

  @POST('/sessions/{id}/end')
  Future<SessionDto> endSession(@Path('id') String id);

  // --- Patients -------------------------------------------------------------

  /// `limit` defaults to 10 server-side, so it is always sent explicitly.
  @GET('/patients/my-patients')
  Future<MyPatientListDto> listMyPatients({
    @Query('search') String? search,
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  // --- Reviews --------------------------------------------------------------

  /// The signed-in therapist's reviews, newest first.
  @GET('/therapists/me/reviews')
  Future<TherapistReviewsDto> listMyReviews({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 50,
  });

  // --- Availability ---------------------------------------------------------

  @GET('/availability/slots')
  Future<SlotRangeDto> getOwnSlots({
    @Query('from_date') required String fromDate,
    @Query('to_date') required String toDate,
  });

  /// The stored weekly pattern. Answers the server's defaults rather than 404
  /// for a therapist who has never saved one.
  @GET('/availability/working-hours')
  Future<WorkingHoursDto> getWorkingHours();

  /// Saves the weekly pattern **and** writes the slot rows that make it real.
  ///
  /// `PUT /availability/working-hours` exists and is not used: it stores the
  /// pattern without writing rows, and the slot grid ignores `daysOfWeek`, so
  /// on its own it would save the hours and silently drop the days off.
  ///
  /// [options] carries a longer receive timeout than the 15s Dio default. The
  /// server writes each slot with its own read-then-write pair, so a full
  /// seven-day week over the fortnight horizon is ~135 sequential database
  /// round trips: measured at 13.7s against a local server, which is inside
  /// the default only by accident. Without the override a save that is
  /// working would be reported to the therapist as a timeout while it went on
  /// to succeed — the worst possible answer for this particular screen.
  @POST('/availability/generate')
  Future<SlotUpdateCountDto> generateAvailability(
    @Body() GenerateAvailabilityDto body,
    @DioOptions() Options options,
  );

  @POST('/availability/slot')
  Future<void> setSlot(@Body() SlotUpdateDto body);

  @POST('/availability/recurring')
  Future<RecurringApplyDto> applyRecurring(
    @Body() RecurringPatternCreateDto body,
  );

  /// Emergency day off — goes to an admin for approval rather than blocking
  /// the calendar directly.
  @POST('/availability/block-request')
  Future<BlockRequestCreatedDto> requestBlock(@Body() BlockRequestDto body);

  /// Returns a bare array whose shape differs between THERAPIST and ADMIN.
  @GET('/availability/block-requests')
  Future<List<BlockRequestItemDto>> listBlockRequests();

  // --- Earnings -------------------------------------------------------------

  /// Page-based, not skip-based.
  @GET('/therapist/earnings/transactions')
  Future<TransactionListDto> listTransactions({
    @Query('page') int page = 1,
    @Query('limit') int limit = 50,
  });

  @GET('/therapist/earnings/payouts')
  Future<PayoutListDto> listPayouts({
    @Query('page') int page = 1,
    @Query('limit') int limit = 24,
  });
}
