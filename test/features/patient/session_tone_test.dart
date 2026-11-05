import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/shared_widgets.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/session_labels.dart';

/// One status-to-colour mapping, for both roles.
///
/// It existed already, private to `patient_sessions_screen.dart`. The
/// therapist dashboard had written its own — `completed ? neutral : green` —
/// which painted *everything* not yet finished the same green, so a visit
/// still waiting on the therapist read identically to one they had agreed
/// to. That is the therapist's own list of today's work, and the badge is the
/// only thing on the row that says which is which.
void main() {
  Session withStatus(SessionStatus status) => Session(
    id: 's',
    therapistId: 't',
    therapistName: 'Dr. Test',
    patientId: 'p',
    patientName: 'Pranita K.',
    patientPhone: '',
    date: DateTime.now().add(const Duration(days: 1)),
    time: '09:00',
    type: 'HOME_VISIT',
    status: status,
    address: 'Lalitpur',
    fee: 1500,
  );

  test('a confirmed visit is green', () {
    expect(sessionStatusTone(withStatus(SessionStatus.scheduled)), TagTone.green);
  });

  test('a finished one is neutral', () {
    expect(
      sessionStatusTone(withStatus(SessionStatus.completed)),
      TagTone.neutral,
    );
  });

  test('a cancelled one is red', () {
    expect(sessionStatusTone(withStatus(SessionStatus.cancelled)), TagTone.red);
  });

  test('and anything still waiting on somebody is amber, not green', () {
    // This is the case the therapist dashboard used to get wrong. Spec §31
    // draws these as a warning badge.
    for (final status in [
      SessionStatus.rescheduleRequested,
      SessionStatus.declineRequested,
      SessionStatus.inProgress,
    ]) {
      expect(
        sessionStatusTone(withStatus(status)),
        TagTone.amber,
        reason: '$status must not read as confirmed',
      );
    }
  });

  test('every status has a tone, including one the API has not invented yet', () {
    for (final status in SessionStatus.values) {
      expect(sessionStatusTone(withStatus(status)), isA<TagTone>());
    }
  });
}
