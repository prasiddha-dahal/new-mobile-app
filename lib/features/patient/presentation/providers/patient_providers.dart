import '../../../../core/network/error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/patient_api.dart';
import '../../data/repositories/patient_repository_impl.dart';
import '../../domain/entities/booking_outcome.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/therapist.dart';
import '../../domain/repositories/patient_repository.dart';

final patientApiProvider = Provider<PatientApi>((ref) {
  return PatientApi(ref.watch(dioProvider));
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepositoryImpl(ref.watch(patientApiProvider));
});

/// Unwraps an [AppResult] into an AsyncValue, so screens get one loading /
/// error / data shape to render instead of hand-rolling each.
Future<T> _unwrap<T>(Future<AppResult<T>> future) async {
  final result = await future;
  return result.fold((failure) => throw failure, (value) => value);
}

/// Home-screen counts and the next upcoming session.
final patientDashboardProvider = FutureProvider<PatientDashboard>((ref) {
  return _unwrap(ref.watch(patientRepositoryProvider).getDashboard());
});

/// The sessions the signed-in patient can still leave a review for.
///
/// "Leave a review" used to appear on every completed session, whether or not
/// it had been reviewed, so a patient who had already rated a session was
/// offered the button again and met a refusal when they used it. The server
/// is the one that knows, and its rule is stricter than "no review yet" -- a
/// therapist can only be reviewed once -- so this reads its answer rather than
/// guessing from the session list.
final reviewableSessionIdsProvider = FutureProvider<Set<String>>((ref) {
  return _unwrap(ref.watch(patientRepositoryProvider).reviewableSessionIds());
});

/// The platform fee percentage every checkout shows and the server charges.
///
/// One number, set by the admin: the web, the app and the booking route all
/// read it, rather than each holding its own (QA FIN-02 found 15%, 5% and
/// nothing). Read directly from the API -- it is a setting, not patient data.
///
/// A server that has no such setting -- the route is missing (404) or answers
/// with nothing -- charges no platform fee, so that reads as 0%. Only a
/// server that cannot be reached at all is an error.
final platformFeePercentProvider = FutureProvider.autoDispose<double>((
  ref,
) async {
  try {
    final dto = await ref.watch(patientApiProvider).getPlatformFee();
    return dto.percent;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return 0;
    throw mapDioErrorToFailure(e);
  } on TypeError {
    // An empty body cannot be read as the setting.
    return 0;
  }
});

/// The platform fee in whole rupees, rounded half up -- the server's rule, so
/// the amount on the button is the amount charged.
double platformFeeFor(double sessionFee, double percent) =>
    (sessionFee * percent / 100 + 0.5).floorToDouble();

/// What the patient's card shows as owed at booking: the session less any
/// points, plus the platform fee on the full session fee.
double bookingTotal({
  required double sessionFee,
  required double percent,
  int points = 0,
  double pointToNpr = 1.0,
}) {
  final discount = points * pointToNpr;
  final session = (sessionFee - discount).clamp(0, sessionFee).toDouble();
  return session + platformFeeFor(sessionFee, percent);
}

/// What the signed-in patient has already reviewed, so a completed session can
/// say "You rated this" instead of showing nothing once the button is gone.
final myReviewsProvider = FutureProvider<List<MyReview>>((ref) {
  return _unwrap(ref.watch(patientRepositoryProvider).myReviews());
});

/// Search/filter state for the Find-therapist screen.
class TherapistQuery {
  const TherapistQuery({this.search = '', this.specialty});

  final String search;

  /// Null means "All" — the prototype's first chip.
  final String? specialty;

  TherapistQuery copyWith({
    String? search,
    String? specialty,
    bool clearSpecialty = false,
  }) => TherapistQuery(
    search: search ?? this.search,
    specialty: clearSpecialty ? null : (specialty ?? this.specialty),
  );

  @override
  bool operator ==(Object other) =>
      other is TherapistQuery &&
      other.search == search &&
      other.specialty == specialty;

  @override
  int get hashCode => Object.hash(search, specialty);
}

final therapistQueryProvider = StateProvider<TherapistQuery>(
  (_) => const TherapistQuery(),
);

/// Therapist list for the current [therapistQueryProvider].
final therapistListProvider = FutureProvider<List<Therapist>>((ref) {
  final query = ref.watch(therapistQueryProvider);
  return _unwrap(
    ref
        .watch(patientRepositoryProvider)
        .findTherapists(search: query.search, specialty: query.specialty),
  );
});

/// The handful of therapists shown on the home screen, highest-rated first.
final featuredTherapistsProvider = FutureProvider<List<Therapist>>((ref) async {
  final all = await _unwrap(
    ref.watch(patientRepositoryProvider).findTherapists(),
  );
  final sorted = [...all]..sort((a, b) => b.rating.compareTo(a.rating));
  return sorted.take(5).toList();
});

