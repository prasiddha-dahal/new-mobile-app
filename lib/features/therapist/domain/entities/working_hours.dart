import '../../../patient/domain/entities/availability.dart'
    show availabilityHorizonDays, formatSlotMinutes, parseSlotMinutes;

/// How far ahead saving working hours writes.
///
/// Deliberately [availabilityHorizonDays] — the same fortnight the patient
/// side reads. The reason is the shape of the API rather than a design
/// preference: `GET /availability/slots` synthesises its grid from the stored
/// working hours and *overlays* whatever `AvailabilitySlot` rows exist, so a
/// day with no row reads `open` no matter what `daysOfWeek` says. Days off
/// only become real once an `off` row has been written for them, and rows are
/// written one day at a time. Writing exactly the window patients can see is
/// therefore the smallest write that cannot leave a patient looking at a day
/// the therapist has marked closed.
///
/// Widening this without widening `slotWindowDays` would spend time writing
/// rows nobody reads; narrowing it would leave the tail of the patient's
/// calendar showing the old pattern.
const availabilityWriteHorizonDays = availabilityHorizonDays;

/// The span of dates one save rewrites: today, plus the rest of the horizon.
///
/// A value type rather than two loose `DateTime`s so the arithmetic — which
/// end is inclusive, how a horizon of 14 becomes a 13-day offset — is written
/// once and can be tested without a network.
class AvailabilityWindow {
  AvailabilityWindow.fromDate(
    DateTime start, {
    int horizonDays = availabilityWriteHorizonDays,
  }) : from = DateTime(start.year, start.month, start.day),
       to = DateTime(start.year, start.month, start.day + horizonDays);

  /// Midnight on the first day rewritten — today.
  final DateTime from;

  /// Midnight on the last day rewritten, **inclusive**.
  ///
  /// `from + horizonDays`, not `from + horizonDays - 1`, so that the window
  /// is byte-for-byte the range the readers ask for: both
  /// `availabilityHorizonProvider` (discovery) and `ownSlotsProvider` (the
  /// therapist's own calendar) send `to_date = today + 14`, which is fifteen
  /// dates. Writing one day fewer would leave the last column of the
  /// patient's calendar showing the pattern that was just replaced.
  final DateTime to;

  /// `YYYY-MM-DD`, the format every date parameter in this API expects. Same
  /// output as `formatDateKey` in the patient providers; spelled again here so
  /// that the data layer does not have to reach up into presentation for it.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get fromDate => dateKey(from);
  String get toDate => dateKey(to);

  /// Every date in the window, both ends included.
  List<DateTime> get dates {
    final out = <DateTime>[];
    for (
      var day = from;
      !day.isAfter(to);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      out.add(day);
    }
    return List.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) =>
      other is AvailabilityWindow && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'AvailabilityWindow($fromDate…$toDate)';
}

/// A day of the week, in the spelling `daysOfWeek` uses on the wire.
///
/// Sunday first, matching the API's `_DOW_MAP` (`{"Sun": 0, "Mon": 1, …}`)
/// and the Sunday-indexed `days` list `POST /availability/recurring` takes.
/// The labels are not here — they come from the ARB files at render time.
enum Weekday {
  sunday('Sun'),
  monday('Mon'),
  tuesday('Tue'),
  wednesday('Wed'),
  thursday('Thu'),
  friday('Fri'),
  saturday('Sat');

  const Weekday(this.wireValue);

  /// What `daysOfWeek` carries: `Sun`, `Mon`, … Sent verbatim.
  final String wireValue;

  /// Sunday = 0, matching the server's `isoweekday() % 7`.
  int get sundayIndex => index;

  static Weekday? fromWire(String value) {
    for (final day in Weekday.values) {
      if (day.wireValue == value) return day;
    }
    return null;
  }

