import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/location/directions.dart';
import 'package:sahayatri_care_connect/core/location/geo_point.dart';
import 'package:sahayatri_care_connect/core/location/location_service.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';
import 'package:sahayatri_care_connect/core/map/map_tiles.dart';
import 'package:sahayatri_care_connect/core/widgets/location_autocomplete_field.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/session_models.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/widgets/navigate_button.dart';

import '../l10n_harness.dart';

/// Pinning a home visit's exact point, and sending a therapist to it.
///
/// The point comes only from an explicit "use my current location" in the
/// visit address field, only when the fix is good enough to navigate to, and it
/// is dropped as soon as the address no longer names that place.

const _here = GeoPoint(27.6915, 85.342);

class _FakeLocation implements LocationService {
  _FakeLocation(this.result);
  LocationLookup result;
  final preciseCalls = <bool>[];

  @override
  Future<DetectedLocation?> describe(GeoPoint point) async => null;

  @override
  Future<LocationLookup> detect({bool precise = false}) async {
    preciseCalls.add(precise);
    return result;
  }
}

LocationFound _found({double accuracy = 12}) => LocationFound(
  const DetectedLocation(
    city: 'Kathmandu',
    area: 'Baneshwor',
  ).withFix(_here, accuracy),
);

Session _visit({
  GeoPoint? point,
  String address = 'House 12, Baneshwor, Kathmandu',
  String? landmark,
  String type = 'HOME_VISIT',
  SessionStatus status = SessionStatus.scheduled,
  DateTime? date,
}) => Session(
  id: 's1',
  therapistId: 't1',
  therapistName: 'Dr. Rai',
  patientId: 'p1',
  patientName: 'Aakar Sharma',
  patientPhone: '',
  date: date ?? DateTime.now().add(const Duration(days: 1)),
  time: '09:00',
  type: type,
  status: status,
  address: address,
  point: point,
  landmark: landmark,
  fee: 1500,
);

