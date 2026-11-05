/// How one row of the feed is drawn and where it goes.
///
/// Everything here is derived from the three fields the API already sends —
/// `type`, `readAt` and `createdAt` — plus who is signed in. No server field
/// carries an icon, a pill or a route, and none should: the client decides
/// how its own screens look, and a new `type` must not need a new column.
///
/// The registry this mirrors is `docs/notification_types.md` on the API
/// (branch `feat/notification-events`), which is the contract. Its 22 keys
/// are listed in [notificationTypes] below, and a test asserts that every one
/// of them has a case here rather than falling into the default.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The pill
// ─────────────────────────────────────────────────────────────────────────────

/// The small uppercase badge at the right of every row.
///
/// **One rule, over all 22 types: the pill answers "is this waiting on me?"**
///
/// * [actionNeeded] (`NEW`) — *your turn.* If the reader does nothing,
///   something does not happen: a request wants an answer, a session wants
///   rating, a new booking wants looking at, a report wants opening.
/// * [done] (`DONE`) — *settled.* The thing the row names has reached its
///   final state and nothing more is asked. Settled is not the same as happy:
///   a refund **denied** and a leave request **rejected** are as finished as
///   their approvals, so they read `DONE` too. The icon tint carries whether
///   it went the reader's way; the pill carries only whether it is over.
/// * [info] (`INFO`) — *neither.* A step along the way or a change of fact:
///   worth knowing, no decision landed, nothing asked.
///
/// An unrecognised `type` is [info], because "we cannot tell" and "nothing is
/// asked of you" are the same instruction to the reader, and it is the pill
/// that is wrong least often when the app is older than the API.
///
/// This departs from one row of the supplied mock, which badges "Rate your
/// last session" `INFO`. A rating prompt is the plainest *your turn* row in
/// the whole registry; the mock's five sample rows use the badge decoratively
/// (the same `DONE` appears in two different colours), and a pill whose
/// meaning cannot be stated in one sentence is worth less than none.
enum NotificationPill {
  done('DONE'),
  actionNeeded('NEW'),
  info('INFO');

  const NotificationPill(this.label);

  /// What the badge reads in English, and the name the tests address it by.
  ///
  /// Uppercase in the design, and short enough that it never competes with the
  /// title for the row. [labelIn] is what a row actually renders — this stays
  /// as the stable, language-independent handle.
  final String label;

  /// What the badge reads, in the reader's language.
  String labelIn(AppLocalizations l10n) => switch (this) {
    NotificationPill.done => l10n.notificationPillDone,
    NotificationPill.actionNeeded => l10n.notificationPillNew,
    NotificationPill.info => l10n.notificationPillInfo,
  };

  Color get foreground => switch (this) {
    NotificationPill.done => AppColors.pine,
    NotificationPill.actionNeeded => AppColors.amberBrand,
    NotificationPill.info => AppColors.inkMid,
  };

  Color get background => switch (this) {
    NotificationPill.done => AppColors.pinePale,
    NotificationPill.actionNeeded => AppColors.amberPale,
    NotificationPill.info => AppColors.mist,
  };

