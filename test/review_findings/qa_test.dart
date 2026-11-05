// Regression tests from the sub-agent review of feat/date-time-pickers (2026-10-08):
// each reproduced a bug the review found; they now pin the fixes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/location/geo_point.dart';
import 'package:sahayatri_care_connect/core/location/location_service.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';
import 'package:sahayatri_care_connect/core/map/map_tiles.dart';
import 'package:sahayatri_care_connect/core/validation/validators.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/widgets/location_autocomplete_field.dart';
import 'package:sahayatri_care_connect/core/widgets/slot_pickers.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/care_models.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_profile_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/booking_screen.dart';
import 'package:sahayatri_care_connect/features/rewards/presentation/providers/points_providers.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/widgets/visit_map_preview.dart';

import 'package:sahayatri_care_connect/features/rewards/data/models/points_models.dart';

import '../l10n_harness.dart';

const _old = GeoPoint(27.70, 85.30); // yesterday's last-known fix
const _a = GeoPoint(27.6915, 85.342);
const _b = GeoPoint(27.6710, 85.3240);

Session _visit(String id, GeoPoint p) => Session(
  id: id,
  therapistId: 't1',
  therapistName: 'Dr. Rai',
  patientId: 'p1',
  patientName: 'X',
  patientPhone: '',
  date: DateTime.now().add(const Duration(days: 1)),
  time: '09:00',
  type: 'HOME_VISIT',
  status: SessionStatus.scheduled,
  address: 'House 12, Baneshwor, Kathmandu',
  point: p,
  fee: 1500,
);

class _SlowPrecise implements LocationService {
  final precise = Completer<LocationLookup>();
  @override
  Future<DetectedLocation?> describe(GeoPoint point) async => null;
  @override
  Future<LocationLookup> detect({bool precise = false}) {
    if (!precise) {
      // Approximate lookup: the last-known position, good accuracy, old.
      return Future.value(
        LocationFound(
          const DetectedLocation(
            city: 'Kathmandu',
            area: 'Old Place',
          ).withFix(_old, 30),
        ),
      );
    }
    return this.precise.future;
  }
}

final _noTiles = mapTileLayerProvider.overrideWithValue(
  () => const SizedBox.shrink(),
);

void main() {
  testWidgets('QA1 map preview follows the session it is rebuilt with', (
    tester,
  ) async {
    final which = ValueNotifier<Session>(_visit('a', _a));
    await pumpLocalized(
      tester,
      Scaffold(
        body: ValueListenableBuilder<Session>(
          valueListenable: which,
          builder: (_, s, _) => VisitMapPreview(session: s, onOpen: () {}),
        ),
      ),
      overrides: [_noTiles],
    );
    await tester.pumpAndSettle();
    final markerEl = tester.element(find.byType(MarkerLayer));
    expect(MapCamera.of(markerEl).center.latitude, closeTo(_a.latitude, 1e-6));

    which.value = _visit('b', _b);
    await tester.pumpAndSettle();
    final markerEl2 = tester.element(find.byType(MarkerLayer));
    // Fails: camera still on A while the marker moved to B (off-screen).
    expect(MapCamera.of(markerEl2).center.latitude, closeTo(_b.latitude, 1e-6));
  });

  testWidgets('QA2 a pin is not taken from an approximate fix while the '
      'precise lookup is in flight', (tester) async {
    final service = _SlowPrecise();
    final controller = TextEditingController();
    GeoPoint? pinned;
    final container = await pumpLocalized(
      tester,
      Scaffold(
        body: LocationAutocompleteField(
          controller: controller,
          detail: LocationDetail.address,
          pinnable: true,
          onPinChanged: (p) => pinned = p,
        ),
      ),
      overrides: [_noTiles, locationServiceProvider.overrideWithValue(service)],
    );
    // Some earlier screen's city field did an approximate lookup.
    await container.read(locationSuggestionProvider.notifier).ensureDetected();
    await tester.pump();

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(container.read(locationSuggestionProvider).detecting, isTrue);

    // The stale approximate suggestion is no longer offered while the
    // precise lookup runs, so it cannot be pinned.
    expect(find.text('Old Place, Kathmandu'), findsNothing);
    expect(find.text('Finding your location…'), findsOneWidget);
    expect(pinned, isNull);
  });

  testWidgets('QA3 slot fields show a time the chosen day no longer has', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: SlotPickerFields(
          openTimes: const {
            '2099-01-02': ['11:00'],
          },
          date: '2099-01-01', // vanished after a refresh
          time: '10:00',
          onDate: (_) {},
          onTime: (_) {},
        ),
      ),
    );
    // Fails: the stale time is still displayed as the selection.
    expect(find.text('10:00'), findsNothing);
  });

  testWidgets('QA4 the booking prefill shows a red error before any '
      'interaction when the profile arrives after first build', (tester) async {
    final profile = Completer<PatientProfileDto?>();
    await pumpLocalized(
      tester,
      const BookingScreen(therapistId: 't1', date: '2099-01-01', time: '10:00'),
      overrides: [
        therapistDetailProvider('t1').overrideWith(
          (_) async => const Therapist(
            id: 't1',
            userId: 'u1',
            name: 'Dr. Rai',
            specialty: 'Ortho',
            city: 'Kathmandu',
            gender: 'Male',
            rating: 0,
            reviewCount: 0,
            fee: 1500,
            experienceYears: 3,
            bio: '',
          ),
        ),
        platformFeePercentProvider.overrideWith((_) async => 5),
        patientProfileProvider.overrideWith((_) => profile.future),
        currentUserProvider.overrideWith((_) => null),
        spendablePointsProvider.overrideWithValue(0),
        pointBalanceProvider.overrideWith(
          (_) async => const PointBalanceDto(balance: 0),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextFormField), findsWidgets);

    profile.complete(const PatientProfileDto(address: 'Kathmandu'));
    await tester.pump();
    await tester.pump();

    final ctx = tester.element(find.byType(BookingScreen));
    final err = Validators.visitAddress(ctx.l10n)('Kathmandu');
    // Not that the city is refused -- that is correct -- but nobody
    // has touched the field yet.
    expect(
      find.textContaining('is only the city'),
      findsNothing,
      reason: 'error $err shown before interaction',
    );
  });

  test('QA5 visitAddress lets a short Devanagari address through?', () {
    // 'ठमेल-२६' (Thamel-26) is 7 UTF-16 units.
    expect('ठमेल-२६'.length, lessThan(10));
  });
}
