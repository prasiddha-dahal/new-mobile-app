import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/location/directions.dart';
import 'package:sahayatri_care_connect/core/location/geo_point.dart';
import 'package:sahayatri_care_connect/core/location/location_service.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';
import 'package:sahayatri_care_connect/core/map/map_pin_picker.dart';
import 'package:sahayatri_care_connect/core/map/map_tiles.dart';
import 'package:sahayatri_care_connect/core/widgets/location_autocomplete_field.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/widgets/visit_map_preview.dart';

import '../l10n_harness.dart';

/// The map: choosing a visit's point by dragging a map under a fixed pin, and
/// a therapist's small map of where the visit is.
///
/// Tiles are swapped for an empty box -- tests have no network, and the map
/// must work (and tell the patient where they are) without one.

const _here = GeoPoint(27.6915, 85.342);

class _FakeLocation implements LocationService {
  int described = 0;

  @override
  Future<DetectedLocation?> describe(GeoPoint point) async {
    described++;
    return const DetectedLocation(city: 'Kathmandu', area: 'Baneshwor');
  }

  @override
  Future<LocationLookup> detect({bool precise = false}) async => LocationFound(
    const DetectedLocation(city: 'Kathmandu', area: 'Baneshwor')
        .withFix(_here, 10),
  );
}

final _noTiles = mapTileLayerProvider.overrideWithValue(
  () => const SizedBox.shrink(),
);

void main() {
  test('the tiles are OpenStreetMap, and the app names itself to them', () {
    expect(MapTiles.osmTemplate, contains('tile.openstreetmap.org'));
    expect(MapTiles.userAgentPackageName, 'com.sahayatri.sahayatri_care_connect');
  });

  group('the pin picker', () {
    testWidgets('opens on the device, names the place, returns the point', (
      tester,
    ) async {
      MapPick? picked;
      await pumpLocalized(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showMapPinPicker(context),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          _noTiles,
          locationServiceProvider.overrideWithValue(_FakeLocation()),
        ],
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Pin your visit address'), findsOneWidget);
      expect(find.text('Baneshwor, Kathmandu'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsWidgets);

      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.point.latitude, closeTo(_here.latitude, 1e-6));
      expect(picked!.point.longitude, closeTo(_here.longitude, 1e-6));
      expect(picked!.label, 'Baneshwor, Kathmandu');
    });
  });

  group('Choose on map in the visit address', () {
    testWidgets('pins the chosen point and fills a bare city', (tester) async {
      final controller = TextEditingController(text: 'Kathmandu');
      addTearDown(controller.dispose);
      final pins = <GeoPoint?>[];

      await pumpLocalized(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LocationAutocompleteField(
              controller: controller,
              detail: LocationDetail.address,
              pinnable: true,
              onPinChanged: pins.add,
            ),
          ),
        ),
        overrides: [
          _noTiles,
          locationServiceProvider.overrideWithValue(_FakeLocation()),
        ],
      );

      await tester.tap(find.text('Choose on map'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      expect(pins.single, isNotNull);
      expect(controller.text, 'Baneshwor, Kathmandu');
      expect(find.text('Pinned on the map'), findsOneWidget);
      expect(find.byTooltip('Move pin on map'), findsOneWidget);
    });

    testWidgets('keeps an address the patient typed', (tester) async {
      final controller = TextEditingController(text: 'House 12, Baneshwor');
      addTearDown(controller.dispose);

      await pumpLocalized(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LocationAutocompleteField(
              controller: controller,
              detail: LocationDetail.address,
              pinnable: true,
            ),
          ),
        ),
        overrides: [
          _noTiles,
          locationServiceProvider.overrideWithValue(_FakeLocation()),
        ],
      );

      await tester.tap(find.text('Choose on map'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      expect(controller.text, 'House 12, Baneshwor');
      expect(find.text('Pinned on the map'), findsOneWidget);
    });

    testWidgets('a city field offers no map', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpLocalized(
        tester,
        Scaffold(body: LocationAutocompleteField(controller: controller)),
        overrides: [locationServiceProvider.overrideWithValue(_FakeLocation())],
      );
      expect(find.text('Choose on map'), findsNothing);
    });
  });

  group('the therapist visit map', () {
    Session visit({GeoPoint? point}) => Session(
      id: 's1',
      therapistId: 't1',
      therapistName: 'Dr. Jane Smith',
      patientId: 'p1',
      patientName: 'John Doe',
      patientPhone: '',
      date: DateTime.now().add(const Duration(days: 1)),
      time: '10:00',
      type: 'HOME_VISIT',
      status: SessionStatus.scheduled,
      address: 'Baneshwor',
      point: point,
      fee: 1500,
    );

    testWidgets('is drawn only for a pinned visit', (tester) async {
      await pumpLocalized(
        tester,
        Scaffold(body: VisitMapPreview(session: visit())),
        overrides: [_noTiles],
      );
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('a tap opens directions to the pin', (tester) async {
      final opened = <Uri>[];
      var tapped = false;
      await pumpLocalized(
        tester,
        Scaffold(
          body: VisitMapPreview(
            session: visit(point: _here),
            onOpen: () => tapped = true,
          ),
        ),
        overrides: [
          _noTiles,
          urlOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      await tester.pumpAndSettle();
      // The map's own tap, so the attribution button stays reachable.
      await tester.tapAt(tester.getCenter(find.byType(VisitMapPreview)));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('the OpenStreetMap credit can still be opened', (tester) async {
      var tapped = false;
      await pumpLocalized(
        tester,
        Scaffold(
          body: VisitMapPreview(
            session: visit(point: _here),
            onOpen: () => tapped = true,
          ),
        ),
        overrides: [_noTiles],
      );
      await tester.pumpAndSettle();
      final credit = find.descendant(
        of: find.byType(RichAttributionWidget),
        matching: find.byType(IconButton),
      );
      expect(credit, findsOneWidget);
      await tester.tap(credit);
      await tester.pumpAndSettle();
      expect(tapped, isFalse, reason: 'the credit button, not directions');
      expect(find.textContaining('OpenStreetMap'), findsWidgets);
    });
  });
}
