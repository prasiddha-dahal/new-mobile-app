import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/therapist.dart';
import '../../domain/repositories/availability_repository.dart';
import '../datasources/patient_api.dart';

/// Fans one batched question out over the per-therapist endpoint the API
/// actually has, and does the three things that stop that becoming an N+1.
///
/// 1. **A success is cached** under (therapist, from, to). The Find screen
///    asks for the same fourteen-day window every time, so a therapist is
///    fetched once per session however often their card is rebuilt, scrolled
///    past, re-filtered or re-sorted. Changing the filter's *date* costs
///    nothing at all, because the day asked about is already inside the
///    window that was fetched.
/// 2. **Concurrent asks for the same therapist share one request.** Two cards
///    cannot both be on screen, but the filter and a card can ask in the same
///    frame, and a scroll can re-ask while the first request is in flight.
/// 3. **At most [maxConcurrent] requests are in the air.** Filtering a list of
///    a hundred therapists is still a hundred requests — that is the API's
///    shape, not a choice made here — but it goes out as waves of four rather
///    than a hundred sockets and a hundred simultaneous JWT validations.
///
/// A **failure is deliberately not cached**: "we could not check" has to be
/// retryable, and caching it would freeze a transient timeout into a
/// permanent unknown for the life of the screen.
class AvailabilityRepositoryImpl implements AvailabilityRepository {
  AvailabilityRepositoryImpl(this._api, {this.maxConcurrent = 4})
    : assert(maxConcurrent > 0);

  final PatientApi _api;

  /// How many slot requests may be outstanding at once.
  final int maxConcurrent;

  final Map<String, List<TherapistSlot>> _cache = {};
  final Map<String, Future<AppResult<List<TherapistSlot>>>> _inFlight = {};

  static String _key(String id, String from, String to) => '$id|$from|$to';

  @override
  Future<Map<String, AppResult<List<TherapistSlot>>>> slotsForTherapists({
    required List<String> therapistIds,
    required String fromDate,
    required String toDate,
  }) async {
    final results = <String, AppResult<List<TherapistSlot>>>{};

    // Answer from cache first, and de-duplicate the ids: a caller that asks
    // for the same therapist twice in one batch should cost one request, not
    // two, and should not be able to make the wave scheduling lopsided.
    final toFetch = <String>[];
    for (final id in therapistIds) {
      final cached = _cache[_key(id, fromDate, toDate)];
      if (cached != null) {
        results[id] = Right(cached);
      } else if (!results.containsKey(id) && !toFetch.contains(id)) {
        toFetch.add(id);
      }
    }

    for (var i = 0; i < toFetch.length; i += maxConcurrent) {
      final wave = toFetch.skip(i).take(maxConcurrent).toList();
      final answers = await Future.wait(
        wave.map((id) => _fetchOne(id, fromDate, toDate)),
      );
      for (var j = 0; j < wave.length; j++) {
        results[wave[j]] = answers[j];
      }
    }

    return results;
  }

  Future<AppResult<List<TherapistSlot>>> _fetchOne(
    String therapistId,
    String fromDate,
    String toDate,
  ) {
    final key = _key(therapistId, fromDate, toDate);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final request = _request(therapistId, fromDate, toDate).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  Future<AppResult<List<TherapistSlot>>> _request(
    String therapistId,
    String fromDate,
    String toDate,
  ) async {
    try {
      final response = await _api.getSlots(
        therapistId,
        fromDate: fromDate,
        toDate: toDate,
      );
      // Booked and blocked slots are dropped here rather than at every call
      // site. `off` is what the API writes for a blocked or closed slot;
      // anything that is not `open` is not availability.
      final open = response.slots
          .where((s) => s.isOpen)
          .map((s) => s.toEntity())
          .toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.time.compareTo(b.time);
        });
      _cache[_key(therapistId, fromDate, toDate)] = open;
      return Right(open);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  void invalidate([Iterable<String>? therapistIds]) {
    if (therapistIds == null) {
      _cache.clear();
      return;
    }
    final ids = therapistIds.toSet();
    _cache.removeWhere((key, _) => ids.contains(key.split('|').first));
  }
}
