import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/patient/data/datasources/patient_api.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/patient/data/repositories/availability_repository_impl.dart';

/// The API has no bulk availability endpoint, so the repository fans a batched
/// question out over the per-therapist one. These tests are the guard on that
/// fan-out: if a later refactor drops the cache, the in-flight de-duplication
/// or the concurrency ceiling, the Find screen quietly becomes N+1 again and
/// nothing else would notice.
class _FakeApi implements PatientApi {
  _FakeApi({this.slotsById = const {}, this.failFor = const {}});

  /// `therapistId -> [(date, time, status)]`.
  final Map<String, List<(String, String, String)>> slotsById;

  /// Therapist ids whose calendar throws instead of answering.
  final Set<String> failFor;

  /// Every `getSlots` call, in order, as `id|from|to`.
  final calls = <String>[];

  int _inFlight = 0;
  int maxInFlight = 0;

  int callsFor(String id) => calls.where((c) => c.startsWith('$id|')).length;

  @override
  Future<SlotRangeDto> getSlots(
    String id, {
    required String fromDate,
    required String toDate,
  }) async {
    calls.add('$id|$fromDate|$toDate');
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      // Two yields, so every request started in the same wave is genuinely
      // overlapping by the time any of them finishes.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      if (failFor.contains(id)) {
        throw DioException(
          requestOptions: RequestOptions(path: '/therapists/$id/slots'),
          response: Response(
            requestOptions: RequestOptions(path: '/therapists/$id/slots'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        );
      }
      return SlotRangeDto(
        slots: [
          for (final (date, time, status)
              in slotsById[id] ?? const <(String, String, String)>[])
            SlotDto(date: date, time: time, status: status),
        ],
      );
    } finally {
      _inFlight--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  const from = '2026-09-12';
  const to = '2026-09-26';

  test('keeps only open slots, sorted by date then time', () async {
    final api = _FakeApi(
      slotsById: {
        'a': [
          ('2026-09-13', '09:00', 'open'),
          ('2026-09-12', '14:00', 'booked'),
          ('2026-09-12', '09:00', 'open'),
          ('2026-09-12', '10:00', 'off'),
        ],
      },
    );
    final repo = AvailabilityRepositoryImpl(api);

    final answers = await repo.slotsForTherapists(
      therapistIds: ['a'],
      fromDate: from,
      toDate: to,
    );

    final slots = answers['a']!.getOrElse((_) => []);
    expect(slots.map((s) => '${s.date} ${s.time}'), [
      '2026-09-12 09:00',
      '2026-09-13 09:00',
    ]);
  });

  test('one request per therapist, keyed back by id', () async {
    final api = _FakeApi(
      slotsById: {
        'a': [('2026-09-12', '09:00', 'open')],
        'b': [('2026-09-12', '10:00', 'open')],
      },
    );
    final repo = AvailabilityRepositoryImpl(api);

    final answers = await repo.slotsForTherapists(
      therapistIds: ['a', 'b'],
      fromDate: from,
      toDate: to,
    );

    expect(answers.keys.toSet(), {'a', 'b'});
    expect(api.calls, ['a|$from|$to', 'b|$from|$to']);
  });

  test('a repeated ask for the same window costs no further requests', () async {
    final api = _FakeApi(slotsById: {'a': [('2026-09-12', '09:00', 'open')]});
    final repo = AvailabilityRepositoryImpl(api);

    for (var i = 0; i < 5; i++) {
      await repo.slotsForTherapists(
        therapistIds: ['a'],
        fromDate: from,
        toDate: to,
      );
    }

    // This is the assertion that stops the N+1 creeping back: a card that
    // rebuilds, a filter re-applied, a date changed inside the fetched window
    // — all of it is one request for the life of the screen.
    expect(api.callsFor('a'), 1);
  });

  test('the same id twice in one batch is one request', () async {
    final api = _FakeApi(slotsById: {'a': [('2026-09-12', '09:00', 'open')]});
    final repo = AvailabilityRepositoryImpl(api);

    await repo.slotsForTherapists(
      therapistIds: ['a', 'a', 'a'],
      fromDate: from,
      toDate: to,
    );

    expect(api.callsFor('a'), 1);
  });

  test('two batches racing for the same therapist share one request', () async {
    final api = _FakeApi(slotsById: {'a': [('2026-09-12', '09:00', 'open')]});
    final repo = AvailabilityRepositoryImpl(api);

    await Future.wait([
      repo.slotsForTherapists(
        therapistIds: ['a'],
        fromDate: from,
        toDate: to,
      ),
      repo.slotsForTherapists(
        therapistIds: ['a'],
        fromDate: from,
        toDate: to,
      ),
    ]);

    expect(api.callsFor('a'), 1);
  });

  test('never has more than maxConcurrent requests in the air', () async {
    final ids = [for (var i = 0; i < 20; i++) 't$i'];
    final api = _FakeApi(
      slotsById: {for (final id in ids) id: const [('2026-09-12', '09:00', 'open')]},
    );
    final repo = AvailabilityRepositoryImpl(api, maxConcurrent: 3);

    await repo.slotsForTherapists(
      therapistIds: ids,
      fromDate: from,
      toDate: to,
    );

    expect(api.calls.length, 20);
    // Twenty therapists is still twenty requests — that is the API's shape,
    // not a choice here — but they go out as waves rather than opening twenty
    // sockets and twenty simultaneous JWT validations at once.
    expect(api.maxInFlight, lessThanOrEqualTo(3));
    expect(api.maxInFlight, 3);
  });

  test('one therapist failing leaves the others answered', () async {
    final api = _FakeApi(
      slotsById: {
        'ok': [('2026-09-12', '09:00', 'open')],
        'bad': const [],
      },
      failFor: {'bad'},
    );
    final repo = AvailabilityRepositoryImpl(api);

    final answers = await repo.slotsForTherapists(
      therapistIds: ['ok', 'bad'],
      fromDate: from,
      toDate: to,
    );

    expect(answers['ok']!.isRight(), isTrue);
    expect(answers['bad']!.isLeft(), isTrue);
  });

  test('a failure is not cached, so a retry really retries', () async {
    final api = _FakeApi(failFor: {'bad'});
    final repo = AvailabilityRepositoryImpl(api);

    await repo.slotsForTherapists(
      therapistIds: ['bad'],
      fromDate: from,
      toDate: to,
    );
    await repo.slotsForTherapists(
      therapistIds: ['bad'],
      fromDate: from,
      toDate: to,
    );

    expect(api.callsFor('bad'), 2);
  });

  test('invalidate drops what was cached', () async {
    final api = _FakeApi(
      slotsById: {
        'a': [('2026-09-12', '09:00', 'open')],
        'b': [('2026-09-12', '09:00', 'open')],
      },
    );
    final repo = AvailabilityRepositoryImpl(api);

    Future<void> ask() => repo.slotsForTherapists(
      therapistIds: ['a', 'b'],
      fromDate: from,
      toDate: to,
    );

    await ask();
    repo.invalidate(['a']);
    await ask();
    expect(api.callsFor('a'), 2);
    expect(api.callsFor('b'), 1);

    repo.invalidate();
    await ask();
    expect(api.callsFor('a'), 3);
    expect(api.callsFor('b'), 2);
  });

  test('a different window is a different cache entry', () async {
    final api = _FakeApi(slotsById: {'a': [('2026-09-12', '09:00', 'open')]});
    final repo = AvailabilityRepositoryImpl(api);

    await repo.slotsForTherapists(
      therapistIds: ['a'],
      fromDate: from,
      toDate: to,
    );
    await repo.slotsForTherapists(
      therapistIds: ['a'],
      fromDate: from,
      toDate: '2026-10-30',
    );

    // Which is exactly why the horizon lives in a provider rather than being
    // recomputed at each call site: a range that drifted would miss every
    // time.
    expect(api.callsFor('a'), 2);
  });
}
