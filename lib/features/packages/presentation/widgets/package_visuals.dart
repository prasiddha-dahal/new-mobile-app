import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pastel tile fills from the design system (docs/LOVABLE_DESIGN_SPEC.md —
/// "Pastel category tiles"), cycled per card.
const packageTileTints = <Color>[
  AppColors.pinePale,
  Color(0xFFE8DCF5),
  AppColors.amberPale,
  Color(0xFFDCE7F5),
  Color(0xFFF5DCE0),
];

/// The backend stores a **lucide-react icon name** (`Brain`, `Activity`,
/// `HeartHandshake`) because the web app renders it directly. Flutter has no
/// icon set keyed by those names, so the handful the catalogue actually uses is
/// mapped by hand and anything else falls back to a neutral medical glyph —
/// better than a broken tile or an invented emoji.
IconData packageIconFor(String name) {
  switch (name.trim().toLowerCase()) {
    case 'brain':
      return Icons.psychology_outlined;
    case 'activity':
      return Icons.monitor_heart_outlined;
    case 'hearthandshake':
    case 'heart':
      return Icons.volunteer_activism_outlined;
    case 'accessibility':
    case 'personstanding':
      return Icons.accessibility_new_outlined;
    case 'baby':
      return Icons.child_care_outlined;
    case 'bone':
      return Icons.healing_outlined;
    default:
      return Icons.medical_services_outlined;
  }
}

/// Rounded icon tile used on every package card.
class PackageIconTile extends StatelessWidget {
  const PackageIconTile({
    super.key,
    required this.icon,
    this.tintIndex = 0,
    this.size = 44,
  });

  final String icon;
  final int tintIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: packageTileTints[tintIndex % packageTileTints.length],
        borderRadius: BorderRadius.circular(size * 0.4),
      ),
      alignment: Alignment.center,
      child: Icon(
        packageIconFor(icon),
        size: size * 0.45,
        color: AppColors.pine,
      ),
    );
  }
}

/// Sessions-used bar. Mirrors the recovery screen's gradient bar so the two
/// read as the same component.
class PackageProgressBar extends StatelessWidget {
  const PackageProgressBar({super.key, required this.value, this.height = 10});

  /// 0.0 – 1.0.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: AppColors.mist),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.pine, AppColors.amberBrand],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
