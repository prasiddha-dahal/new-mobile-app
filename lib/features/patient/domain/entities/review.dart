import 'session.dart';

/// A review the signed-in patient has already left.
class MyReview {
  const MyReview({
    required this.id,
    required this.sessionId,
    required this.therapistId,
    required this.rating,
    this.comment,
  });

  final String id;
  final String sessionId;
  final String therapistId;

  /// 1–5.
  final int rating;
  final String? comment;
}

/// What a completed session's card says about its review.
sealed class ReviewState {
  const ReviewState();
}

/// Nothing to say: the session is not completed, or the lookups are still in
/// flight and a line that appears and then changes would be worse than none.
class ReviewNone extends ReviewState {
  const ReviewNone();
}

/// The server will still take a review for this session.
class ReviewOpen extends ReviewState {
  const ReviewOpen();
}

/// This very session was reviewed.
class ReviewDone extends ReviewState {
  const ReviewDone(this.review);
  final MyReview review;
}

/// A different session with the same therapist was reviewed. A therapist can
/// be reviewed once, so this one is closed -- but the patient should be told
/// why, not left with a card that silently offers nothing.
class ReviewDoneForTherapist extends ReviewState {
  const ReviewDoneForTherapist(this.review);
  final MyReview review;
}

/// Decides what to show on [session].
///
/// [reviewable] is the server's list of sessions it will still accept a review
/// for, and [reviews] is what the patient has already written. Either may be
/// null while it loads; [reviewableFailed] means the lookup errored, in which
/// case the button is offered (the server refuses a duplicate anyway) so a flaky
/// connection does not take the feature away.
ReviewState reviewStateFor(
  Session session, {
  required Set<String>? reviewable,
  required List<MyReview>? reviews,
  bool reviewableFailed = false,
}) {
  if (session.status != SessionStatus.completed) return const ReviewNone();

  if (reviews != null) {
    for (final r in reviews) {
      if (r.sessionId == session.id) return ReviewDone(r);
    }
  }
  if (reviewable != null && reviewable.contains(session.id)) {
    return const ReviewOpen();
  }
  if (reviewable == null && reviewableFailed) return const ReviewOpen();

  if (reviews != null) {
    for (final r in reviews) {
      if (r.therapistId == session.therapistId) {
        return ReviewDoneForTherapist(r);
      }
    }
  }
  return const ReviewNone();
}
