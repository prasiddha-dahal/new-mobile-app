import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';

/// A geocoder describes a place in its own administrative vocabulary --
/// "Kathmandu Metropolitan City", "Lalitpur Sub-Metropolitan City" -- and the
/// therapist search matches `city` as plain text against what the platform
/// stores, which is "Kathmandu". Getting from one to the other is the one
/// piece of the location feature that is guesswork, so it is tested without a
/// device.
void main() {
  group('the city', () {
    test('snaps a municipality label to the city the platform serves', () {
      final place = describePlace(locality: 'Kathmandu Metropolitan City');
      expect(place!.city, 'Kathmandu');
    });

    test('handles each supported city', () {
      for (final city in supportedCities) {
        expect(describePlace(locality: city)!.city, city);
      }
    });

    test('finds the city in the district when the locality is a town', () {
      // Bharatpur is a municipality in Chitwan; Chitwan is what is served.
      final place = describePlace(
        locality: 'Bharatpur Metropolitan City',
        subAdministrativeArea: 'Chitwan',
      );
      expect(place!.city, 'Chitwan');
    });

    test('keeps a place the platform does not list, minus the suffix', () {
      final place = describePlace(locality: 'Dharan Sub-Metropolitan City');
      expect(place!.city, 'Dharan');
    });

    test('reads the district when there is no locality', () {
      expect(describePlace(subAdministrativeArea: 'Lalitpur')!.city, 'Lalitpur');
    });

    test('is null when the geocoder named nothing', () {
      expect(describePlace(), isNull);
      expect(describePlace(locality: '  ', subLocality: 'Baneshwor'), isNull);
    });
  });

  group('the area', () {
    test('joins the street and neighbourhood ahead of the city', () {
      final place = describePlace(
        thoroughfare: 'Shankhamul Road',
        subLocality: 'Baneshwor',
        locality: 'Kathmandu',
      )!;
      expect(place.area, 'Shankhamul Road, Baneshwor');
      expect(place.addressLabel, 'Shankhamul Road, Baneshwor, Kathmandu');
      expect(place.cityLabel, 'Kathmandu');
    });

    test('falls back to the city alone for an address', () {
      final place = describePlace(locality: 'Pokhara')!;
      expect(place.area, isNull);
      expect(place.addressLabel, 'Pokhara');
    });

    test('does not repeat the city as its own neighbourhood', () {
      final place = describePlace(
        subLocality: 'Kathmandu',
        locality: 'Kathmandu',
      )!;
      expect(place.addressLabel, 'Kathmandu');
    });

    test('drops a Plus Code and a bare house number', () {
      final place = describePlace(
        thoroughfare: '7J3F+JW',
        subLocality: '42',
        locality: 'Lalitpur',
      )!;
      expect(place.area, isNull);
    });

    test('does not repeat a part that appears twice', () {
      final place = describePlace(
        thoroughfare: 'Baneshwor',
        subLocality: 'baneshwor',
        locality: 'Kathmandu',
      )!;
      expect(place.addressLabel, 'Baneshwor, Kathmandu');
    });
  });

  test('two descriptions of one place are equal', () {
    expect(
      describePlace(locality: 'Kathmandu', subLocality: 'Baneshwor'),
      describePlace(locality: 'Kathmandu Metropolitan City', subLocality: 'Baneshwor'),
    );
  });
}
