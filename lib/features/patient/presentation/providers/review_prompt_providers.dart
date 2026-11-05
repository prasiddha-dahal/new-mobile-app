import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/preferences_storage.dart';
import '../../domain/entities/session.dart';
import 'patient_providers.dart';

/// How long after a visit the Home banner keeps asking. Past this the moment
/// has gone, and the Sessions tab is still there for a patient who wants to.
const reviewPromptWindow = Duration(days: 14);

/// The most recent completed session worth asking about, or null.
///
/// Worth asking about means: completed within [reviewPromptWindow], the server
/// still accepts a review for it ([reviewable]), and the patient has not said
/// "not now" to it ([dismissed]). One session at a time -- a stack of banners
/// is nagging, and rating the newest leaves the older ones on the Sessions tab.
Session? pickReviewPrompt(
  List<Session> sessions, {
  required Set<String> reviewable,
  required Set<String> dismissed,
  required DateTime now,
}) {
  final cutoff = now.subtract(reviewPromptWindow);
  Session? best;
  for (final s in sessions) {
    if (s.status != SessionStatus.completed) continue;
    if (!reviewable.contains(s.id) || dismissed.contains(s.id)) continue;
    if (s.date.isBefore(cutoff)) continue;
    if (best == null || s.date.isAfter(best.date)) best = s;
  }
  return best;
}

/// Sessions whose prompt the patient dismissed, persisted across launches.
///
/// Starts empty and fills from storage a moment later, so the banner can show
/// for one frame for a session that was dismissed last launch. The prompt is
/// gated on [loaded] to avoid exactly that flicker.
class DismissedReviewPrompts extends StateNotifier<Set<String>> {
  DismissedReviewPrompts(this._storage) : super(const {}) {
    _load();
  }

  static const _cap = 50;

  final PreferencesStorage _storage;
  bool loaded = false;

  Future<void> _load() async {
    final raw = await _storage.readString(PreferenceKeys.dismissedReviewPrompts);
    if (!mounted) return;
    loaded = true;
    state = {
      ...state,
      ...?raw?.split(',').where((id) => id.isNotEmpty),
    };
  }

  Future<void> dismiss(String sessionId) async {
    // Newest last; the cap drops the oldest so the key cannot grow forever.
    final next = [...state.where((id) => id != sessionId), sessionId];
    final kept = next.length > _cap ? next.sublist(next.length - _cap) : next;
    state = kept.toSet();
    await _storage.writeString(
      PreferenceKeys.dismissedReviewPrompts,
      kept.join(','),
    );
  }
}

final dismissedReviewPromptsProvider =
    StateNotifierProvider<DismissedReviewPrompts, Set<String>>(
      (ref) => DismissedReviewPrompts(ref.watch(preferencesStorageProvider)),
    );

/// The session the Home banner is asking about, or null for no banner.
final reviewPromptProvider = Provider<Session?>((ref) {
  final sessions = ref.watch(patientSessionsProvider).valueOrNull;
  final reviewable = ref.watch(reviewableSessionIdsProvider).valueOrNull;
  final dismissed = ref.watch(dismissedReviewPromptsProvider);
  final loaded = ref.watch(dismissedReviewPromptsProvider.notifier).loaded;
  if (sessions == null || reviewable == null || !loaded) return null;
  return pickReviewPrompt(
    sessions,
    reviewable: reviewable,
    dismissed: dismissed,
    now: DateTime.now(),
  );
});
