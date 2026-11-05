// Regression tests from the sub-agent review of feat/date-time-pickers (2026-10-08):
// each reproduced a bug the review found; they now pin the fixes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/location/geo_point.dart';
import 'package:sahayatri_care_connect/core/location/location_service.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';
import 'package:sahayatri_care_connect/core/map/map_pin_picker.dart';
import 'package:sahayatri_care_connect/core/map/map_tiles.dart';
import 'package:sahayatri_care_connect/core/widgets/slot_pickers.dart';

import '../l10n_harness.dart';

const _gps = GeoPoint(27.6915, 85.342);

class _Slow implements LocationService {
  final c = Completer<LocationLookup>();
  @override
  Future<DetectedLocation?> describe(GeoPoint point) async =>
      const DetectedLocation(city: 'Kathmandu', area: 'Somewhere');
  @override
  Future<LocationLookup> detect({bool precise = false}) => c.future;
}

void main() {
  testWidgets('QA8 picker tile exposes a tap action to screen readers', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpLocalized(
      t,
      Scaffold(
        body: SlotPickerFields(
          openTimes: const {
            '2099-01-02': ['11:00'],
          },
          date: null,
          time: null,
          onDate: (_) {},
          onTime: (_) {},
        ),
      ),
    );
    final node = t.getSemantics(find.byKey(const ValueKey('slot-date')));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets(
    'QA9 a late GPS answer does not move a map the patient already placed',
    (t) async {
      final service = _Slow();
      MapPick? picked;
      await pumpLocalized(
        t,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showMapPinPicker(context),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          mapTileLayerProvider.overrideWithValue(() => const SizedBox.shrink()),
          locationServiceProvider.overrideWithValue(service),
        ],
      );
      await t.tap(find.text('open'));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      // Patient drags the map to their door while the precise fix is slow.
      await t.drag(find.byType(FlutterMap), const Offset(-150, 120));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final placed = MapCamera.of(
        t.element(find.byType(MapAttribution)),
      ).center;

      service.c.complete(
        LocationFound(
          const DetectedLocation(city: 'Kathmandu').withFix(_gps, 10),
        ),
      );
      await t.pumpAndSettle(const Duration(seconds: 1));
      await t.tap(find.text('Use this location'));
      await t.pumpAndSettle();
      expect(picked, isNotNull);
      // Fails: the late answer moved the map back to the GPS fix.
      expect(picked!.point.latitude, closeTo(placed.latitude, 1e-6));
    },
  );
}
