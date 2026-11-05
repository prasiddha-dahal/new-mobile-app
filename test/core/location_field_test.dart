import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/location/geo_point.dart';
import 'package:sahayatri_care_connect/core/location/location_service.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';
import 'package:sahayatri_care_connect/core/widgets/location_autocomplete_field.dart';

import '../l10n_harness.dart';

/// "When a user opens the location field, the app should detect where they are
/// and offer it as a suggestion."
///
/// A fake service stands in for the GPS: what matters here is when the lookup
/// starts, what the field does with each possible answer, and that nothing is
/// ever written into the box without a tap.
class _FakeLocation implements LocationService {
  _FakeLocation(this.result);

  LocationLookup result;
  int calls = 0;

  /// When set, `detect` waits for it -- to look at the in-between state.
  Completer<void>? gate;

  @override
  Future<DetectedLocation?> describe(GeoPoint point) async => null;

  @override
  Future<LocationLookup> detect({bool precise = false}) async {
    calls++;
    if (gate != null) await gate!.future;
    return result;
  }
}

const _baneshwor = DetectedLocation(city: 'Kathmandu', area: 'Baneshwor');

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pumpField(
    WidgetTester tester,
    _FakeLocation service, {
    LocationDetail detail = LocationDetail.city,
    Locale locale = const Locale('en'),
    List<String>? places,
  }) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: LocationAutocompleteField(
            controller: controller,
            detail: detail,
            hint: 'City or area',
            places: places,
          ),
        ),
      ),
      locale: locale,
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
  }

  group('opening the field', () {
    testWidgets('starts the lookup, and only then', (tester) async {
      final service = _FakeLocation(const LocationFound(_baneshwor));
      await pumpField(tester, service);

      expect(service.calls, 0, reason: 'nobody is asked before they use a field');

      await open(tester);
      expect(service.calls, 1);
    });

    testWidgets('offers the detected city as a suggestion', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationFound(_baneshwor)));
      await open(tester);

      expect(find.text('Kathmandu'), findsOneWidget);
      expect(find.text('Your current location'), findsOneWidget);
    });

    testWidgets('an address field is offered the neighbourhood too', (
      tester,
    ) async {
      await pumpField(
        tester,
        _FakeLocation(const LocationFound(_baneshwor)),
        detail: LocationDetail.address,
      );
      await open(tester);

      expect(find.text('Baneshwor, Kathmandu'), findsOneWidget);
    });

    testWidgets('tapping the suggestion fills the field', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationFound(_baneshwor)));
      await open(tester);

      await tester.tap(find.text('Kathmandu'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Kathmandu');
    });

    testWidgets('and then has nothing left to suggest', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationFound(_baneshwor)));
      await open(tester);
      await tester.tap(find.text('Your current location'));
      await tester.pumpAndSettle();

      expect(find.text('Your current location'), findsNothing);
    });

    testWidgets('never writes into the box on its own', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationFound(_baneshwor)));
      await open(tester);

      expect(
        controller.text,
        isEmpty,
        reason: 'a wrong guess typed into someone\'s address for them is worse '
            'than an empty field',
      );
    });
  });

  group('while it works, and when it cannot', () {
    testWidgets('says it is looking, then shows the answer', (tester) async {
      final service = _FakeLocation(const LocationFound(_baneshwor))
        ..gate = Completer<void>();
      await pumpField(tester, service);

      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.pump();
      expect(find.text('Finding your location…'), findsOneWidget);
      expect(find.text('Kathmandu'), findsNothing);

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Finding your location…'), findsNothing);
      expect(find.text('Kathmandu'), findsOneWidget);
    });

    testWidgets('a refused permission is explained, not silent', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationDenied()));
      await open(tester);

      expect(
        find.text('Allow location access to see your area here.'),
        findsOneWidget,
      );
      expect(find.byType(InkWell), findsNothing, reason: 'it is a note, not a button');
    });

    testWidgets('a device with location off says that instead', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationServicesOff()));
      await open(tester);

      expect(find.text('Turn on location to see your area here.'), findsOneWidget);
    });

    testWidgets('a lookup that simply fails shows nothing at all', (
      tester,
    ) async {
      await pumpField(tester, _FakeLocation(const LocationFailed()));
      await open(tester);

      expect(find.byType(InkWell), findsNothing);
      expect(find.textContaining('location'), findsNothing);
    });

    testWidgets('the field still takes typing when location is refused', (
      tester,
    ) async {
      await pumpField(tester, _FakeLocation(const LocationDenied()));
      await open(tester);

      await tester.enterText(find.byType(TextFormField), 'Patan');
      expect(controller.text, 'Patan');
    });
  });

  group('typing', () {
    testWidgets('offers the supported cities that match', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationFailed()));
      await open(tester);

      await tester.enterText(find.byType(TextFormField), 'la');
      await tester.pumpAndSettle();

      expect(find.text('Lalitpur'), findsOneWidget);
      expect(find.text('Kathmandu'), findsNothing);
    });

    testWidgets('picking a city completes the field', (tester) async {
      await pumpField(tester, _FakeLocation(const LocationFailed()));
      await open(tester);
      await tester.enterText(find.byType(TextFormField), 'bha');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bhaktapur'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Bhaktapur');
    });

    testWidgets('narrows the current-location suggestion like any other', (
      tester,
    ) async {
      await pumpField(tester, _FakeLocation(const LocationFound(_baneshwor)));
      await open(tester);

      await tester.enterText(find.byType(TextFormField), 'pok');
      await tester.pumpAndSettle();

      expect(find.text('Your current location'), findsNothing);
      expect(find.text('Pokhara'), findsOneWidget);
    });

    testWidgets('an address field has no city list to complete from', (
      tester,
    ) async {
      await pumpField(
        tester,
        _FakeLocation(const LocationFailed()),
        detail: LocationDetail.address,
      );
      await open(tester);

      await tester.enterText(find.byType(TextFormField), 'la');
      await tester.pumpAndSettle();

      expect(find.text('Lalitpur'), findsNothing);
    });

    testWidgets('a field already holding the answer suggests nothing', (
      tester,
    ) async {
      controller.text = 'Kathmandu';
      await pumpField(tester, _FakeLocation(const LocationFound(_baneshwor)));
      await open(tester);

      expect(find.text('Your current location'), findsNothing);
    });
  });

  group('asking again', () {
    testWidgets('a second field on the same form reuses the answer', (
      tester,
    ) async {
      final service = _FakeLocation(const LocationFound(_baneshwor));
      final second = TextEditingController();
      addTearDown(second.dispose);
      await pumpLocalized(
        tester,
        Scaffold(
          body: Column(
            children: [
              LocationAutocompleteField(controller: controller),
              LocationAutocompleteField(
                controller: second,
                detail: LocationDetail.address,
              ),
            ],
          ),
        ),
        overrides: [locationServiceProvider.overrideWithValue(service)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextFormField).last);
      await tester.pumpAndSettle();

      expect(service.calls, 1, reason: 'one prompt, one lookup, many fields');
      expect(find.text('Baneshwor, Kathmandu'), findsOneWidget);
    });

    testWidgets('a refusal is asked about again the next time it is opened', (
      tester,
    ) async {
      // Permission can be granted in Settings between two taps.
      final service = _FakeLocation(const LocationDenied());
      await pumpField(tester, service);
      await open(tester);
      expect(service.calls, 1);

      service.result = const LocationFound(_baneshwor);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await open(tester);

      expect(service.calls, 2);
      expect(find.text('Kathmandu'), findsOneWidget);
    });
  });

  testWidgets('reads in Nepali', (tester) async {
    await pumpField(
      tester,
      _FakeLocation(const LocationFound(_baneshwor)),
      locale: const Locale('ne'),
    );
    await open(tester);

    expect(find.text('Your current location'), findsNothing);
    expect(find.text('तपाईंको हालको स्थान'), findsOneWidget);
  });
}
