import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/map/map_tiles.dart';
import 'package:sahayatri_care_connect/features/coverage/data/models/coverage_models.dart';
import 'package:sahayatri_care_connect/features/coverage/presentation/widgets/coverage_map.dart';

import '../../l10n_harness.dart';

/// "Therapists near you": the chosen area and the clinics around it.

final _noTiles = mapTileLayerProvider.overrideWithValue(
  () => const SizedBox.shrink(),
);

const _area = ServiceAreaDto(
  id: 'a1',
  name: 'Kathmandu Central',
  latitude: 27.7,
  longitude: 85.333,
);

const _hamro = CoverageClinicDto(
  id: 'c1',
  name: 'Hamro Physio Clinic',
  distanceKm: 4.1,
  latitude: 27.7365,
  longitude: 85.3305,
);

void main() {
  testWidgets('pins the area and its clinics, and a pin opens the clinic', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpLocalized(
      tester,
      Scaffold(
        body: CoverageMap(
          area: _area,
          clinics: const [
            _hamro,
            // Not geocoded yet: listed below the map, never pinned.
            CoverageClinicDto(id: 'c2', name: 'Unmapped'),
          ],
          onClinic: (c) => opened.add(c.id),
        ),
      ),
      overrides: [_noTiles],
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Kathmandu Central'), findsOneWidget);
    expect(find.byIcon(Icons.local_hospital), findsOneWidget);

    await tester.tap(find.byIcon(Icons.local_hospital));
    expect(opened, ['c1']);
  });

  testWidgets('says so when nothing has a place on the map', (tester) async {
    await pumpLocalized(
      tester,
      const Scaffold(
        body: CoverageMap(
          area: ServiceAreaDto(id: 'a2', name: 'Bhaktapur'),
          clinics: [CoverageClinicDto(id: 'c2', name: 'Unmapped')],
        ),
      ),
      overrides: [_noTiles],
    );
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('This area is not on the map yet'), findsOneWidget);
  });

  test('reads a clinic\'s point from the API', () {
    final c = CoverageClinicDto.fromJson({
      'id': 'c1',
      'name': 'Hamro',
      'latitude': 27.7365,
      'longitude': 85.3305,
    });
    expect(c.latitude, 27.7365);
    expect(c.longitude, 85.3305);
  });
}
