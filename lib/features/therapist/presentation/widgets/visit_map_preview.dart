import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/map/map_tiles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../patient/domain/entities/session.dart';

/// A small, still map of where a home visit is, on the therapist's card.
///
/// Only for a visit the patient pinned: a typed address has no point to draw.
/// It does not pan or zoom -- a map inside a scrolling list fights the
/// scroll -- and a tap hands over to [onOpen], which opens directions.
class VisitMapPreview extends ConsumerWidget {
  const VisitMapPreview({super.key, required this.session, this.onOpen});

  final Session session;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = session.point;
    if (point == null) return const SizedBox.shrink();
    final tiles = ref.watch(mapTileLayerProvider);

    return Semantics(
      button: onOpen != null,
      label: context.l10n.mapVisitPreview,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        child: SizedBox(
          height: 140,
          child: Stack(
            children: [
              // Keyed by the point: flutter_map reads initialCenter once, so a
              // reused card kept showing the previous visit's place.
              FlutterMap(
                key: ValueKey(point.query),
                options: MapOptions(
                  initialCenter: toLatLng(point),
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  tiles(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: toLatLng(point),
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 36,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  // The tap layer sits under the attribution, so the credit
                  // button stays reachable (a full overlay above the map used
                  // to swallow it). The map's own onTap does not fire with
                  // interaction switched off.
                  if (onOpen != null)
                    SizedBox.expand(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: onOpen),
                      ),
                    ),
                  const MapAttribution(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
