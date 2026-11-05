import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/data/datasources/therapist_api.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/data/repositories/therapist_availability_repository_impl.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/entities/working_hours.dart';
import 'package:sahayatri_care_connect/features/therapist/domain/usecases/availability_usecases.dart';

/// Records what the repository sent and answers with whatever the test wants.
///
/// `noSuchMethod` covers the dozen [TherapistApi] methods this feature never
/// touches; anything unexpected throws rather than quietly returning null.
class _FakeApi implements TherapistApi {
  _FakeApi({
    this.workingHours = const WorkingHoursDto(),
    this.updated = 0,
    this.error,
  });

  final WorkingHoursDto workingHours;
  final int updated;
  final Object? error;

  GenerateAvailabilityDto? sentBody;
  Options? sentOptions;

  @override
  Future<WorkingHoursDto> getWorkingHours() async {
    if (error != null) throw error!;
    return workingHours;
  }

  @override
  Future<SlotUpdateCountDto> generateAvailability(
    GenerateAvailabilityDto body,
    Options options,
  ) async {
    sentBody = body;
    sentOptions = options;
    if (error != null) throw error!;
    return SlotUpdateCountDto(updated: updated);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

DioException _http(int statusCode) => DioException(
  requestOptions: RequestOptions(path: '/availability/generate'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/availability/generate'),
    statusCode: statusCode,
  ),
);

void main() {
  group('reading the stored pattern', () {
    test('turns the working-hours record into an entity', () async {
      final api = _FakeApi(
        workingHours: const WorkingHoursDto(
          start: '10:00',
          end: '14:00',
          slotInterval: 60,
          sessionDuration: 60,
          breakDuration: 0,
          daysOfWeek: ['Mon', 'Wed', 'Fri'],
        ),
      );
      final result = await TherapistAvailabilityRepositoryImpl(
        api,
      ).getWorkingHours();

      final hours = result.getOrElse((_) => throw StateError('failed'));
      expect(hours.days, {Weekday.monday, Weekday.wednesday, Weekday.friday});
      expect(hours.startLabel, '10:00');
      expect(hours.endLabel, '14:00');
      expect(hours.sessionMinutes, 60);
      expect(hours.slotTimes, ['10:00', '11:00', '12:00', '13:00']);
    });

    test('a failed read stays a failure — it does not become a default',
        () async {
      // The screen must never open showing an invented pattern as though it
      // were stored. That is the bug this feature replaces.
      final result = await TherapistAvailabilityRepositoryImpl(
        _FakeApi(error: _http(500)),
      ).getWorkingHours();

      expect(result.isLeft(), isTrue);
      result.match((f) => expect(f, isA<ServerFailure>()), (_) => fail('ok'));
    });
  });

  group('what the repository sends', () {
    const hours = WorkingHours(
      days: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      startMinutes: 10 * 60,
      endMinutes: 14 * 60,
      sessionMinutes: 60,
      breakMinutes: 15,
    );

    test('the whole pattern, as POST /availability/generate expects it',
        () async {
      final api = _FakeApi(updated: 12);
      await TherapistAvailabilityRepositoryImpl(
        api,
      ).saveWorkingHours(hours, from: DateTime(2026, 9, 14));

      final body = api.sentBody!;
      expect(body.daysOfWeek, ['Mon', 'Wed', 'Fri']);
      expect(body.startTime, '10:00');
      expect(body.endTime, '14:00');
      expect(body.sessionDuration, 60);
      // Echoed, not zeroed. Nothing on the screen edits the break, and
      // sending a hardcoded 0 would silently re-step the whole slot grid.
      expect(body.breakDuration, 15);
    });

    test('an explicit dateTo, covering the window the readers read', () async {
      // Omitting `dateTo` makes the server default to a year ahead — roughly
      // three thousand individually-written rows in one request.
      final api = _FakeApi();
      await TherapistAvailabilityRepositoryImpl(
        api,
      ).saveWorkingHours(hours, from: DateTime(2026, 9, 14, 16, 30));

      expect(api.sentBody!.dateFrom, '2026-09-14');
      expect(api.sentBody!.dateTo, '2026-09-28');
    });

    test('and a timeout long enough for the server to finish', () async {
      // Measured worst case against a local server: 13.7s for a seven-day,
      // nine-slot week. Dio's default receive timeout is 15s, so without this
      // a save that is working gets reported as a failure.
      final api = _FakeApi();
      await TherapistAvailabilityRepositoryImpl(
        api,
      ).saveWorkingHours(hours, from: DateTime(2026, 9, 14));

      expect(
        api.sentOptions!.receiveTimeout,
        TherapistAvailabilityRepositoryImpl.saveTimeout,
      );
      expect(
        api.sentOptions!.receiveTimeout!.inSeconds,
        greaterThan(30),
        reason: 'a save must not be called a timeout while it is still going',
      );
    });

    test('the server\'s own count comes back as the result', () async {
      final result = await TherapistAvailabilityRepositoryImpl(
        _FakeApi(updated: 12),
      ).saveWorkingHours(hours, from: DateTime(2026, 9, 14));

      expect(
        result.getOrElse((_) => throw StateError('failed')),
        const WorkingHoursSaved(
          openedSlots: 12,
          fromDate: '2026-09-14',
          toDate: '2026-09-28',
        ),
      );
    });

    test('a rejected save is a failure, not a zero', () async {
      final result = await TherapistAvailabilityRepositoryImpl(
        _FakeApi(error: _http(403)),
      ).saveWorkingHours(hours, from: DateTime(2026, 9, 14));

      expect(result.isLeft(), isTrue);
    });
  });

  group('SaveWorkingHoursUseCase refuses before the network', () {
    const good = WorkingHours(
      days: {Weekday.monday},
      startMinutes: 9 * 60,
      endMinutes: 17 * 60,
      sessionMinutes: 60,
    );

    Future<void> expectRefused(
      WorkingHours hours,
      WorkingHoursProblem problem,
    ) async {
      final api = _FakeApi();
      final result = await SaveWorkingHoursUseCase(
        TherapistAvailabilityRepositoryImpl(api),
      ).call(hours, from: DateTime(2026, 9, 14));

      expect(result.isLeft(), isTrue);
      result.match((failure) {
        expect(failure, isA<InvalidWorkingHoursFailure>());
        expect((failure as InvalidWorkingHoursFailure).problem, problem);
      }, (_) => fail('should not have been sent'));

      // The point of refusing locally: nothing reached the API, so nothing
      // was half-written and there is nothing to undo.
      expect(api.sentBody, isNull);
    }

    test('an empty week', () {
      return expectRefused(
        good.copyWith(days: const <Weekday>{}),
        WorkingHoursProblem.noDays,
      );
    });

    test('a day that ends before it starts', () {
      return expectRefused(
        good.copyWith(endMinutes: 8 * 60),
        WorkingHoursProblem.endNotAfterStart,
      );
    });

    test('a session that does not fit', () {
      return expectRefused(
        good.copyWith(endMinutes: 10 * 60, sessionMinutes: 90),
        WorkingHoursProblem.sessionLongerThanDay,
      );
    });

    test('but a sound pattern goes through', () async {
      final api = _FakeApi(updated: 8);
      final result = await SaveWorkingHoursUseCase(
        TherapistAvailabilityRepositoryImpl(api),
      ).call(good, from: DateTime(2026, 9, 14));

      expect(result.isRight(), isTrue);
      expect(api.sentBody, isNotNull);
    });
  });

  // ─── The round trip ──────────────────────────────────────────────────────

  /// `GET /availability/slots?from_date=2026-09-14&to_date=2026-09-20`,
  /// recorded from the running API **after** saving Mon/Wed/Fri 10:00–14:00
  /// at 60 minutes through `POST /availability/generate`.
  ///
  /// Only the fields the clients read are kept. The shape is the API's:
  /// `blocks` sits beside `slots` rather than folded into them.
  Map<String, dynamic> recordedSlotRange() {
    const pattern = {
      '2026-09-14': 'open', // Mon
      '2026-09-15': 'off', // Tue
      '2026-09-16': 'open', // Wed
      '2026-09-17': 'off', // Thu
      '2026-09-18': 'open', // Fri
      '2026-09-19': 'off', // Sat
      '2026-09-20': 'off', // Sun
    };
    return {
      'slots': [
        for (final entry in pattern.entries)
          for (final time in ['10:00', '11:00', '12:00', '13:00'])
            {
              'date': entry.key,
              'time': time,
              'status': entry.value,
              'sessionType': 'Morning',
              'fee': 0,
            },
      ],
      'blocks': <dynamic>[],
    };
  }

  group('round trip: what is written here is what the patient side reads', () {
    const saved = WorkingHours(
      days: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      startMinutes: 10 * 60,
      endMinutes: 14 * 60,
      sessionMinutes: 60,
    );

    test('the projection matches the grid the API actually returned', () {
      // Recorded against the running server, not imagined: saving this
      // pattern produced exactly this grid, including four `off` rows on each
      // non-working day. The `off` rows are the whole point — the slot grid
      // applies no day-of-week filter of its own, so a day with no row reads
      // `open` however `daysOfWeek` is set.
      final response = SlotRangeDto.fromJson(recordedSlotRange());

      final byDate = <String, Map<String, String>>{};
      for (final slot in response.slots) {
        byDate.putIfAbsent(slot.date, () => {})[slot.time] = slot.status;
      }

      for (final entry in byDate.entries) {
        final day = DateTime.parse(entry.key);
        expect(
          entry.value,
          saved.projectedDay(day),
          reason: 'the grid for ${entry.key} is not what saving would predict',
        );
      }
      expect(byDate.keys, hasLength(7));
    });

    test('a therapist who works Mon/Wed/Fri is not offered on Saturday', () {
      final response = SlotRangeDto.fromJson(recordedSlotRange());
      // The filter discovery applies: anything that is not `open` is not
      // availability.
      final open = response.slots.where((s) => s.isOpen).toList();

      expect(open, hasLength(12));
      expect(open.map((s) => s.date).toSet(), {
        '2026-09-14',
        '2026-09-16',
        '2026-09-18',
      });
      expect(
        open.every((s) => s.time.compareTo('10:00') >= 0),
        isTrue,
        reason: 'nothing before the start time the therapist published',
      );
      expect(
        open.every((s) => s.time.compareTo('14:00') < 0),
        isTrue,
        reason: 'nothing at or after the finishing time either',
      );
    });

    test('the hours narrow the day as well as the week', () {
      // Before the save the same therapist answered nine open slots on every
      // one of the seven days, 09:00 to 17:00. Both halves of the pattern had
      // to land for this to be twelve.
      final open = SlotRangeDto.fromJson(
        recordedSlotRange(),
      ).slots.where((s) => s.isOpen).toList();

      expect(open.length, saved.slotsPerWeek);
      expect(
        open.map((s) => s.time).toSet(),
        saved.slotTimes.toSet(),
      );
    });
  });
}
