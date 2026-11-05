import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// What a marker stands for. Decides its colour and the legend entry.
///
/// [area] is the centre of the service area the patient chose: a red pin, no
/// legend entry, and nothing to open when tapped.
enum PlaceKind { therapist, clinic, area }

/// One pin on the map.
///
/// Plain doubles rather than a LatLng, so call sites that also import
/// `latlong2` (the pin picker still uses flutter_map) never see two different
/// `LatLng` types.
class MapPlace {
  const MapPlace({
    required this.id,
    required this.kind,
    required this.title,
    required this.lat,
    required this.lng,
    this.subtitle,
  });

  final String id;
  final PlaceKind kind;
  final String title;
  final String? subtitle;
  final double lat;
  final double lng;
}

/// A Google Map showing [places] as coloured markers.
///
/// Therapists are green and clinics are blue. The camera fits every marker
/// when the map opens and whenever the list changes. Tapping a marker shows
/// its name; tapping the name calls [onPlaceTap].
///
/// Safe to drop inside a scrolling list: the map claims drags that start on
/// it, so panning the map does not scroll the page.
class PlacesMap extends StatefulWidget {
  const PlacesMap({
    super.key,
    required this.places,
    this.onPlaceTap,
    this.height = 240,
    this.showMyLocation = false,
  });

  final List<MapPlace> places;
  final ValueChanged<MapPlace>? onPlaceTap;
  final double height;

  /// Shows the blue "you are here" dot. Needs the location permission to
  /// have been granted already; this widget does not ask for it.
  final bool showMyLocation;

  /// Where the map opens before it has any markers to fit.
  static const LatLng _kathmandu = LatLng(27.7172, 85.3240);

  @override
  State<PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<PlacesMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant PlacesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.places.map((p) => '${p.kind}${p.id}').toList();
    final after = widget.places.map((p) => '${p.kind}${p.id}').toList();
    if (!listEquals(before, after)) _fit();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Set<Marker> _markers() {
    return {
      for (final p in widget.places)
        Marker(
          markerId: MarkerId('${p.kind.name}:${p.id}'),
          position: LatLng(p.lat, p.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(switch (p.kind) {
            PlaceKind.clinic => BitmapDescriptor.hueAzure,
            PlaceKind.therapist => BitmapDescriptor.hueGreen,
            PlaceKind.area => BitmapDescriptor.hueRed,
          }),
          infoWindow: InfoWindow(
            title: p.title,
            snippet: p.subtitle,
            onTap: () => widget.onPlaceTap?.call(p),
          ),
        ),
    };
  }

  /// Moves the camera so every marker is in view.
  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null || widget.places.isEmpty) return;

    final points = [for (final p in widget.places) LatLng(p.lat, p.lng)];

    if (points.length == 1) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        points.map((p) => p.latitude).reduce(math.min),
        points.map((p) => p.longitude).reduce(math.min),
      ),
      northeast: LatLng(
        points.map((p) => p.latitude).reduce(math.max),
        points.map((p) => p.longitude).reduce(math.max),
      ),
    );

    Future<void> go() =>
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));

    try {
      await go();
    } catch (_) {
      // The map has not been laid out yet; try once more a moment later.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      try {
        await go();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTherapists = widget.places.any((p) => p.kind == PlaceKind.therapist);
    final hasClinics = widget.places.any((p) => p.kind == PlaceKind.clinic);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: PlacesMap._kathmandu,
                zoom: 11,
              ),
              markers: _markers(),
              onMapCreated: (c) {
                _controller = c;
                _fit();
              },
              myLocationEnabled: widget.showMyLocation,
              myLocationButtonEnabled: widget.showMyLocation,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              // Let the map take drags that start on it, so it pans inside
              // a scrolling page instead of scrolling the page.
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
            if (hasTherapists || hasClinics)
              Positioned(
                top: 8,
                left: 8,
                child: _Legend(
                  therapists: hasTherapists,
                  clinics: hasClinics,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.therapists, required this.clinics});

  final bool therapists;
  final bool clinics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget entry(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (therapists) entry(AppColors.pine, l10n.coverageTabTherapists),
          if (therapists && clinics) const SizedBox(width: 12),
          if (clinics) entry(const Color(0xFF1A73E8), l10n.coverageTabClinics),
        ],
      ),
    );
  }
}