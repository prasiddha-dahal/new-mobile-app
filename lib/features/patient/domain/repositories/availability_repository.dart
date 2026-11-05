import '../../../../core/error/failures.dart';
import '../entities/therapist.dart';

/// Discovery's view of who is free when.
///
/// ## Why this interface is plural
///
/// The API has no endpoint that answers "which therapists are free at T".
/// `GET /therapists` filters on search, city, specialty and gender and
/// nothing else, and the only availability primitives —
/// `GET /availability/slots?therapist_id=` and `GET /therapists/{id}/slots` —
/// are strictly one therapist per call. Asking about a list of twenty
/// therapists is therefore twenty requests today.
///
/// So the interface is shaped the way the *question* is shaped rather than
/// the way today's transport is: one call, many therapists, one result each.
/// The fan-out, the concurrency limit and the cache all live behind it in
/// [AvailabilityRepositoryImpl]. When the API grows a bulk endpoint — a
/// `therapist_ids` parameter on `/availability/slots`, or an `available_on`
/// filter on `/therapists` — that implementation changes and nothing above
/// this line does.
abstract class AvailabilityRepository {
  /// Open slots for each of [therapistIds] between two `YYYY-MM-DD` dates.
  ///
  /// Returns **one result per therapist**, not one for the batch: a single
  /// therapist's calendar failing must not erase the answers for everyone
  /// else, because "we could not check" and "they are busy" have to render
  /// differently.
  ///
  /// Only open slots come back. Booked and blocked ones are dropped here so
  /// that no caller has to remember to.
  Future<Map<String, AppResult<List<TherapistSlot>>>> slotsForTherapists({
    required List<String> therapistIds,
    required String fromDate,
    required String toDate,
  });

  /// Forgets what was cached for [therapistIds], so the next request goes to
  /// the network. Pass nothing to forget everything.
  void invalidate([Iterable<String>? therapistIds]);
}
