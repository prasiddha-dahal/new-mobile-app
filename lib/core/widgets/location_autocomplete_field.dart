import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../location/geo_point.dart';
import '../map/map_pin_picker.dart';
import '../map/map_tiles.dart';
import '../location/location_service.dart';
import '../location/place_description.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// How much of a place the field wants.
enum LocationDetail {
  /// `Kathmandu` -- a city or area field.
  city,

  /// `Baneshwor, Kathmandu` -- somewhere a therapist is sent to.
  address,
}

/// A text field that offers the device's current location as a suggestion the
/// moment it is opened.
///
/// Opening the field (focusing it) starts the lookup, and the answer appears
/// under the field as a suggestion: tap it and the field fills. Typing filters
/// the suggestions the way an autocomplete does, and for a city field the
/// supported cities are offered alongside, so someone who would rather not
/// share their location still gets a list to pick from.
///
/// The suggestions sit under the field, in the page, rather than in an overlay.
/// An overlay opens over the keyboard on the fields near the bottom of a form
/// -- the home address, the visit address -- and the suggestion was the thing
/// being hidden.
///
/// Nothing is ever filled in without a tap. Location is a suggestion, not a
/// default: a wrong guess typed into someone's address for them is worse than
/// an empty box.
class LocationAutocompleteField extends ConsumerStatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    this.detail = LocationDetail.city,
    this.label,
    this.hint,
    this.decoration,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.words,
    this.textInputAction,
    this.style,
    this.places,
    this.onSelected,
    this.pinnable = false,
    this.onPinChanged,
  });

  final TextEditingController controller;
  final LocationDetail detail;

  /// A caption above the field, in the auth forms' style. Leave null when
  /// [decoration] carries a floating label instead.
  final String? label;
  final String? hint;

  /// Replaces the default decoration, for screens that style their own.
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final TextStyle? style;

  /// Known places to complete from as the person types. Defaults to the
  /// supported cities for a city field and to nothing for an address.
  final List<String>? places;
  final ValueChanged<String>? onSelected;

  /// Whether choosing "your current location" also pins the exact point, for
  /// a field a therapist navigates to. The lookup is then a precise one, and
  /// the field says when it is pinned and offers to remove the pin.
  final bool pinnable;

  /// The pinned point, or null when the pin is removed -- by the button, or
  /// by the text being replaced with something that no longer names the place
  /// the point is at. Adding to it ("House 12, Baneshwor, Kathmandu") keeps it.
  final ValueChanged<GeoPoint?>? onPinChanged;

  @override
  ConsumerState<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

enum _Kind { current, detecting, place, note }

class _Option {
  const _Option(this.kind, this.text, {this.caption});
  final _Kind kind;
  final String text;
  final String? caption;

  bool get tappable => kind == _Kind.current || kind == _Kind.place;
}

