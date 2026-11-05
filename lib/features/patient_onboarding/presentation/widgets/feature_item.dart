import 'package:flutter/material.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.pinePale.withAlpha(110),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.pine),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: AppTypography.fontSans,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
