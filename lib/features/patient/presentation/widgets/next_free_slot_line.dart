import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/availability.dart';
import '../providers/availability_providers.dart';

/// What a therapist card says about when they are next free.
///
/// Four different sentences, and the difference between them is the whole
/// point of the feature:
///
/// | state | reads |
/// |---|---|
/// | answered, has a slot | `Free tomorrow · 9:00 AM` |
/// | answered, nothing open | `No free slots in the next 14 days` |
/// | still asking | `Checking availability…` |
/// | could not ask | `Tap to see availability` |
///
/// The last two are **not** "unavailable". A therapist whose calendar timed
/// out has not told us they are busy, and a card that said so would cost them
/// work on the strength of a dropped request.
///
/// [now] is injectable so the day boundaries can be tested without waiting
/// for midnight.
String nextFreeSlotLabel(
  SlotLookup lookup,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  switch (lookup) {
    case SlotLookupUnknown():
    case SlotLookupPending():
      return l10n.findCheckingAvailability;
    case SlotLookupFailed():
      return l10n.findAvailabilityUnknown;
    case SlotLookupLoaded(:final openSlots):
      final current = now ?? DateTime.now();
      final slot = nextFreeSlot(openSlots, current);
      if (slot == null) return l10n.findNoFreeSlots(availabilityHorizonDays);

      final at = slotStartsAt(slot)!;
      final time = formatSlotTime(slot.time, l10n);
      final today = DateTime(current.year, current.month, current.day);
      final day = DateTime(at.year, at.month, at.day);
      final days = day.difference(today).inDays;

      return switch (days) {
        0 => l10n.findFreeToday(time),
        1 => l10n.findFreeTomorrow(time),
        // Inside the coming week a weekday name is the shortest thing that
        // is still unambiguous; past it, "Thu" could be either of two
        // Thursdays, so the date is spelled out.
        >= 2 && < 7 => l10n.findFreeOnDay(formatWeekday(at, l10n), time),
        _ => l10n.findFreeOnDay(formatDayAndMonth(at, l10n), time),
      };
  }
}

/// The colour the line is drawn in.
///
/// A known free slot is the good news the feature exists to deliver, so it is
/// the only one that gets the brand green. The two unknowns are muted rather
/// than red: nothing has gone wrong for the reader.
Color _tintFor(SlotLookup lookup, DateTime now) => switch (lookup) {
  SlotLookupLoaded(:final openSlots) =>
    nextFreeSlot(openSlots, now) == null ? AppColors.inkMute : AppColors.pine,
  _ => AppColors.inkMute,
};

IconData _iconFor(SlotLookup lookup, DateTime now) => switch (lookup) {
  SlotLookupLoaded(:final openSlots) => nextFreeSlot(openSlots, now) == null
      ? Icons.event_busy_outlined
      : Icons.schedule_rounded,
  SlotLookupFailed() => Icons.help_outline_rounded,
  _ => Icons.schedule_rounded,
};

/// The next-free-slot line on a therapist card.
///
/// Asks about its own therapist as it is built. `ListView.builder` only builds
/// what is on screen (plus its cache extent), so this is a request for the
/// visible window — a list of a hundred therapists costs a handful of
/// requests, not a hundred. The notifier drops ids it already knows and
/// coalesces everything queued in one frame into a single batched call, so a
/// rebuild is free and a scroll is one request per newly-revealed card.
class NextFreeSlotLine extends ConsumerWidget {
  const NextFreeSlotLine({super.key, required this.therapistId, this.now});

  final String therapistId;

  /// Fixed clock, for tests and goldens.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(therapistAvailabilityProvider);
    final lookup = lookups[therapistId] ?? const SlotLookupUnknown();

    // Safe during build: the notifier queues and drains in a microtask rather
    // than writing state here.
    if (lookup is SlotLookupUnknown) {
      ref.read(therapistAvailabilityProvider.notifier).request([therapistId]);
    }

    final current = now ?? DateTime.now();
    final label = nextFreeSlotLabel(lookup, context.l10n, now: current);
    final tint = _tintFor(lookup, current);

    return Row(
      children: [
        Icon(_iconFor(lookup, current), size: 14, color: tint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ),
      ],
    );
  }
}
