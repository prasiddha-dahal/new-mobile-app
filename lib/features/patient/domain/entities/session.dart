import '../../../../core/location/geo_point.dart';

/// Lifecycle of a booked session, mirroring the backend `SessionStatus` enum.
enum SessionStatus {
  scheduled('SCHEDULED', 'Confirmed'),
  inProgress('IN_PROGRESS', 'In progress'),
  completed('COMPLETED', 'Done'),
  cancelled('CANCELLED', 'Cancelled'),

  /// A gateway booking whose payment has not settled yet.
  ///
  /// The server creates it in this state and deliberately leaves the slot
  /// unlocked, so it is *not* a booking: somebody else can still take the
  /// time, and an abandoned hold is swept to CANCELLED after twenty minutes.
  /// It was missing from this enum, so a held session read as `unknown` and
  /// every list that filters on status silently dropped it.
  pendingHold('PENDING_HOLD', 'Awaiting payment'),
  rescheduleRequested('RESCHEDULE_REQUESTED', 'Reschedule requested'),
  declineRequested('DECLINE_REQUESTED', 'Decline requested'),
  unknown('', 'Unknown');

  const SessionStatus(this.wireValue, this.label);

  /// Value as it appears in JSON.
  final String wireValue;

  /// Human-facing label used on badges.
  final String label;

  static SessionStatus fromWire(String? value) {
    final v = (value ?? '').toUpperCase();
    return SessionStatus.values.firstWhere(
      (s) => s.wireValue == v,
      orElse: () => SessionStatus.unknown,
    );
  }

  bool get isUpcoming =>
      this == scheduled ||
      this == inProgress ||
      this == rescheduleRequested ||
      this == declineRequested;

  bool get isPast => this == completed;
  bool get isCancelled => this == cancelled;

  /// Paid for? Not yet. Deliberately excluded from [isUpcoming]: showing a
  /// hold beside confirmed bookings is how a patient comes to believe they
  /// have an appointment they do not have.
  bool get isAwaitingPayment => this == pendingHold;

  /// Only a SCHEDULED session can be moved or called off.
  bool get canReschedule => this == scheduled;
  bool get canCancel => this == scheduled;
}

/// A booked session (pure Dart).
class Session {
  const Session({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.date,
    required this.time,
    required this.type,
    required this.status,
    required this.address,
    this.point,
    this.landmark,
    required this.fee,
    this.notes,
    this.therapistPhotoUrl,
    this.therapistPhotoThumbUrl,
    this.patientPhotoUrl,
    this.patientPhotoThumbUrl,
  });

  final String id;
  final String therapistId;

  /// Photo links, null when the person has not set one. Use the `Thumb`
  /// variant in a list or card. The patient's is only ever present on a
  /// therapist's own views.
  final String? therapistPhotoUrl;
  final String? therapistPhotoThumbUrl;
  final String? patientPhotoUrl;
  final String? patientPhotoThumbUrl;

  /// Empty string when the backend did not join the therapist relation.
  final String therapistName;
  final String patientId;

  /// Only populated on the therapist's own list; empty for patients.
  final String patientName;
  final String patientPhone;
  final DateTime date;

  /// `HH:MM`.
  final String time;

  /// `HOME_VISIT` or `CLINIC`.
  final String type;
  final SessionStatus status;
  final String address;

  /// Where a home visit is, when the patient pinned it. Null when they only
  /// typed an address -- navigation then falls back to searching for it.
  final GeoPoint? point;

  /// Directions the address cannot give. Null or blank when there are none.
  final String? landmark;
  final double fee;
  final String? notes;

  bool get isHomeVisit => type.toUpperCase() == 'HOME_VISIT';

  /// True once the scheduled day has passed.
  ///
  /// Status alone is not enough to place a session in the right tab: the
  /// backend leaves a session SCHEDULED even after its slot goes by, so a
  /// booking from last month would otherwise sit under "Upcoming" offering a
  /// Reschedule the API would refuse.
  bool get hasElapsed {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return date.isBefore(startOfToday);
  }

  /// Still ahead of the patient — the "Upcoming" tab.
  bool get isUpcoming => status.isUpcoming && !hasElapsed;

  /// Done, or a scheduled slot whose time has simply gone by.
  bool get isPast => status.isPast || (status.isUpcoming && hasElapsed);

  bool get isCancelled => status.isCancelled;

  /// Rescheduling and cancelling only make sense for a session still ahead.
  bool get canReschedule => status.canReschedule && !hasElapsed;
  bool get canCancel => status.canCancel && !hasElapsed;

  /// `YYYY-MM-DD`, the format the reschedule endpoint expects.
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
