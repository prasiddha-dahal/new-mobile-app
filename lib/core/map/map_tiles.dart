import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../location/geo_point.dart';

/// Where the map's picture comes from.
///
/// OpenStreetMap's public tile server for now. Its usage policy allows light
/// use by an app that names itself (the User-Agent below) and credits the
/// map (the attribution below), and forbids heavy or bulk use -- so before
/// real traffic the tiles move to our own server. That move is one value:
/// set `MAP_TILE_URL` in `.env` to the self-hosted template.
class MapTiles {
  MapTiles._();

  static const String osmTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Identifies the app to the tile server, as OSM's policy requires.
  static const String userAgentPackageName =
      'com.sahayatri.sahayatri_care_connect';

  static String get urlTemplate {
    final fromEnv = dotenv.isInitialized
        ? dotenv.maybeGet('MAP_TILE_URL')?.trim()
        : null;
    return (fromEnv == null || fromEnv.isEmpty) ? osmTemplate : fromEnv;
  }

  /// OSM tiles go to zoom 19.
  static const double maxZoom = 19;
}

/// Builds the tile layer. Overridden in tests, which have no network and
/// should not try.
final mapTileLayerProvider = Provider<Widget Function()>(
  (_) =>
      () => TileLayer(
        urlTemplate: MapTiles.urlTemplate,
        userAgentPackageName: MapTiles.userAgentPackageName,
        maxNativeZoom: MapTiles.maxZoom.toInt(),
      ),
);

/// "© OpenStreetMap contributors", which the licence requires on every map.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}

LatLng toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);
GeoPoint toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);

/// The same box the API accepts a pinned visit in (app/models/visit_location.py),
/// so a map cannot be dragged somewhere the booking would then refuse.
final nepalBounds = LatLngBounds(
  const LatLng(26.3, 80.0),
  const LatLng(30.5, 88.3),
);

/// Kathmandu, for a map that has nothing better to open on.
const kathmandu = GeoPoint(27.7172, 85.3240);
