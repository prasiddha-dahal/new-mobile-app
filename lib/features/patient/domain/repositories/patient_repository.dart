import '../../../../core/location/geo_point.dart';
import '../../../../core/error/failures.dart';
import '../entities/booking_outcome.dart';
import '../entities/review.dart';
import '../entities/session.dart';
import '../entities/therapist.dart';

abstract class PatientRepository {
  Future<AppResult<List<Therapist>>> findTherapists({
    String? search,
    String? city,
    String? specialty,
    String? gender,
  });

  Future<AppResult<Therapist>> getTherapist(String id);

  /// Open and booked slots between two `YYYY-MM-DD` dates, inclusive.
  Future<AppResult<List<TherapistSlot>>> getSlots({
    required String therapistId,
    required String fromDate,
    required String toDate,
  });

  Future<AppResult<PatientDashboard>> getDashboard();

  Future<AppResult<List<Session>>> getSessions();

  /// Books a session and records its payment in one call.
  ///
  /// Returns a [BookingOutcome] rather than a [Session] because a gateway
  /// booking is not finished when this returns: it comes back as a
  /// `PENDING_HOLD` with its slot still unlocked and a checkout the patient
  /// has yet to complete.
  Future<AppResult<BookingOutcome>> bookSession({
    required String therapistId,
    required DateTime date,
    required String time,
    required String address,
    required double fee,
    String type,
    String paymentMethod,
    String? notes,
    String? walletMobile,
    GeoPoint? point,
    String? landmark,
    int pointsToUse,
  });

  /// Settles a gateway payment after the patient comes back from checkout.
  ///
  /// Returns the endpoint's `result`: a payment status, `already_completed`,
  /// or `CONFLICT` when the money settled but the slot was taken meanwhile.
  Future<AppResult<String>> confirmPayment({
    required String paymentId,
    Map<String, dynamic> params,
  });

  /// The stored status of a payment, without asking the gateway. Recovers a
  /// checkout that was abandoned or interrupted.
  Future<AppResult<String>> paymentStatus(String paymentId);

  Future<AppResult<Session>> rescheduleSession({
    required String sessionId,
    required String newDate,
    required String newTime,
  });

  Future<AppResult<void>> cancelSession(String sessionId);

  Future<AppResult<void>> reviewSession({
    required String sessionId,
    required int rating,
    String? comment,
  });

  /// Ids of the sessions the server will still accept a review for.
  ///
  /// Not "completed sessions without a review": a patient reviews a therapist
  /// once, so a second session with the same therapist is not reviewable even
  /// though nothing has been written against it.
  Future<AppResult<Set<String>>> reviewableSessionIds();

  /// The reviews the signed-in patient has already written.
  Future<AppResult<List<MyReview>>> myReviews();
}
