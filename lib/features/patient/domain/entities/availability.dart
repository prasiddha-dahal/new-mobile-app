import '../../../../core/error/failures.dart';
import 'therapist.dart';

/// How many days ahead discovery looks when it asks "when is this therapist
/// free?".
///
/// Deliberately the same number the profile screen's slot picker uses
/// (`slotWindowDays`), because the two share a cache entry: a card that has
/// already shown "Free Thu 2:00 PM" has, in doing so, fetched every slot the
/// availability filter can ask about. Widening one without the other would
/// turn every date change into a fresh round of requests.
const availabilityHorizonDays = 14;

// ─── Wall-clock time ────────────────────────────────────────────────────────

/// Minutes since midnight for an `HH:MM` slot time, or null if it is not one.
///
/// **These are wall-clock strings, not instants.** The API stores and returns
/// a slot as a bare `YYYY-MM-DD` plus `HH:MM` with no offset, and every other
/// screen in the app — the profile slot grid, the booking summary, the
/// reschedule sheet — renders and sends them exactly as they arrive. Nepal
/// has one timezone and no DST, so "09:00" means 09:00 to the therapist who
/// published it and to the patient reading it. Converting here would be
/// inventing a convention the rest of the app does not share, and would make
/// this screen disagree with the booking screen it hands off to.
int? parseSlotMinutes(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

/// `HH:MM` for minutes since midnight.
String formatSlotMinutes(int minutes) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  return '${(clamped ~/ 60).toString().padLeft(2, '0')}:'
      '${(clamped % 60).toString().padLeft(2, '0')}';
}

/// A slot's start as a local `DateTime`, or null if either half is malformed.
///
/// Local, for the reason in [parseSlotMinutes]: the strings are wall clock and
/// the reader's clock is the same clock.
DateTime? slotStartsAt(TherapistSlot slot) {
  final day = DateTime.tryParse(slot.date);
  final minutes = parseSlotMinutes(slot.time);
  if (day == null || minutes == null) return null;
  return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
}

/// A span of the clock on one day, as the patient describes it: "some time
/// between 2 and 4".
///
/// **Both ends are inclusive**, and the comparison is against the slot's
/// *start* time. Someone who asks for 14:00–16:00 is offered the 14:00 slot
/// and the 16:00 slot; a therapist free only at 16:00 is a real answer to
/// "can anyone see me between 2 and 4", and dropping them because the session
/// would run past 4 would be the app second-guessing the question.
///
/// The consequence is that the preset windows overlap by one slot at noon and
/// at 5pm, which is the right way round: a 12:00 slot is a plausible answer
/// to both "morning" and "afternoon", and a patient who picked one and cannot
/// see it listed has been failed worse than one who sees it twice.
class SlotWindow {
  const SlotWindow({required this.fromMinutes, required this.toMinutes});

  /// Every slot of the day. The filter still narrows by date.
  static const anyTime = SlotWindow(fromMinutes: 0, toMinutes: 24 * 60 - 1);
  static const morning = SlotWindow(fromMinutes: 9 * 60, toMinutes: 12 * 60);
  static const afternoon = SlotWindow(fromMinutes: 12 * 60, toMinutes: 17 * 60);
  static const evening = SlotWindow(fromMinutes: 17 * 60, toMinutes: 20 * 60);

  final int fromMinutes;
  final int toMinutes;

  bool get isAnyTime => this == anyTime;

  /// Whether a slot beginning [minutes] after midnight falls in this window.
  bool contains(int minutes) =>
      minutes >= fromMinutes && minutes <= toMinutes;

  bool containsTime(String time) {
    final minutes = parseSlotMinutes(time);
    return minutes != null && contains(minutes);
  }

  String get fromLabel => formatSlotMinutes(fromMinutes);
  String get toLabel => formatSlotMinutes(toMinutes);

  @override
  bool operator ==(Object other) =>
      other is SlotWindow &&
      other.fromMinutes == fromMinutes &&
      other.toMinutes == toMinutes;

  @override
  int get hashCode => Object.hash(fromMinutes, toMinutes);

  @override
  String toString() => 'SlotWindow($fromLabel–$toLabel)';
}

/// The availability filter the patient has set, or null for "any time".
class AvailabilityFilter {
  const AvailabilityFilter({required this.date, required this.window});

  /// `YYYY-MM-DD`, the one day being asked about.
  final String date;
  final SlotWindow window;

  /// Whether [openSlots] contains anything this filter would accept.
  ///
  /// Takes *open* slots only — a booked or blocked slot is not availability,
  /// and the caller has already dropped them.
  bool isSatisfiedBy(Iterable<TherapistSlot> openSlots) =>
      openSlots.any((s) => s.date == date && window.containsTime(s.time));