class _LocationAutocompleteFieldState
    extends ConsumerState<LocationAutocompleteField> {
  final _focus = FocusNode();

  /// The pinned point and the text it was pinned with.
  GeoPoint? _pin;
  String? _pinnedText;

  /// The current location was chosen, but its fix was too rough to pin.
  bool _tooRough = false;

  /// Whether the pin was placed on the map rather than taken from the GPS.
  bool _pinFromMap = false;

  List<String> get _places =>
      widget.places ??
      (widget.detail == LocationDetail.city ? supportedCities : const []);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(LocationAutocompleteField old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    final pinned = _pinnedText;
    if (pinned != null &&
        !widget.controller.text.toLowerCase().contains(pinned.toLowerCase())) {
      _setPin(null, null);
    }
    if (mounted) setState(() {});
  }

  void _setPin(GeoPoint? point, String? text, {bool fromMap = false}) {
    final changed = point != _pin;
    _pin = point;
    _pinnedText = point == null ? null : text;
    _pinFromMap = point != null && fromMap;
    if (point == null) _tooRough = false;
    if (changed) widget.onPinChanged?.call(point);
  }

  /// Opens the map on the current pin, or where the device is, and pins
  /// wherever the patient leaves it. The address text is filled from the
  /// place's name only when the field held nothing or just a city -- never
  /// over a house number someone typed.
  ///
  /// Opens the map on the current pin, or where the device is, and pins
  /// wherever the patient leaves it. The address text follows the pin: the
  /// patient has just chosen this spot on purpose, and a pin that sits
  /// somewhere other than the address beside it would send the therapist to
  /// the wrong place.
  Future<void> _pickOnMap() async {
    final here = ref.read(locationSuggestionProvider).location;
    final pick = await showMapPinPicker(
      context,
      start: _pin ?? here?.pinnablePoint,
    );
    if (pick == null || !mounted) return;

    final label = pick.label?.trim() ?? '';
    if (label.isNotEmpty) {
      widget.controller.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
    }
    setState(() {
      _tooRough = false;
      _setPin(pick.point, widget.controller.text.trim(), fromMap: true);
    });
  }

  void _onFocus() {
    // Opening the field is what starts the lookup -- not app launch, so nobody
    // is asked for location before they are doing something that uses it.
    if (_focus.hasFocus) {
      ref
          .read(locationSuggestionProvider.notifier)
          .ensureDetected(precise: widget.pinnable);
    }
    _refresh();
  }

  List<_Option> _options(LocationSuggestionState state, AppLocalizations l10n) {
    final typed = widget.controller.text.trim().toLowerCase();
    final options = <_Option>[];

    // A field that pins the point waits for the precise lookup: offering the
    // earlier approximate (possibly last-known) answer while it runs pinned
    // an old position.
    final settled = !widget.pinnable || (state.precise && !state.detecting);
    final here = settled ? state.location : null;
    String? hereText;
    if (here != null) {
      hereText = widget.detail == LocationDetail.city
          ? here.cityLabel
          : here.addressLabel;
      final lower = hereText.toLowerCase();
      // Typing narrows the suggestion like any autocomplete, and a field
      // already holding exactly it has nothing left to suggest.
      if ((typed.isEmpty || lower.contains(typed)) && lower != typed) {
        options.add(
          _Option(_Kind.current, hereText, caption: l10n.locationCurrentLabel),
        );
      }
    } else if (typed.isEmpty) {
      if (state.detecting || !settled) {
        options.add(_Option(_Kind.detecting, l10n.locationDetecting));
      } else if (state.result is LocationDenied) {
        options.add(_Option(_Kind.note, l10n.locationPermissionNeeded));
      } else if (state.result is LocationServicesOff) {
        options.add(_Option(_Kind.note, l10n.locationServicesOff));
      }
    }

    if (typed.isNotEmpty) {
      for (final place in _places) {
        final lower = place.toLowerCase();
        if (lower == typed || !lower.contains(typed)) continue;
        if (hereText != null && lower == hereText.toLowerCase()) continue;
        options.add(_Option(_Kind.place, place));
      }
    }
    return options;
  }

  void _choose(_Option option) {
    if (widget.pinnable) {
      final state = ref.read(locationSuggestionProvider);
      final here = state.precise && !state.detecting ? state.location : null;
      final point = option.kind == _Kind.current ? here?.pinnablePoint : null;
      // Pinned before the text changes, so the listener sees text that still
      // names the pinned place and keeps it.
      _setPin(point, option.text);
      _tooRough = option.kind == _Kind.current && point == null;
    }
    widget.controller.value = TextEditingValue(
      text: option.text,
      selection: TextSelection.collapsed(offset: option.text.length),
    );
    widget.onSelected?.call(option.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(locationSuggestionProvider);
    final options = _focus.hasFocus ? _options(state, l10n) : const <_Option>[];

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      decoration: widget.decoration ?? InputDecoration(hintText: widget.hint),
      validator: widget.validator,
      maxLines: widget.maxLines,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      style: widget.style,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          _Caption(widget.label!),
          const SizedBox(height: 6),
        ],
        field,
        if (_pin != null) ...[
          const SizedBox(height: 8),
          _PinCard(
            point: _pin!,
            fromMap: _pinFromMap,
            tiles: ref.watch(mapTileLayerProvider),
            onMove: widget.pinnable ? _pickOnMap : null,
            onRemove: () => setState(() => _setPin(null, null)),
          ),
        ] else if (_tooRough) ...[
          const SizedBox(height: 6),
          Text(
            l10n.locationPinTooRough,
            style: const TextStyle(fontSize: 11, color: AppColors.inkMid),
          ),
        ],
        // Once pinned, the card above moves the pin.
        if (widget.pinnable && _pin == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickOnMap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pine,
                textStyle: AppTypography.textTheme.titleSmall?.copyWith(
                  fontFamily: AppTypography.fontSans,
                  letterSpacing: 0,
                ),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(l10n.locationChooseOnMap),
            ),
          ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SuggestionPanel(options: options, onChoose: _choose),
        ],
      ],
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.options, required this.onChoose});

  final List<_Option> options;
  final ValueChanged<_Option> onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _OptionRow(option: options[i], onChoose: onChoose),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.onChoose});

  final _Option option;
  final ValueChanged<_Option> onChoose;

  @override
  Widget build(BuildContext context) {
    final Widget leading = switch (option.kind) {
      _Kind.detecting => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pine),
      ),
      _Kind.current => const Icon(
        Icons.my_location_rounded,
        size: 18,
        color: AppColors.pine,
      ),
      _Kind.place => const Icon(
        Icons.place_outlined,
        size: 18,
        color: AppColors.inkMute,
      ),
      _Kind.note => const Icon(
        Icons.location_off_outlined,
        size: 18,
        color: AppColors.inkMute,
      ),
    };

    final isNote = option.kind == _Kind.note || option.kind == _Kind.detecting;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.text,
                  style: TextStyle(
                    fontSize: isNote ? 12 : 13,
                    fontWeight: option.kind == _Kind.current
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isNote ? AppColors.inkMid : AppColors.ink,
                  ),
                ),
                if (option.caption != null)
                  Text(
                    option.caption!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.inkMute,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!option.tappable) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: () => onChoose(option), child: row),
    );
  }
}

