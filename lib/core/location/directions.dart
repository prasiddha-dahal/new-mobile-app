import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'geo_point.dart';

/// A Google Maps directions link to a home visit.
///
/// The universal `maps/dir/?api=1` form: it opens the Google Maps app when it
/// is installed and the browser when it is not, needs no API key, and costs
/// nothing. A pinned [point] is exact; without one the typed [address] is sent
/// as a search, which is the best a text address can do.
Uri directionsUri({GeoPoint? point, required String address}) => Uri.https(
  'www.google.com',
  '/maps/dir/',
  {'api': '1', 'destination': point?.query ?? address},
);

/// Opens [uri] outside the app. False when nothing on the device can.
typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Overridden in tests, which cannot leave the app.
final urlOpenerProvider = Provider<UrlOpener>((_) => _openExternally);
