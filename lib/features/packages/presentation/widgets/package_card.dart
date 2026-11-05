import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../domain/entities/therapy_package.dart';
import 'package_visuals.dart';

/// One catalogue row.
///
/// The design puts a `1 Week / 2 Weeks / 3 Weeks / 4 Weeks` duration picker and
/// a "From Rs 4,500" teaser here. Neither is backed: a `Package` has exactly one
/// price, one session count and one validity window, so the card states those
/// three facts instead of offering choices that cannot be bought.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    required this.onView,
    this.tintIndex = 0,
  });

  final TherapyPackage package;
  final VoidCallback onView;
  final int tintIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final radius = BorderRadius.circular(AppRadii.sheet);

    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onView,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon, tag and name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PackageIconTile(icon: package.icon, tintIndex: tintIndex),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (package.tag.isNotEmpty) ...[
                          StatusTag(
                            label: package.tag,
                            tone: TagTone.neutral,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          package.name,
                          style: text.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (package.featured)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(
                        Icons.star_rounded,
                        size: 22,
                        color: AppColors.amberBrand,
                      ),
                    ),
                ],
              ),

              if (package.blurb.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  package.blurb,
                  style: text.bodyMedium!.copyWith(fontSize: 13, height: 1.5),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Price, terms and the button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCurrency(package.price.toDouble(), l10n),
                          style: text.titleLarge!.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          packageTermsLine(package, l10n),
                          style: text.bodySmall!.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Flexible, not bare. The price column beside it already
                  // gives way; without this, at 1.6x text on a 320dp phone the
                  // Nepali label pushed the footer off the right edge of the
                  // card. Nothing moves at ordinary sizes.
                  Flexible(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: onView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pine,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          minimumSize: Size.zero,
                          // Buttons default to labelLarge (mono, spaced), so
                          // the style has to be given here.
                          textStyle: text.titleSmall,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                          ),
                        ),
                        child: Text(
                          l10n.packagesViewPackage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "per month · 12 sessions · valid 30 days" — the backend's own [cadence]
/// display string, with the validity window appended when it is not already
/// implied by it.
String packageTermsLine(TherapyPackage package, AppLocalizations l10n) {
  final parts = <String>[];
  if (package.cadence.trim().isNotEmpty) {
    // The backend's own display string. It arrives in English; translating it
    // is a backend change, not a Flutter one.
    parts.add(package.cadence.trim());
  } else if (package.sessionCount > 0) {
    parts.add(l10n.packagesSessionCount(package.sessionCount));
  }
  if (package.validityDays > 0) {
    parts.add(l10n.packagesValidDays(package.validityDays));
  }
  return parts.isEmpty ? l10n.packagesOneOff : parts.join(' · ');
}