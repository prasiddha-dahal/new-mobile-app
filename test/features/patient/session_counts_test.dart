import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/shared_widgets.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/session_labels.dart';

import 'package:sahayatri_care_connect/core/l10n/l10n.dart';

/// QA DATA-01: past visits nobody closed were tagged CONFIRMED, and the
/// Account screen counted them as completed.
Session _visit({required int dayOffset, required SessionStatus status}) {
  final now = DateTime.now();
  return Session(
    id: 's',
    therapistId: 't',
    therapistName: 'Dr. Rai',
    patientId: 'p',
    patientName: '',
    patientPhone: '',
    date: DateTime(now.year, now.month, now.day + dayOffset),
    time: '10:00',
    type: 'HOME_VISIT',
    status: status,
    address: 'Baneshwor',
    fee: 1500,
  );
}

void main() {
  final l10n = englishL10n;

  test('a past visit still marked confirmed says it awaits an update', () {
    final s = _visit(dayOffset: -80, status: SessionStatus.scheduled);
    expect(isAwaitingUpdate(s), isTrue);
    expect(sessionLabel(s, l10n), 'Awaiting update');
    expect(sessionStatusTone(s), TagTone.amber);
  });

  test('today and the future keep their real status', () {
    final today = _visit(dayOffset: 0, status: SessionStatus.scheduled);
    final later = _visit(dayOffset: 3, status: SessionStatus.scheduled);
    expect(isAwaitingUpdate(today), isFalse);
    expect(sessionLabel(later, l10n), 'Confirmed');
  });

  test('a completed or cancelled past visit is not awaiting anything', () {
    expect(
      isAwaitingUpdate(_visit(dayOffset: -3, status: SessionStatus.completed)),
      isFalse,
    );
    expect(
      isAwaitingUpdate(_visit(dayOffset: -3, status: SessionStatus.cancelled)),
      isFalse,
    );
  });
}
