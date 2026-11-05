import '../../../../core/error/failures.dart';
import '../entities/working_hours.dart';

/// The therapist's own side of availability: the weekly pattern patients
/// book against.
///
/// ## Why saving is one call and not two
///
/// The API has a `PUT /availability/working-hours` that stores the pattern
/// and a `POST /availability/generate` that stores it *and* materialises the
/// slot rows. Only the second one takes effect.
///
/// `GET /availability/slots` — the endpoint the patient's profile grid, the
/// availability filter and the next-free-slot line all read — builds its grid
/// from the stored `start`, `end` and `sessionDuration + breakDuration`, and
/// then overlays whatever `AvailabilitySlot` rows exist. It applies **no
/// day-of-week filter**: verified against the running server, a therapist
/// whose stored `daysOfWeek` is Mon–Fri still comes back with nine `open`
/// slots on Saturday and Sunday. Days off are only real once an `off` row
/// exists for them.
///
/// So `PUT /working-hours` alone would change the *hours* and silently drop
/// the *days*, which is half a save presented as a whole one. `generate`
/// writes the rows and saves the pattern in the same request, which is why it
/// is the only write here.
abstract class TherapistAvailabilityRepository {
  /// The pattern currently stored for the signed-in therapist.
  ///
  /// Never invents one: a failed read is a [Failure], because a screen that
  /// opens showing a default as though it were saved is the bug this feature
  /// was built to remove.
  Future<AppResult<WorkingHours>> getWorkingHours();

  /// Stores [hours] and rewrites the next [availabilityWriteHorizonDays] days
  /// of slots to match, starting at [from].
  ///
  /// Booked slots and slots already in the past are left untouched — that is
  /// the server's behaviour and callers can rely on it, so saving a narrower
  /// week never cancels an appointment.
  ///
  /// The request is slow by nature: the server writes each slot individually,
  /// so a full seven-day, nine-slot week is well over a hundred round trips
  /// inside one call. Implementations must raise the transport timeout rather
  /// than let a save that is working be reported as a failure.
  Future<AppResult<WorkingHoursSaved>> saveWorkingHours(
    WorkingHours hours, {
    required DateTime from,
  });
}