  /// The pill's fill on a row painted [rowFill].
  ///
  /// **A pill never wears the same colour as the row it sits on.** An unread
  /// row is filled `pinePale`, which is exactly [done]'s background, so a
  /// `DONE` pill on an unread row was four pine letters floating with no
  /// badge around them — invisible as a pill, and a different component from
  /// the same pill one row down. White is the fallback because it is what the
  /// icon disc already flips to on an unread row: on a green card, the chrome
  /// goes white.
  Color backgroundOn(Color rowFill) =>
      background == rowFill ? AppColors.card : background;
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon, tint and pill per type
// ─────────────────────────────────────────────────────────────────────────────

/// What a row looks like: the glyph in its circle, the tint of that circle
/// and glyph, and the pill at the far right.
typedef NotificationVisual = ({
  String glyph,
  Color tint,
  NotificationPill pill,
});

/// The glyph shown for a `type` this build has never heard of.
///
/// The API can add a key at any time — the contract says adding one is
/// additive — and an app already on a phone has to render it. A neutral dot
/// and an `INFO` pill say "something happened" without inventing a meaning,
/// which is the honest reading of a row whose title and body are still
/// perfectly readable.
const String unknownNotificationGlyph = '•';

/// Every `type` in the API's registry today, grouped as that document groups
/// them. Exported so a test can walk the whole contract instead of whichever
/// keys someone remembered.
const List<String> notificationTypes = [
  // Bookings
  'SESSION_BOOKED',
  'SESSION_NEW_BOOKING',
  'SESSION_RESCHEDULED',
  'SESSION_RESCHEDULE_REQUESTED',
  'SESSION_DECLINE_REQUESTED',
  'SESSION_CANCELLED',
  'SESSION_COMPLETED',
  'SESSION_RATE_REQUEST',
  // Money
  'PAYMENT_RECEIVED',
  'REFUND_REQUESTED',
  'REFUND_APPROVED',
  'REFUND_DENIED',
  // Therapist lifecycle
  'APPLICATION_APPROVED',
  'APPLICATION_REJECTED',
  'RATE_CHANGE_APPROVED',
  'RATE_CHANGE_REJECTED',
  'LEAVE_APPROVED',
  'LEAVE_REJECTED',
  // Care record
  'REPORT_UPLOADED',
  // Rewards
  'REFERRAL_JOINED',
  'REFERRAL_REWARDED',
  'POINTS_MATURED',
];

/// The visual for one `type`.
///
/// Glyphs are chosen by *subject* where the subject is what makes a row
/// scannable — a licence decision, a rate decision, a leave decision all keep
/// one glyph — and the tint carries the outcome: pine for went-your-way,
/// danger for did-not, amber for in-progress or wanting attention, neutral
/// grey for a bare fact. Reading down the feed, colour tells you how you did
/// and the glyph tells you what about.
NotificationVisual notificationVisualFor(String type) => switch (type) {
  // ── Bookings ──────────────────────────────────────────────────────────
  'SESSION_BOOKED' => (
    glyph: '✓',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  // The therapist's side of the same event. They have to turn up for it, so
  // it is the one booking row that is asking something.
  'SESSION_NEW_BOOKING' => (
    glyph: '📅',
    tint: AppColors.pine,
    pill: NotificationPill.actionNeeded,
  ),
  // Already applied by the time it is announced — the patient moved the
  // slot, nobody has to approve it.
  'SESSION_RESCHEDULED' => (
    glyph: '🔄',
    tint: AppColors.amberBrand,
    pill: NotificationPill.info,
  ),
  'SESSION_RESCHEDULE_REQUESTED' => (
    glyph: '🔄',
    tint: AppColors.amberBrand,
    pill: NotificationPill.actionNeeded,
  ),
  // An acknowledgement to the therapist that their decline was filed, not a
  // question put to them: the decision lands later as a cancellation.
  'SESSION_DECLINE_REQUESTED' => (
    glyph: '⏳',
    tint: AppColors.amberBrand,
    pill: NotificationPill.info,
  ),
  'SESSION_CANCELLED' => (
    glyph: '✕',
    tint: AppColors.danger,
    pill: NotificationPill.done,
  ),
  'SESSION_COMPLETED' => (
    glyph: '🏁',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  'SESSION_RATE_REQUEST' => (
    glyph: '★',
    tint: AppColors.amberBrand,
    pill: NotificationPill.actionNeeded,
  ),

  // ── Money ─────────────────────────────────────────────────────────────
  'PAYMENT_RECEIVED' => (
    glyph: '💳',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  // One glyph, three tints: the case is open, then it went one way or the
  // other. Both endings are endings, so both are DONE.
  'REFUND_REQUESTED' => (
    glyph: '↩',
    tint: AppColors.inkMid,
    pill: NotificationPill.info,
  ),
  'REFUND_APPROVED' => (
    glyph: '↩',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  'REFUND_DENIED' => (
    glyph: '↩',
    tint: AppColors.danger,
    pill: NotificationPill.done,
  ),

  // ── Therapist lifecycle ───────────────────────────────────────────────
  'APPLICATION_APPROVED' => (
    glyph: '📜',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  'APPLICATION_REJECTED' => (
    glyph: '📜',
    tint: AppColors.danger,
    pill: NotificationPill.done,
  ),
  'RATE_CHANGE_APPROVED' => (
    glyph: '💰',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  'RATE_CHANGE_REJECTED' => (
    glyph: '💰',
    tint: AppColors.danger,
    pill: NotificationPill.done,
  ),
  'LEAVE_APPROVED' => (
    glyph: '🌴',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  'LEAVE_REJECTED' => (
    glyph: '🌴',
    tint: AppColors.danger,
    pill: NotificationPill.done,
  ),

  // ── Care record ───────────────────────────────────────────────────────
  // There is a document waiting to be read, so this one is asking.
  'REPORT_UPLOADED' => (
    glyph: '📄',
    tint: AppColors.pine,
    pill: NotificationPill.actionNeeded,
  ),

  // ── Rewards ───────────────────────────────────────────────────────────
  // Someone signed up with your code. The payout is a separate row, later,
  // once they have actually had a session — so this is news, not a reward.
  'REFERRAL_JOINED' => (
    glyph: '🎁',
    tint: AppColors.inkMid,
    pill: NotificationPill.info,
  ),
  'REFERRAL_REWARDED' => (
    glyph: '🎁',
    tint: AppColors.pine,
    pill: NotificationPill.done,
  ),
  'POINTS_MATURED' => (
    glyph: '✨',
    tint: AppColors.amberBrand,
    pill: NotificationPill.done,
  ),

  _ => (
    glyph: unknownNotificationGlyph,
    tint: AppColors.inkMute,
    pill: NotificationPill.info,
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Where a tap goes
// ─────────────────────────────────────────────────────────────────────────────

/// A route to open when a row is tapped.
///
/// [isTab] separates the two kinds of destination, because go_router treats
/// them differently and getting it wrong is visible. A tab root has to be
/// reached with `go`, which switches branches — `push`ing one would stack a
/// second copy of the Sessions screen *inside* the Notifications tab. Anything
/// else is `push`ed, which stacks on the current branch's navigator, so the
/// page opens inside the Notifications tab and Back returns to the feed.
typedef NotificationDestination = ({String path, bool isTab});

/// Where tapping a row goes, or null when the app has nowhere to send it.
///
/// **Role-guarded, because the router bounces cross-role paths.** Sending a
/// therapist to `/patient/sessions` does not show them a session — the
/// redirect in `app_router.dart` throws them to `/therapist/home`, which is
/// how this screen behaved before: every `SESSION` row, on either side of the
/// booking, went to `/patient/sessions` unconditionally.
///
/// Null is a real answer, not a gap to paper over. Several `refType`s point at
/// things this app has no screen for, and the rule is that a tap on one still
/// marks the row read and leaves the reader on the feed. Navigating "close
/// to" the subject — a payment receipt to the saved-cards screen, say — is
/// worse than not moving: it costs the reader their place and does not answer
/// the question the row raised.
///
/// | `refType` | patient | therapist | why |
/// |---|---|---|---|
/// | `SESSION` | `/patient/sessions` | `/therapist/requests` | Each role's full session list. The therapist screen's four tabs (Requests / Upcoming / Completed / Cancelled) are the twin of the patient's three, and `/therapist/schedule` is a calendar, not a list. |
/// | `REPORT` | `/patient/reports` | — | Reports are filed *for* patients; a therapist never receives one of these rows. |
/// | `REFERRAL` | `/patient/referral` | `/therapist/referral` | Refer & earn, one per role. |
/// | `POINTS` | `/patient/rewards` | `/therapist/rewards` | Both point at `MyPointsScreen`. |
/// | `THERAPIST` | — | `/therapist/certifications` | The application itself: NMC licence and certificates. |
/// | `LEAVE` | — | `/therapist/availability` | Where working days and blocks are managed. |
/// | `RATE_CHANGE` | — | `/therapist/rate-increase` | The two rows with this `refType` are `RATE_CHANGE_APPROVED` and `RATE_CHANGE_REJECTED`, and the fact both of them turn on is the therapist's rate — which this screen reads live from `GET /therapists/me/profile` and shows as `CURRENT`. Filing a *new* request from it is still blocked (A16), and the screen says so rather than pretending; that does not make it the wrong place to land, because the question an approval row raises is "what am I on now?". Patients never receive one. |
/// | `PAYMENT` | — | — | The app has no payment-history screen. Saved payment *methods* are not it. |
/// | `REFUND` | — | — | No refund or case screen exists in the app at all. |
/// | anything else | — | — | A `refType` from a newer API than this build. |
NotificationDestination? notificationDestinationFor({
  required String? refType,
  required bool isTherapist,
}) => switch (refType) {
  'SESSION' => isTherapist
      ? (path: '/therapist/requests', isTab: true)
      : (path: '/patient/sessions', isTab: true),
  'REPORT' => isTherapist ? null : (path: '/patient/reports', isTab: false),
  'REFERRAL' => isTherapist
      ? (path: '/therapist/referral', isTab: false)
      : (path: '/patient/referral', isTab: false),
  'POINTS' => isTherapist
      ? (path: '/therapist/rewards', isTab: false)
      : (path: '/patient/rewards', isTab: false),
  'THERAPIST' => isTherapist
      ? (path: '/therapist/certifications', isTab: false)
      : null,
  'LEAVE' => isTherapist
      ? (path: '/therapist/availability', isTab: false)
      : null,
  'RATE_CHANGE' => isTherapist
      ? (path: '/therapist/rate-increase', isTab: false)
      : null,
  _ => null,
};