  /// The weekday [date] falls on.
  ///
  /// `DateTime.weekday` is 1 (Monday) to 7 (Sunday); `% 7` maps Sunday to 0,
  /// which is the same arithmetic `get_slots_for_range` does server-side.
  static Weekday ofDate(DateTime date) => Weekday.values[date.weekday % 7];
}

/// Why a set of working hours cannot be saved.
///
/// Each one is a case where the API would accept the request and quietly do
/// something other than what was asked, so the screen refuses instead.
enum WorkingHoursProblem {
  /// No day selected. The API would take it and write `off` across the whole
  /// horizon — a total blackout, which is a real thing to want but not one
  /// anybody means to express by clearing every chip. Leave is its own flow.
  noDays,

  /// The day ends before it starts, or at the same minute. The server's
  /// `range(start, end, step)` is empty for this, so it would write nothing
  /// at all on the working days and report `updated: 0`.
  endNotAfterStart,

  /// The session is longer than the working day. The server emits one slot
  /// anyway — `range(540, 600, 90)` is `[540]` — and that slot would run past
  /// the end time the therapist just published.
  sessionLongerThanDay,
}

/// The therapist's weekly pattern: which days they work, between what hours,
/// and how long one session is.
///
/// **All times are wall-clock minutes since midnight, with no offset**, which
/// is how the rest of the app treats them (see `parseSlotMinutes`). Nepal has
/// one timezone and no DST; the strings the API stores mean the same thing to
/// the therapist who published them and the patient who reads them.
class WorkingHours {
  const WorkingHours({
    required this.days,
    required this.startMinutes,
    required this.endMinutes,
    required this.sessionMinutes,
    this.breakMinutes = 0,
  });

  /// What the API hands back for a therapist who has never set anything —
  /// `DEFAULT_WORKING_HOURS` in `app/services/availability.py`.
  ///
  /// Used only when a field is missing from the response, never as a stand-in
  /// for a failed read: showing an invented pattern as though it were stored
  /// is the bug this screen exists to fix.
  static const fallback = WorkingHours(
    days: {
      Weekday.monday,
      Weekday.tuesday,
      Weekday.wednesday,
      Weekday.thursday,
      Weekday.friday,
    },
    startMinutes: 9 * 60,
    endMinutes: 18 * 60,
    sessionMinutes: 60,
  );

  /// The days worked. Unordered; [sortedDays] is what the wire and the UI use.
  final Set<Weekday> days;

  final int startMinutes;
  final int endMinutes;

  /// One appointment's length. The API calls it `sessionDuration`.
  final int sessionMinutes;

  /// Gap between appointments. Not editable here — there is nowhere in the
  /// designs to set it — but it is read back and sent again unchanged so that
  /// saving hours never silently resets a value somebody set elsewhere.
  final int breakMinutes;

  List<Weekday> get sortedDays =>
      Weekday.values.where(days.contains).toList(growable: false);

  List<String> get dayWireValues =>
      sortedDays.map((d) => d.wireValue).toList(growable: false);

  String get startLabel => formatSlotMinutes(startMinutes);
  String get endLabel => formatSlotMinutes(endMinutes);

  /// The step between slot starts, which is what the server uses:
  /// `sessionDuration + breakDuration`.
  int get stepMinutes => sessionMinutes + breakMinutes;

  /// The first problem that stops this being saved, or null when it is fine.
  WorkingHoursProblem? get problem {
    if (days.isEmpty) return WorkingHoursProblem.noDays;
    if (endMinutes <= startMinutes) return WorkingHoursProblem.endNotAfterStart;
    if (sessionMinutes > endMinutes - startMinutes) {
      return WorkingHoursProblem.sessionLongerThanDay;
    }
    return null;
  }

  bool get isSavable => problem == null;