final therapistDetailProvider = FutureProvider.family<Therapist, String>((
  ref,
  id,
) {
  return _unwrap(ref.watch(patientRepositoryProvider).getTherapist(id));
});

/// Slots for one therapist over the next [slotWindowDays] days.
const slotWindowDays = 14;

/// Fetched fresh for each screen that shows them (autoDispose), and
/// invalidated after a booking, reschedule or cancellation: a long-lived cache
/// kept offering a time just booked, and days that had already gone.
final therapistSlotsProvider = FutureProvider.autoDispose
    .family<List<TherapistSlot>, String>((ref, therapistId) {
      final now = DateTime.now();
      final end = now.add(const Duration(days: slotWindowDays));
      return _unwrap(
        ref
            .watch(patientRepositoryProvider)
            .getSlots(
              therapistId: therapistId,
              fromDate: formatDateKey(now),
              toDate: formatDateKey(end),
            ),
      );
    });

/// All of the signed-in patient's sessions, newest first.
final patientSessionsProvider = FutureProvider<List<Session>>((ref) {
  return _unwrap(ref.watch(patientRepositoryProvider).getSessions());
});

/// `YYYY-MM-DD`, the format every date query parameter expects.
String formatDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Booking, rescheduling, cancelling and reviewing — the mutating actions.
///
/// Each refreshes the lists it invalidates so the UI updates without a manual
/// reload.
final patientActionsProvider = Provider<PatientActions>((ref) {
  return PatientActions(ref);
});

class PatientActions {
  PatientActions(this._ref);
  final Ref _ref;

  PatientRepository get _repo => _ref.read(patientRepositoryProvider);

  Future<AppResult<BookingOutcome>> book({
    required String therapistId,
    required DateTime date,
    required String time,
    required String address,
    required double fee,
    String type = 'HOME_VISIT',
    String paymentMethod = 'CASH',
    String? notes,
    GeoPoint? point,
    String? landmark,
    int pointsToUse = 0,
  }) async {
    final result = await _repo.bookSession(
      therapistId: therapistId,
      date: date,
      time: time,
      address: address,
      fee: fee,
      type: type,
      paymentMethod: paymentMethod,
      notes: notes,
      point: point,
      landmark: landmark,
      pointsToUse: pointsToUse,
    );
    // Either way the slot list is stale: the time was just booked, or the
    // server refused it because someone else did.
    _ref.invalidate(therapistSlotsProvider(therapistId));
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  /// Settles a gateway payment once the patient returns from checkout.
  ///
  /// The session views are refreshed on every outcome, not just success: a
  /// hold that failed or lost its slot has to stop showing as a booking.
  Future<AppResult<String>> confirmPayment({
    required String paymentId,
    Map<String, dynamic> params = const {},
  }) async {
    final result = await _repo.confirmPayment(
      paymentId: paymentId,
      params: params,
    );
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  Future<AppResult<String>> paymentStatus(String paymentId) =>
      _repo.paymentStatus(paymentId);

  Future<AppResult<Session>> reschedule({
    required String sessionId,
    required String newDate,
    required String newTime,
  }) async {
    final result = await _repo.rescheduleSession(
      sessionId: sessionId,
      newDate: newDate,
      newTime: newTime,
    );
    // The old time is free again and the new one taken (or someone else
    // took it): every slot list is stale.
    _ref.invalidate(therapistSlotsProvider);
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  Future<AppResult<void>> cancel(String sessionId) async {
    final result = await _repo.cancelSession(sessionId);
    result.match((_) {}, (_) {
      _ref.invalidate(therapistSlotsProvider);
      _invalidateSessionViews();
    });
    return result;
  }

  Future<AppResult<void>> review({
    required String sessionId,
    required int rating,
    String? comment,
  }) async {
    final result = await _repo.reviewSession(
      sessionId: sessionId,
      rating: rating,
      comment: comment,
    );
    // Refreshed on a failure too. The usual failure is a 409 -- the session or
    // the therapist was already reviewed, from another device or an earlier
    // attempt that timed out after the server had saved it -- and the button
    // that led here must go away rather than invite the same refusal again.
    _ref.invalidate(reviewableSessionIdsProvider);
    _ref.invalidate(myReviewsProvider);
    result.match((_) {}, (_) {
      _ref.invalidate(patientSessionsProvider);
      _ref.invalidate(therapistListProvider);
    });
    return result;
  }

  void _invalidateSessionViews() {
    _ref.invalidate(patientSessionsProvider);
    _ref.invalidate(patientDashboardProvider);
  }
}
