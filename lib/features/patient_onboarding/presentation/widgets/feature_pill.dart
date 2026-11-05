import 'package:flutter/material.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

class FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeaturePill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.pine),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.fontSans,
                fontSize: 13.5,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}