  @override
  bool operator ==(Object other) =>
      other is AvailabilityFilter &&
      other.date == date &&
      other.window == window;

  @override
  int get hashCode => Object.hash(date, window);
}

// ─── What we know about one therapist ───────────────────────────────────────

/// The answer to "when is this therapist next free?", including the two
/// answers that are not a time.
///
/// The distinction that matters is between [SlotLookupLoaded] with no slots —
/// "asked, and they have nothing open" — and [SlotLookupUnknown] /
/// [SlotLookupFailed] — "we have not been told". Collapsing those would make
/// a therapist whose calendar failed to load read as fully booked, which is
/// both untrue and unfair to them.
sealed class SlotLookup {
  const SlotLookup();

  /// Slots we know to be open, or empty when we do not know.
  List<TherapistSlot> get openSlots => const [];

  /// True only when the answer is in: this therapist has nothing open in the
  /// horizon. Never true for an answer we are still waiting on.
  bool get isKnownEmpty => false;
}

/// Nobody has asked yet — this card has not been on screen.
class SlotLookupUnknown extends SlotLookup {
  const SlotLookupUnknown();
}

/// Asked; waiting.
class SlotLookupPending extends SlotLookup {
  const SlotLookupPending();
}

/// Asked and answered. [openSlots] may be empty, which is a real answer.
class SlotLookupLoaded extends SlotLookup {
  const SlotLookupLoaded(this.openSlots);

  @override
  final List<TherapistSlot> openSlots;

  @override
  bool get isKnownEmpty => openSlots.isEmpty;
}

/// Asked, and the request failed. Still not the same as "unavailable".
class SlotLookupFailed extends SlotLookup {
  const SlotLookupFailed(this.failure);
  final Failure failure;
}

/// A therapist list split by what the availability filter can say about it.
///
/// Three groups, not two, because "we do not know yet" is neither a match nor
/// a miss. Reporting the third separately is what lets the screen say
/// "checking 4 more" instead of quietly showing a short list as if it were
/// the whole answer.
class AvailabilityPartition {
  const AvailabilityPartition({
    required this.matching,
    required this.pending,
    required this.unchecked,
  });

  /// Therapists known to have a slot the filter accepts, in the order they
  /// arrived.
  final List<Therapist> matching;

  /// Still being asked about.
  final List<Therapist> pending;

  /// Asked, and the answer never came. Not the same as unavailable, and the
  /// screen must not present them as though it were.
  final List<Therapist> unchecked;

  bool get isSettled => pending.isEmpty;

  /// True when every therapist was checked and none is free then — a real,
  /// final answer rather than a failure.
  bool get isDefinitelyEmpty =>
      matching.isEmpty && pending.isEmpty && unchecked.isEmpty;
}

/// Splits [therapists] by whether [filter] accepts them, using [lookups] for
/// what is known.
///
/// An information-only listing is dropped without being looked up at all:
/// they publish no slots and are visited at their clinic rather than booked
/// through the app, so "free at 2pm" is not a question they have an answer
/// to. Leaving them in would strand them in [AvailabilityPartition.pending]
/// for ever and spend a request finding that out.
AvailabilityPartition partitionByAvailability({
  required List<Therapist> therapists,
  required Map<String, SlotLookup> lookups,
  required AvailabilityFilter filter,
}) {
  final matching = <Therapist>[];
  final pending = <Therapist>[];
  final unchecked = <Therapist>[];

  for (final therapist in therapists) {
    if (!therapist.isBookable) continue;
    final lookup = lookups[therapist.id] ?? const SlotLookupUnknown();
    switch (lookup) {
      case SlotLookupLoaded(:final openSlots):
        if (filter.isSatisfiedBy(openSlots)) matching.add(therapist);
      case SlotLookupFailed():
        unchecked.add(therapist);
      case SlotLookupUnknown():
      case SlotLookupPending():
        pending.add(therapist);
    }
  }

  return AvailabilityPartition(
    matching: matching,
    pending: pending,
    unchecked: unchecked,
  );
}

/// The earliest open slot at or after [now], or null when there is none.
///
/// Slots already gone by are dropped: a card reading "Free today 9:00 AM" at
/// four in the afternoon is worse than no card at all, and the API would
/// refuse the booking anyway.
TherapistSlot? nextFreeSlot(Iterable<TherapistSlot> openSlots, DateTime now) {
  TherapistSlot? best;
  DateTime? bestAt;
  for (final slot in openSlots) {
    final at = slotStartsAt(slot);
    if (at == null || at.isBefore(now)) continue;
    if (bestAt == null || at.isBefore(bestAt)) {
      best = slot;
      bestAt = at;
    }
  }
  return best;
}
