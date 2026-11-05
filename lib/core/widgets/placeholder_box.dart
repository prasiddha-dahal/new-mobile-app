import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Stands in for artwork that does not exist yet.
///
/// The DESIGN-TODO convention (docs/DEVELOPMENT_PLAN.md §0.2): when a screen
/// calls for an image, illustration, or icon asset that has not been produced,
/// reserve its real footprint with this box instead of shipping a broken
/// `Image.asset` or inventing artwork. Every use is paired with a
/// `// TODO(design): ...` comment naming the asset that is needed.
class PlaceholderBox extends StatelessWidget {
  const PlaceholderBox({
    super.key,
    required this.label,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.icon = Icons.image_outlined,
    this.showLabel = true,
  });

  /// Describes the missing asset, e.g. 'Therapist photo'. Already localised
  /// by the caller — a screen reader reads it out, so it is copy, not a
  /// developer note.
  final String label;
  final double? width;
  final double? height;
  final double borderRadius;
  final IconData icon;
  final bool showLabel;

  /// A circular placeholder for avatars.
  factory PlaceholderBox.avatar({
    Key? key,
    required String label,
    double size = 48,
  }) =>
      PlaceholderBox(
        key: key,
        label: label,
        width: size,
        height: size,
        borderRadius: size / 2,
        icon: Icons.person_outline,
        showLabel: false,
      );

  @override
  Widget build(BuildContext context) {
    final compact = (height ?? 0) < 56 || (width ?? 0) < 96;

    return Semantics(
      label: context.l10n.placeholderSemantics(label),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.placeholderFill,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.placeholderBorder),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 18 : 26, color: AppColors.placeholderInk),
            if (showLabel && !compact) ...[
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: AppColors.placeholderInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