  /// The slot start times one working day will carry, as `HH:MM`.
  ///
  /// A deliberate mirror of the server's `_generate_time_slots` —
  /// `range(start, end, sessionDuration + breakDuration)` — so the screen can
  /// say how many appointments a day holds before the save happens, and so a
  /// test can check the prediction against what the API actually returns.
  List<String> get slotTimes {
    if (!isSavable) return const [];
    final out = <String>[];
    for (var m = startMinutes; m < endMinutes; m += stepMinutes) {
      out.add(formatSlotMinutes(m));
    }
    return List.unmodifiable(out);
  }

  int get slotsPerDay => slotTimes.length;

  /// Every slot published in a week, which is the number worth showing: one
  /// day's count says nothing about a therapist who works three days.
  int get slotsPerWeek => slotsPerDay * days.length;

  /// What `GET /availability/slots` will report for [day] once these hours
  /// have been saved, as `HH:MM` → `open` | `off`.
  ///
  /// This is the round trip written down. The grid is synthesised from the
  /// stored hours for *every* date in the range — the server applies no
  /// day-of-week filter of its own — so a non-working day is not an absence
  /// of slots but a full day of `off` rows, which is exactly what
  /// `POST /availability/generate` writes.
  ///
  /// Booked slots are not modelled: the server never overwrites one, so a
  /// slot already sold stays `booked` whatever is projected here.
  Map<String, String> projectedDay(DateTime day) {
    final working = days.contains(Weekday.ofDate(day));
    return {for (final time in slotTimes) time: working ? 'open' : 'off'};
  }

  WorkingHours copyWith({
    Set<Weekday>? days,
    int? startMinutes,
    int? endMinutes,
    int? sessionMinutes,
    int? breakMinutes,
  }) => WorkingHours(
    days: days ?? this.days,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
  );

  /// Turns a day on or off.
  WorkingHours withDay(Weekday day, bool on) {
    final next = {...days};
    on ? next.add(day) : next.remove(day);
    return copyWith(days: next);
  }

  /// Parses the `HH:MM` pair the API stores, falling back per-field so one
  /// malformed value does not discard the rest of the record.
  static WorkingHours fromWire({
    required String start,
    required String end,
    required int sessionMinutes,
    required int breakMinutes,
    required List<String> daysOfWeek,
  }) {
    final parsedDays = daysOfWeek
        .map(Weekday.fromWire)
        .whereType<Weekday>()
        .toSet();
    return WorkingHours(
      days: parsedDays.isEmpty ? fallback.days : parsedDays,
      startMinutes: parseSlotMinutes(start) ?? fallback.startMinutes,
      endMinutes: parseSlotMinutes(end) ?? fallback.endMinutes,
      sessionMinutes: sessionMinutes > 0
          ? sessionMinutes
          : fallback.sessionMinutes,
      breakMinutes: breakMinutes >= 0 ? breakMinutes : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkingHours &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes &&
      other.sessionMinutes == sessionMinutes &&
      other.breakMinutes == breakMinutes &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(
    startMinutes,
    endMinutes,
    sessionMinutes,
    breakMinutes,
    Object.hashAllUnordered(days),
  );

  @override
  String toString() =>
      'WorkingHours(${dayWireValues.join(",")} $startLabel–$endLabel '
      '${sessionMinutes}m)';
}

/// What came back from a successful save.
///
/// [openedSlots] is the server's own count of slots it opened, not a number
/// this app worked out — the point of showing it is that it is evidence the
/// write landed. It can legitimately be lower than [WorkingHours.slotsPerWeek]
/// implies: slots already in the past are skipped, and slots already booked
/// are left alone.
class WorkingHoursSaved {
  const WorkingHoursSaved({
    required this.openedSlots,
    required this.fromDate,
    required this.toDate,
  });

  final int openedSlots;

  /// `YYYY-MM-DD`, inclusive at both ends — the window that was rewritten.
  final String fromDate;
  final String toDate;

  @override
  bool operator ==(Object other) =>
      other is WorkingHoursSaved &&
      other.openedSlots == openedSlots &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(openedSlots, fromDate, toDate);
}
