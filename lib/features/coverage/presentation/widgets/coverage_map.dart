import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/coverage_models.dart';

/// The chosen area and the clinics around it, on an OpenStreetMap map.
///
/// Therapists are not pinned: the point a therapist works from is often their
/// home, and the API does not send it. The list under the map answers who
/// covers the area; the map answers where it is and which clinics are near.
class CoverageMap extends ConsumerWidget {
  const CoverageMap({
    super.key,
    required this.area,
    required this.clinics,
    this.onClinic,
  });

  final ServiceAreaDto? area;
  final List<CoverageClinicDto> clinics;
  final ValueChanged<CoverageClinicDto>? onClinic;

  /// Clinics further than this from the area still get a pin, but the map
  /// does not zoom out to show them (Pokhara is not "near" Baneshwor).
  static const double nearKm = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final centre = _point(area?.latitude, area?.longitude);
    final pinned = [
      for (final c in clinics)
        if (_point(c.latitude, c.longitude) != null) c,
    ];

    if (centre == null && pinned.isEmpty) return const _NoPins();

    final focus = <LatLng>[
      ?centre,
      for (final c in pinned)
        if (centre == null || (c.distanceKm ?? double.infinity) <= nearKm)
          _point(c.latitude, c.longitude)!,
    ];
    final tiles = ref.watch(mapTileLayerProvider);

    return Semantics(
      label: l10n.coverageMapLabel(area?.name ?? l10n.coverageYourAreaFallback),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            // Keyed by the area: flutter_map reads the camera once, so
            // switching areas would otherwise keep the old view.
            key: ValueKey('coverage-${area?.id}-${focus.length}'),
            options: MapOptions(
              initialCenter: focus.length == 1 ? focus.single : focus.first,
              initialZoom: 13,
              initialCameraFit: focus.length > 1
                  ? CameraFit.coordinates(
                      coordinates: focus,
                      padding: const EdgeInsets.all(40),
                      maxZoom: 15,
                    )
                  : null,
              minZoom: 7,
              maxZoom: MapTiles.maxZoom,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: nepalBounds,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              tiles(),
              MarkerLayer(
                markers: [
                  for (final c in pinned)
                    Marker(
                      point: _point(c.latitude, c.longitude)!,
                      width: 36,
                      height: 36,
                      child: _ClinicPin(
                        label: l10n.coverageMapClinicPin(c.name),
                        onTap: onClinic == null ? null : () => onClinic!(c),
                      ),
                    ),
                  if (centre != null)
                    Marker(
                      point: centre,
                      width: 160,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: _AreaPin(name: area?.name ?? ''),
                    ),
                ],
              ),
              const MapAttribution(),
            ],
          ),
        ),
      ),
    );
  }

  static LatLng? _point(double? lat, double? lng) =>
      lat == null || lng == null ? null : LatLng(lat, lng);
}

/// The area's name over a dot on its centre.
class _AreaPin extends StatelessWidget {
  const _AreaPin({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pine,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.card,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.pine,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.card, width: 3),
          ),
        ),
      ],
    );
  }
}

class _ClinicPin extends StatelessWidget {
  const _ClinicPin({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pine, width: 2),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.local_hospital,
            size: 18,
            color: AppColors.pine,
          ),
        ),
      ),
    );
  }
}

class _NoPins extends StatelessWidget {
  const _NoPins();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.pinePale,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: AppColors.pine),
          const SizedBox(height: 6),
          Text(
            context.l10n.coverageMapNoPins,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMid),
          ),
        ],
      ),
    );
  }
}
