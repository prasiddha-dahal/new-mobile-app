import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/availability_repository_impl.dart';
import '../../domain/entities/availability.dart';
import '../../domain/repositories/availability_repository.dart';
import '../../domain/usecases/availability_usecases.dart';
import 'patient_providers.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepositoryImpl(ref.watch(patientApiProvider));
});

final getTherapistAvailabilityUseCaseProvider =
    Provider<GetTherapistAvailabilityUseCase>(
      (ref) =>
          GetTherapistAvailabilityUseCase(ref.watch(availabilityRepositoryProvider)),
    );

final forgetTherapistAvailabilityUseCaseProvider =
    Provider<ForgetTherapistAvailabilityUseCase>(
      (ref) => ForgetTherapistAvailabilityUseCase(
        ref.watch(availabilityRepositoryProvider),
      ),
    );

/// The one date range discovery ever asks about.
///
/// Held in a provider rather than recomputed at each call site so that every
/// request in a screen session carries **identical** `from`/`to` strings —
/// they are part of the repository's cache key, and a range that drifted by a
/// second would miss the cache every time and reintroduce the fan-out this
/// whole layer exists to avoid.
class AvailabilityHorizon {
  const AvailabilityHorizon({required this.fromDate, required this.toDate});

  /// `YYYY-MM-DD`, today.
  final String fromDate;

  /// `YYYY-MM-DD`, [availabilityHorizonDays] later.
  final String toDate;
}

final availabilityHorizonProvider = Provider<AvailabilityHorizon>((ref) {
  final now = DateTime.now();
  return AvailabilityHorizon(
    fromDate: formatDateKey(now),
    toDate: formatDateKey(
      now.add(const Duration(days: availabilityHorizonDays)),
    ),
  );
});

/// The availability filter the patient has set, or null for "any time".
final availabilityFilterProvider = StateProvider<AvailabilityFilter?>(
  (_) => null,
);

/// What is known about each therapist's open slots, keyed by therapist id.
///
/// The single place that decides *when* a slot request goes out. Two callers
/// feed it and they have different appetites:
///
/// * **A therapist card** asks about itself as it is built. `ListView.builder`
///   only builds what is on screen (plus its cache extent), so this is a
///   request for the visible window and nothing more — scrolling past twenty
///   therapists costs twenty requests spread over the scroll, not twenty on
///   first paint.
/// * **The availability filter** asks about every candidate at once, because
///   it cannot decide who to hide without knowing. That is the expensive
///   case, and it is deliberately behind an explicit user action.
///
/// Both go through [request], which does three things worth naming:
///
/// * **Ids already known or in flight are dropped.** A rebuilt card is free.
/// * **Requests made in the same frame are coalesced** into one call on
///   [AvailabilityRepository], which is the batch-shaped seam. Five cards
///   built in one frame are one call, not five.
/// * **State is never written during a build.** The queue is drained in a
///   microtask, which runs after the frame that filled it.
final therapistAvailabilityProvider =
    NotifierProvider<TherapistAvailabilityNotifier, Map<String, SlotLookup>>(
      TherapistAvailabilityNotifier.new,
    );

class TherapistAvailabilityNotifier extends Notifier<Map<String, SlotLookup>> {
  final _queue = <String>{};
  bool _drainScheduled = false;
  bool _disposed = false;

  /// Bumped whenever everything known is thrown away. A batch already in
  /// flight when that happens lands on a stale generation and is dropped,
  /// rather than merging yesterday's answers back into a refreshed state.
  int _generation = 0;

  @override
  Map<String, SlotLookup> build() {
    _queue.clear();
    _drainScheduled = false;
    _generation++;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const {};
  }

  /// What is known about [therapistId] right now.
  SlotLookup lookup(String therapistId) =>
      state[therapistId] ?? const SlotLookupUnknown();

  /// Asks about any of [therapistIds] we have no answer for.
  ///
  /// Safe to call from a widget `build`: nothing is written synchronously.
  void request(Iterable<String> therapistIds) {
    var added = false;
    for (final id in therapistIds) {
      if (id.isEmpty) continue;
      final known = state[id];
      // Unknown only. Pending is already coming, Loaded is answered, and a
      // Failed one stays failed until the reader asks again through [retry] —
      // otherwise a card that keeps rebuilding would hammer a dead endpoint.
      if (known != null && known is! SlotLookupUnknown) continue;
      if (_queue.add(id)) added = true;
    }
    if (added) _scheduleDrain();
  }

  /// Asks again about ids that failed, clearing the failure first.
  void retry(Iterable<String> therapistIds) {
    final ids = therapistIds.toSet();
    if (ids.isEmpty) return;
    ref.read(forgetTherapistAvailabilityUseCaseProvider).call(ids);
    final next = Map<String, SlotLookup>.from(state)
      ..removeWhere((id, lookup) => ids.contains(id) && lookup is SlotLookupFailed);
    state = next;
    request(ids);
  }

  /// Drops everything, so a pull-to-refresh really refetches.
  void refreshAll() {
    ref.read(forgetTherapistAvailabilityUseCaseProvider).call();
    _queue.clear();
    _generation++;
    state = const {};
  }

  void _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    // A microtask, not a post-frame callback: it runs after the synchronous
    // build pass that queued these ids, which is all that is needed to keep
    // the state write out of the build phase, and it does not depend on a
    // frame being scheduled at all.
    scheduleMicrotask(_drain);
  }

  Future<void> _drain() async {
    _drainScheduled = false;
    final batch = _queue.toList();
    _queue.clear();
    if (batch.isEmpty || _disposed) return;

    state = {
      ...state,
      for (final id in batch) id: const SlotLookupPending(),
    };

    final generation = _generation;
    final horizon = ref.read(availabilityHorizonProvider);
    final answers = await ref
        .read(getTherapistAvailabilityUseCaseProvider)
        .call(
          therapistIds: batch,
          fromDate: horizon.fromDate,
          toDate: horizon.toDate,
        );

    // The screen may have been left, or refreshed out from under this batch,
    // while it was in the air.
    if (_disposed || generation != _generation) return;

    state = {
      ...state,
      for (final entry in answers.entries)
        entry.key: entry.value.fold(
          SlotLookupFailed.new,
          SlotLookupLoaded.new,
        ),
    };

    // Anything queued while that batch was in flight — a scroll during the
    // request — goes out as the next one rather than waiting for another
    // build to notice it.
    if (_queue.isNotEmpty) _scheduleDrain();
  }
}