/// The pin under a pinnable field, on a small still map: where the therapist
/// will be sent, who sees it, and a way to move or take it off. A tap on the
/// map moves it too.
class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.point,
    required this.tiles,
    required this.onRemove,
    this.onMove,
    this.fromMap = false,
  });

  final GeoPoint point;
  final Widget Function() tiles;
  final VoidCallback onRemove;
  final VoidCallback? onMove;
  final bool fromMap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // inside _PinCard.build — replace the SizedBox(height: 130, child: FlutterMap(...))

          SizedBox(
            height: 130,
            child: GoogleMap(
              key: ValueKey(point.query), // force rebuild when pin moves
              initialCameraPosition: CameraPosition(
                target: LatLng(point.latitude, point.longitude),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('pin'),
                  position: LatLng(point.latitude, point.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: false,
              liteModeEnabled: true, // cheaper on Android for a static preview
              onTap: onMove != null ? (_) => onMove!() : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: AppColors.pine,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromMap ? l10n.locationPinnedMap : l10n.locationPinned,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        l10n.locationPinnedWho,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMove != null)
                  IconButton(
                    onPressed: onMove,
                    tooltip: l10n.locationMovePin,
                    icon: const Icon(
                      Icons.edit_location_alt_outlined,
                      size: 20,
                      color: AppColors.pine,
                    ),
                  ),
                TextButton(
                  onPressed: onRemove,
                  child: Text(
                    l10n.locationPinRemove,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Inter',
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The mono uppercase caption the auth forms put above a field. Redrawn here
/// rather than imported: `core` does not depend on a feature.
class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      letterSpacing: 0,
      color: AppColors.inkMute,
    ),
  );
}
