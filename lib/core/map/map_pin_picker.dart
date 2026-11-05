import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/l10n.dart';
import '../location/geo_point.dart';
import '../location/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Where the patient put the pin, and what the place is called if the
/// geocoder knew.
class MapPick {
  const MapPick({required this.point, this.label});

  final GeoPoint point;

  /// "Baneshwor, Kathmandu", or null when the point could not be named.
  final String? label;
}

/// Opens the full-screen pin picker. Null if the patient backs out.
Future<MapPick?> showMapPinPicker(BuildContext context, {GeoPoint? start}) {
  return Navigator.of(context, rootNavigator: true).push<MapPick>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MapPinPickerScreen(start: start),
    ),
  );
}

LatLng _toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);
GeoPoint _toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);

/// Kathmandu fallback when we have nothing better.
const _kathmandu = GeoPoint(27.7172, 85.3240);

/// Rough Nepal bounding box.
final _nepalBounds = LatLngBounds(
  southwest: const LatLng(26.3, 80.0),
  northeast: const LatLng(30.5, 88.3),
);

/// Drag the map until the pin sits on the door.
class MapPinPickerScreen extends ConsumerStatefulWidget {
  const MapPinPickerScreen({super.key, this.start});

  final GeoPoint? start;

  @override
  ConsumerState<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends ConsumerState<MapPinPickerScreen> {
  GoogleMapController? _map;
  late GeoPoint _center = widget.start ?? _kathmandu;
  GeoPoint? _me;
  String? _label;

  bool _naming = false;
  bool _locating = false;
  bool _confirming = false;

  Timer? _debounce;

  /// Patient has already dragged; a late GPS fix only shows the blue dot.
  bool _movedByHand = false;

  @override
  void initState() {
    super.initState();

    if (widget.start == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLocation());
    } else {
      _nameCenter();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map?.dispose();
    super.dispose();
  }

  /// Looks for the patient, and asks them to turn location on when that fails.
  Future<void> _startLocation() async {
    final found = await _goToMe();

    if (!found && mounted) {
      final localizations = AppLocalizations.of(context);

      if (localizations != null) {
        await _askToTurnOnLocation(localizations);
      }
    }
  }

  /// Returns true when a position was found.
  Future<bool> _goToMe() async {
    setState(() => _locating = true);

    final result = await ref
        .read(locationServiceProvider)
        .detect(precise: true);

    if (!mounted) return false;

    setState(() => _locating = false);

    final point = result is LocationFound ? result.location.point : null;

    if (point == null) {
      _nameCenter();
      return false;
    }

    if (_movedByHand) {
      setState(() => _me = point);
      return true;
    }

    setState(() {
      _me = point;
      _center = point;
    });

    await _map?.animateCamera(CameraUpdate.newLatLngZoom(_toLatLng(point), 17));

    _nameCenter();
    return true;
  }

  /// The patient's location is off or not allowed.
  Future<void> _askToTurnOnLocation(AppLocalizations l10n) async {
    final text = AppTypography.textTheme;

    final turnOn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        icon: const Icon(
          Icons.location_searching_rounded,
          color: AppColors.pine,
          size: 32,
        ),
        title: Text(l10n.turnOnLocation),
        titleTextStyle: text.titleLarge!.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        content: Text(l10n.askToTurnOnLocation),
        contentTextStyle: text.bodyMedium!.copyWith(
          height: 1.45,
          letterSpacing: 0,
          color: AppColors.inkMid,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMid,
              textStyle: text.titleSmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(l10n.notNow),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pine,
              textStyle: text.titleSmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (turnOn != true || !mounted) return;

    _movedByHand = false;

    final found = await _goToMe();

    if (!found && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.locationOffSnackbarMessage)),
        );
    }
  }

  void _onCameraMove(CameraPosition position) {
    _center = _toGeoPoint(position.target);

    if (!_naming) setState(() => _naming = true);
  }

  void _onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _nameCenter);
  }

  Future<void> _nameCenter() async {
    final asked = _center;

    setState(() => _naming = true);

    final place = await ref.read(locationServiceProvider).describe(asked);

    if (!mounted || asked != _center) return;

    setState(() {
      _naming = false;
      _label = place?.addressLabel;
    });
  }

  /// Closes with the chosen point and its name.
  Future<void> _use() async {
    setState(() => _confirming = true);

    _debounce?.cancel();

    if (_naming || _label == null) {
      await _nameCenter();
    }

    if (!mounted) return;

    setState(() => _confirming = false);

    Navigator.of(context).pop(MapPick(point: _center, label: _label));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _toLatLng(_center),
              zoom: widget.start == null ? 13 : 17,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(6, 20),
            cameraTargetBounds: CameraTargetBounds(_nepalBounds),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (c) => _map = c,
            onCameraMove: (pos) {
              _movedByHand = true;
              _onCameraMove(pos);
            },
            onCameraIdle: _onCameraIdle,
            markers: {
              if (_me != null)
                Marker(
                  markerId: const MarkerId('me'),
                  position: _toLatLng(_me!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                  infoWindow: const InfoWindow(title: ''),
                  anchor: const Offset(0.5, 0.5),
                ),
            },
          ),

          // Fixed centre pin.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),

          // Top bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.close,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          boxShadow: _softShadow,
                        ),
                        child: Text(
                          l10n.mapPickTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // My-location button with explanatory helper text.
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    boxShadow: _softShadow,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        l10n.locationTooltip,
                        style: text.bodySmall!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),
                _RoundButton(
                  icon: Icons.my_location_rounded,
                  tooltip: l10n.mapMyLocation,
                  loading: _locating,
                  onTap: _locating
                      ? null
                      : () {
                          _movedByHand = false;
                          _startLocation();
                        },
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom location details and confirmation button.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          AppColors.pinePale.withAlpha(150),
                          Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.place_outlined,
                        size: 22,
                        color: AppColors.pine,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _naming
                                ? l10n.mapPickNaming
                                : (_label ?? l10n.mapPickUnnamed),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall!.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.mapPickHint,
                            style: text.bodySmall!.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                              color: AppColors.inkMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_naming) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.pine,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _confirming ? null : _use,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pine,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.pine.withAlpha(90),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: _confirming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.mapPickUse),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _softShadow = [
  BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 2)),
];

/// A white circle with an icon, floated over the map.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.pine,
                      ),
                    )
                  : Icon(icon, size: 24, color: AppColors.pine),
            ),
          ),
        ),
      ),
    );
  }
}