void main() {
  group('the directions link', () {
    test('goes to the pinned point when there is one', () {
      final uri = directionsUri(point: _here, address: 'ignored');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '27.691500,85.342000');
    });

    test('searches for the typed address when there is not', () {
      final uri = directionsUri(address: 'House 12, Baneshwor, Kathmandu');
      expect(
        uri.queryParameters['destination'],
        'House 12, Baneshwor, Kathmandu',
      );
      expect(uri.toString(), isNot(contains(' ')));
    });
  });

  group('a detected location', () {
    test('is pinnable when the fix is within 100 m', () {
      expect(_found(accuracy: 30).location.pinnablePoint, _here);
    });

    test('is not when the fix is rougher than that', () {
      expect(_found(accuracy: 900).location.pinnablePoint, isNull);
    });

    test('is not without a fix at all', () {
      const bare = DetectedLocation(city: 'Kathmandu');
      expect(bare.pinnablePoint, isNull);
    });
  });

  group('a visit from the API', () {
    SessionDto dto(Map<String, dynamic> extra) => SessionDto.fromJson({
      'id': 's1',
      'therapistId': 't1',
      'patientId': 'p1',
      'date': '2026-10-07T00:00:00',
      'time': '09:00',
      'type': 'HOME_VISIT',
      'status': 'SCHEDULED',
      'address': 'Baneshwor',
      'fee': 1500,
      ...extra,
    });

    test('carries its point and landmark', () {
      final s = dto({
        'latitude': 27.6915,
        'longitude': 85, // a whole number arrives as an int
        'landmark': 'Blue gate',
      }).toEntity();
      expect(s.point, const GeoPoint(27.6915, 85.0));
      expect(s.landmark, 'Blue gate');
    });

    test('has none when the patient only typed an address', () {
      expect(dto({}).toEntity().point, isNull);
    });

    test('the booking request leaves out what it does not have', () {
      final json = BookingPaymentRequestDto(
        therapistId: 't1',
        date: DateTime(2026, 10, 7),
        time: '09:00',
        address: 'Baneshwor',
        fee: 1500,
      ).toJson();
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('landmark'), isFalse);
    });
  });

  group('the visit address field', () {
    late TextEditingController controller;
    late List<GeoPoint?> pins;

    setUp(() {
      controller = TextEditingController();
      pins = [];
    });
    tearDown(() => controller.dispose());

    Future<_FakeLocation> pumpField(
      WidgetTester tester, {
      LocationLookup? result,
      bool pinnable = true,
    }) async {
      final service = _FakeLocation(result ?? _found());
      await pumpLocalized(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LocationAutocompleteField(
              controller: controller,
              detail: LocationDetail.address,
              pinnable: pinnable,
              onPinChanged: pins.add,
            ),
          ),
        ),
        overrides: [
          locationServiceProvider.overrideWithValue(service),
          // No network in tests: the pin card's map draws no tiles.
          mapTileLayerProvider.overrideWithValue(() => const SizedBox.shrink()),
        ],
      );
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      return service;
    }

    Future<void> useCurrent(WidgetTester tester) async {
      await tester.tap(find.text('Baneshwor, Kathmandu'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for a precise fix', (tester) async {
      final service = await pumpField(tester);
      expect(service.preciseCalls, [true]);
    });

    testWidgets('a city field still asks for an approximate one', (
      tester,
    ) async {
      final service = await pumpField(tester, pinnable: false);
      expect(service.preciseCalls, [false]);
    });

    testWidgets('choosing the current location pins it, and says so', (
      tester,
    ) async {
      await pumpField(tester);
      await useCurrent(tester);

      expect(pins, [_here]);
      expect(find.text('Pinned to your current location'), findsOneWidget);
      expect(
        find.text('Your therapist sees this pin once the visit is booked.'),
        findsOneWidget,
      );
    });

    testWidgets('adding house details keeps the pin', (tester) async {
      await pumpField(tester);
      await useCurrent(tester);

      await tester.enterText(
        find.byType(TextFormField),
        'House 12, Baneshwor, Kathmandu',
      );
      await tester.pumpAndSettle();

      expect(pins, [_here]);
      expect(find.text('Pinned to your current location'), findsOneWidget);
    });

    testWidgets('replacing the address drops it', (tester) async {
      await pumpField(tester);
      await useCurrent(tester);

      await tester.enterText(find.byType(TextFormField), 'Jhamsikhel, Lalitpur');
      await tester.pumpAndSettle();

      expect(pins, [_here, null]);
      expect(find.text('Pinned to your current location'), findsNothing);
    });

    testWidgets('Remove drops it and leaves the address', (tester) async {
      await pumpField(tester);
      await useCurrent(tester);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(pins, [_here, null]);
      expect(controller.text, 'Baneshwor, Kathmandu');
      expect(find.text('Pinned to your current location'), findsNothing);
    });

    testWidgets('a rough fix is not pinned, and the patient is told why', (
      tester,
    ) async {
      await pumpField(tester, result: _found(accuracy: 900));
      await useCurrent(tester);

      expect(pins, isEmpty);
      expect(controller.text, 'Baneshwor, Kathmandu');
      expect(find.textContaining('too approximate to pin'), findsOneWidget);
    });

    testWidgets('a field that is not pinnable never pins', (tester) async {
      await pumpField(tester, pinnable: false);
      await useCurrent(tester);

      expect(pins, isEmpty);
      expect(find.text('Pinned to your current location'), findsNothing);
    });
  });

  group('Navigate', () {
    test('is offered only for a home visit that is still on', () {
      expect(canNavigateTo(_visit()), isTrue);
      expect(canNavigateTo(_visit(status: SessionStatus.inProgress)), isTrue);
      expect(canNavigateTo(_visit(type: 'CLINIC')), isFalse);
      expect(canNavigateTo(_visit(status: SessionStatus.cancelled)), isFalse);
      expect(canNavigateTo(_visit(status: SessionStatus.completed)), isFalse);
      expect(canNavigateTo(_visit(address: '  ')), isFalse);
    });

    test('not for a visit on a day already gone, but still for today', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      expect(canNavigateTo(_visit(date: yesterday)), isFalse);
      expect(
        canNavigateTo(_visit(date: DateTime(now.year, now.month, now.day))),
        isTrue,
      );
    });

    Future<List<Uri>> pumpButton(
      WidgetTester tester,
      Session session, {
      bool opens = true,
    }) async {
      final opened = <Uri>[];
      await pumpLocalized(
        tester,
        Scaffold(
          body: Column(
            children: [
              NavigateButton(session: session),
              VisitLandmark(session: session),
            ],
          ),
        ),
        overrides: [
          urlOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return opens;
          }),
        ],
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('opens directions to the pinned point', (tester) async {
      final opened = await pumpButton(tester, _visit(point: _here));

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(opened.single.queryParameters['destination'], _here.query);
    });

    testWidgets('falls back to the typed address', (tester) async {
      final opened = await pumpButton(tester, _visit());

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(
        opened.single.queryParameters['destination'],
        'House 12, Baneshwor, Kathmandu',
      );
    });

    testWidgets('says so when no app can open it', (tester) async {
      await pumpButton(tester, _visit(), opens: false);

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(
        find.text('No maps app could open these directions.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the landmark under the visit', (tester) async {
      await pumpButton(tester, _visit(landmark: 'Blue gate opposite the temple'));
      expect(
        find.text('Landmark: Blue gate opposite the temple'),
        findsOneWidget,
      );
    });

    testWidgets('and nothing when there is none', (tester) async {
      await pumpButton(tester, _visit(landmark: '  '));
      expect(find.textContaining('Landmark'), findsNothing);
    });
  });
}
