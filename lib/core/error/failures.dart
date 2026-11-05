import 'package:fpdart/fpdart.dart';

/// Base failure type for the entire application.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error occurred']);
}

/// The request timed out. Distinct from [NetworkFailure] because the hosted API
/// sleeps when idle, so a timeout is often a cold start rather than a real fault
/// and the UI offers "try again" instead of "check your connection".
class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.message = 'The server is taking longer than usual to respond.',
  ]);
}

/// The server could not be reached at all — it is down, suspended, or the base
/// URL is wrong. Surfaced to the user as an explicit "server unavailable" state.
class ServerUnavailableFailure extends Failure {
  const ServerUnavailableFailure([
    super.message = 'Cannot reach the server right now.',
  ]);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized']);
}

/// Login was refused because a therapist account has not been approved yet.
/// Carries the account status so the caller can route to the right screen.
class AccountPendingFailure extends Failure {
  const AccountPendingFailure(
    this.status, [
    super.message = 'Your application is under review.',
  ]);

  final String status;

  bool get isRejected => status.toUpperCase() == 'REJECTED';
}

class ValidationFailure extends Failure {
  const ValidationFailure(this.fieldErrors, [super.message = 'Validation error']);
  final Map<String, String> fieldErrors;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'Resource already exists']);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = 'Too many attempts. Please wait.']);
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage error']);
}

/// The feature is built in the app but the backend endpoint does not exist yet.
///
/// This is the API-TODO convention from docs/DEVELOPMENT_PLAN.md §0.2: the screen
/// is complete and reachable, and it renders an honest "not available yet" state
/// rather than faking success or crashing. [endpoint] names the missing route so
/// the register in docs/TODO_REGISTER.md can be regenerated from the code.
class NotImplementedFailure extends Failure {
  const NotImplementedFailure(
    this.endpoint, [
    super.message = 'This feature is not available yet.',
  ]);

  final String endpoint;
}

/// A weekly working pattern that was refused before it reached the network.
///
/// Lives here rather than beside the availability use cases only because
/// [Failure] is sealed. [reason] is a
/// `WorkingHoursProblem.name` — the enum itself is in the therapist feature,
/// and core must not depend on a feature — so the screen maps it back to a
/// translated sentence. [message] is the English fallback the generic error
/// surfaces use when nobody does.
class InvalidWorkingHoursFailure extends Failure {
  const InvalidWorkingHoursFailure(this.reason, super.message);

  final String reason;
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error occurred']);
}

/// Type alias for `Either<Failure, T>` used throughout the app.
typedef AppResult<T> = Either<Failure, T>;

/// Type alias for async `Either<Failure, T>`.
typedef AsyncAppResult<T> = Future<Either<Failure, T>>;

/// Extension to fold on `Future<AppResult<T>>`.
extension AppResultExtension<T> on Future<AppResult<T>> {
  Future<R> fold<R>({
    required R Function(Failure failure) onFailure,
    required R Function(T value) onSuccess,
  }) async {
    final result = await this;
    return result.fold(onFailure, onSuccess);
  }
}
