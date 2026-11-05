/// A session already booked against a package, as returned inside
/// `GET /packages/my-purchases/active`.
///
/// The wire shape is a loose dict — `{id, date, time, therapistName, status}` —
/// with `date` as a bare `YYYY-MM-DD` string, so [date] is nullable and [rawDate]
/// keeps whatever arrived.
class PackageSessionRef {
  const PackageSessionRef({
    required this.id,
    required this.rawDate,
    this.date,
    this.time = '',
    this.therapistName = '',
    this.status = '',
  });

  final String id;
  final String rawDate;
  final DateTime? date;
  final String time;
  final String therapistName;
  final String status;

  /// Statuses that still lie ahead of the patient. `COMPLETED` and `CANCELLED`
  /// sessions are history; a decline/reschedule request is still pending.
  static const _upcomingStatuses = {
    'SCHEDULED',
    'IN_PROGRESS',
    'RESCHEDULE_REQUESTED',
  };

  bool isUpcomingAt(DateTime now) {
    final when = date;
    if (when == null) return false;
    if (!_upcomingStatuses.contains(status.toUpperCase())) return false;
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    return !day.isBefore(today);
  }
}

/// A patient's purchase of a package — `PackagePurchaseResponse`, plus the
/// `sessions` list that only the `/active` detail response carries.
class PackagePurchase {
  const PackagePurchase({
    required this.id,
    required this.packageId,
    required this.packageName,
    this.packageTag = '',
    required this.sessionsTotal,
    required this.sessionsUsed,
    this.status = '',
    this.purchasedAt,
    this.expiresAt,
    this.sessions = const [],
  });

  final String id;
  final String packageId;
  final String packageName;
  final String packageTag;

  final int sessionsTotal;
  final int sessionsUsed;

  /// `ACTIVE`, `EXPIRED`, `DEPLETED`, … Kept as the raw wire string: the
  /// backend types it as a plain column with no enum, so mapping it to a closed
  /// set here would silently swallow any value added later.
  final String status;

  final DateTime? purchasedAt;
  final DateTime? expiresAt;

  /// Empty for list rows; populated for `/my-purchases/active`.
  final List<PackageSessionRef> sessions;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  /// Sessions left. Derived rather than read off the wire so the arithmetic
  /// cannot disagree with the two numbers shown beside it, and so an
  /// over-counted `sessionsUsed` can never render as negative.
  int get sessionsRemaining {
    if (sessionsTotal <= 0) return 0;
    final left = sessionsTotal - sessionsUsed;
    return left < 0 ? 0 : (left > sessionsTotal ? sessionsTotal : left);
  }

  /// 0.0 – 1.0. A zero-session package is 0, never a division by zero.
  double get progress {
    if (sessionsTotal <= 0) return 0;
    final ratio = sessionsUsed / sessionsTotal;
    if (ratio.isNaN || ratio < 0) return 0;
    return ratio > 1 ? 1 : ratio;
  }

  /// Whole percent for the label beside the bar.
  int get progressPercent => (progress * 100).round();

  bool get isDepleted => sessionsTotal > 0 && sessionsRemaining == 0;

  /// Expiry is inclusive of the instant itself — at `expiresAt` the package is
  /// spent, which is how the backend's `expiresAt < now` sweep behaves within a
  /// tick either way.
  bool isExpiredAt(DateTime now) {
    final end = expiresAt;
    return end != null && !end.isAfter(now);
  }

  /// Whole days left before expiry, floored at 0. Counted on calendar days so
  /// "expires tomorrow" does not read as 0 days because of the clock time.
  int daysRemainingAt(DateTime now) {
    final end = expiresAt;
    if (end == null) return 0;
    final endDay = DateTime(end.year, end.month, end.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = endDay.difference(today).inDays;
    return days < 0 ? 0 : days;
  }

  /// Whether the patient can still book against this purchase.
  bool isUsableAt(DateTime now) =>
      isActive && !isExpiredAt(now) && sessionsRemaining > 0;

  /// The soonest session still ahead, or null when the detail response carried
  /// none (and always null for list rows, which have no `sessions`).
  PackageSessionRef? nextSessionAt(DateTime now) {
    PackageSessionRef? best;
    for (final s in sessions) {
      if (!s.isUpcomingAt(now)) continue;
      if (best == null || s.date!.isBefore(best.date!)) best = s;
    }
    return best;
  }
}
