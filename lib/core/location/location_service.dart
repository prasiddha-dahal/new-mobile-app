import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'geo_point.dart';
import 'place_description.dart';

/// What came of trying to find the device.
///
/// A sealed result rather than an exception for the first three, because
/// "the person said no" and "location is switched off" are ordinary outcomes
/// that the UI words differently -- not failures to be caught and logged.
sealed class LocationLookup {
  const LocationLookup();
}

class LocationFound extends LocationLookup {
  const LocationFound(this.location);
  final DetectedLocation location;
}

/// The person declined the permission prompt, or declined it for good.
class LocationDenied extends LocationLookup {
  const LocationDenied();
}

/// The device's location switch is off.
class LocationServicesOff extends LocationLookup {
  const LocationServicesOff();
}

/// Anything else: no fix in time, no geocoder on the device, a name that
/// could not be worked out. Silent in the UI -- a suggestion that does not
/// appear is not worth an error.
class LocationFailed extends LocationLookup {
  const LocationFailed();
}

/// The seam between the location field and the platform, so a test can say
/// where the device is without a GPS.
abstract class LocationService {
  /// [precise] asks for a fresh, high-accuracy fix -- slower, and it wakes the
  /// GPS -- for a field whose answer a therapist will navigate to. Without it
  /// the lookup is approximate, which is all a city needs.
  Future<LocationLookup> detect({bool precise = false});

  /// Names an arbitrary point -- where the map's pin was dropped -- the way
  /// [detect] names the device's own. Null when the geocoder cannot.
  Future<DetectedLocation?> describe(GeoPoint point);
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  /// For a city or a neighbourhood name: low accuracy is faster, uses the
  /// network rather than the GPS chip, and asks for less.
  static const _approximate = LocationSettings(
    accuracy: LocationAccuracy.low,
    timeLimit: Duration(seconds: 10),
  );

  /// For a point a therapist navigates to.
  static const _precise = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 20),
  );

  @override
  Future<DetectedLocation?> describe(GeoPoint point) async {
    try {
      final place = await _name(point);
      return place?.withFix(point, 0);
    } catch (e) {
      debugPrint('[location] could not name the point: $e');
      return null;
    }
  }

  @override
  Future<LocationLookup> detect({bool precise = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServicesOff();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationDenied();
      }

      // The last known fix first when a city is all that is wanted: it is
      // instant, and a city does not change between the last fix and now. Not
      // available on every platform, so a failure just means a fresh one. A
      // precise lookup skips it -- an old or network-only fix is exactly what
      // would send a therapist to the wrong door.
      Position? position;
      if (!precise) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: precise ? _precise : _approximate,
      );
      final fix = GeoPoint(position.latitude, position.longitude);

      final place = await _name(fix);
      if (place != null) {
        return LocationFound(place.withFix(fix, position.accuracy));
      }
      debugPrint('[location] the geocoder returned no usable place');
      return const LocationFailed();
    } catch (e) {
      // Silent in the UI by design, but a field that never suggests anything
      // is baffling to debug without knowing which step gave up.
      debugPrint('[location] lookup failed: $e');
      return const LocationFailed();
    }
  }
}

extension on DeviceLocationService {
  /// English, whatever the app's language: the server stores `city` as
  /// "Kathmandu", and a Devanagari name would match nothing it holds.
  Future<DetectedLocation?> _name(GeoPoint point) async {
    final marks = await Geocoding().placemarkFromCoordinates(
      point.latitude,
      point.longitude,
      locale: const Locale('en'),
    );
    for (final mark in marks) {
      final place = describePlace(
        thoroughfare: mark.thoroughfare ?? mark.street,
        subLocality: mark.subLocality,
        locality: mark.locality,
        subAdministrativeArea: mark.subAdministrativeArea,
        administrativeArea: mark.administrativeArea,
      );
      if (place != null) return place;
    }
    return null;
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const DeviceLocationService(),
);

class LocationSuggestionState {
  const LocationSuggestionState({
    this.result,
    this.detecting = false,
    this.at,
    this.precise = false,
  });

  /// The last answer, null before the first attempt.
  final LocationLookup? result;
  final bool detecting;
  final DateTime? at;

  /// Whether [result] came from a precise lookup.
  final bool precise;

  DetectedLocation? get location =>
      result is LocationFound ? (result as LocationFound).location : null;
}

/// Holds the device's location for every location field on screen.
///
/// One lookup serves them all: the fields on a form share an answer rather
/// than each asking the platform, and the permission prompt appears once.
/// Detection runs when a field is opened -- not at app start, so nobody is
/// asked for location before they are doing something that uses it.
class LocationSuggestionNotifier extends StateNotifier<LocationSuggestionState> {
  LocationSuggestionNotifier(this._service)
    : super(const LocationSuggestionState());

  final LocationService _service;

  /// How long a found location is trusted before a field opening it asks
  /// again. A person can have moved; a city rarely changes inside a session.
  static const freshFor = Duration(minutes: 10);

  /// [precise] is for a field that can pin the point: an approximate answer
  /// already held is not good enough for it and is looked up again, while a
  /// precise one serves every field.
  Future<void> ensureDetected({bool precise = false}) async {
    if (state.detecting) return;
    final at = state.at;
    if (state.location != null &&
        at != null &&
        DateTime.now().difference(at) < freshFor &&
        (state.precise || !precise)) {
      return;
    }

    state = LocationSuggestionState(
      result: state.result,
      detecting: true,
      at: state.at,
      precise: state.precise,
    );
    final result = await _service.detect(precise: precise);
    if (!mounted) return;
    state = LocationSuggestionState(
      result: result,
      at: DateTime.now(),
      precise: precise,
    );
  }
}

final locationSuggestionProvider =
    StateNotifierProvider<LocationSuggestionNotifier, LocationSuggestionState>(
      (ref) => LocationSuggestionNotifier(ref.watch(locationServiceProvider)),
    );
