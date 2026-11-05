import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../domain/entities/session.dart';

/// What a session's lifecycle state is called on screen.
///
/// This lives in the presentation layer, not on [SessionStatus] itself,
/// because the domain layer is pure Dart and [AppLocalizations] is not — a
/// `labelIn` method on the enum would drag Flutter into `domain/entities/`
/// and break the rule the rest of the architecture keeps.
///
/// [SessionStatus.label] stays as it was: the English default, used where
/// there is no reader to speak to — a log line, a test, a debug string.
/// Anything a patient or a therapist reads goes through here.
String sessionStatusLabel(SessionStatus status, AppLocalizations l10n) =>
    switch (status) {
      SessionStatus.scheduled => l10n.sessionStatusConfirmed,
      SessionStatus.inProgress => l10n.sessionStatusInProgress,
      SessionStatus.completed => l10n.sessionStatusDone,
      SessionStatus.cancelled => l10n.sessionStatusCancelled,
      SessionStatus.rescheduleRequested =>
        l10n.sessionStatusRescheduleRequested,
      SessionStatus.declineRequested => l10n.sessionStatusDeclineRequested,
      // Not "confirmed" and not "cancelled": the slot is reserved while a
      // gateway payment settles, and the server releases it if it never does.
      SessionStatus.pendingHold => l10n.sessionStatusAwaitingPayment,
      SessionStatus.unknown => l10n.sessionStatusUnknown,
    };

/// Still marked confirmed (or in progress) after its day has passed: nobody
/// closed it. Shown as "Awaiting update", not "Confirmed" -- a past visit
/// labelled confirmed reads as a booking still to come (QA DATA-01).
bool isAwaitingUpdate(Session s) =>
    s.hasElapsed &&
    (s.status == SessionStatus.scheduled ||
        s.status == SessionStatus.inProgress);

/// The label for this particular session: its status, except a past visit
/// nobody closed, which says so.
String sessionLabel(Session s, AppLocalizations l10n) => isAwaitingUpdate(s)
    ? l10n.sessionStatusAwaitingUpdate
    : sessionStatusLabel(s.status, l10n);

/// Badge tone for a status, matching the prototype's colour language.
///
/// Promoted here from `patient_sessions_screen.dart`, which wrote it first
/// and kept it private. The therapist dashboard had its own one-liner —
/// `status == completed ? neutral : green` — which painted a PENDING visit
/// the same green as a CONFIRMED one, so the therapist's own list of today's
/// work could not tell an agreed visit from one still waiting on them. Spec
/// §31 draws that as a warning badge, and this function already did.
TagTone sessionStatusTone(Session s) {
  if (s.isCancelled) return TagTone.red;
  if (isAwaitingUpdate(s)) return TagTone.amber;
  // A hold is not a booking. Green here is the same mistake the app made by
  // showing a confirmation screen for one.
  if (s.status.isAwaitingPayment) return TagTone.amber;
  if (s.status == SessionStatus.completed) return TagTone.neutral;
  if (s.status == SessionStatus.rescheduleRequested ||
      s.status == SessionStatus.declineRequested ||
      s.status == SessionStatus.inProgress) {
    return TagTone.amber;
  }
  return TagTone.green;
}
