import 'package:flutter/material.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';

class Dot extends StatelessWidget {
  final bool isActive;
  const Dot({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isActive ? 10 : 7,
      height: isActive ? 10 : 7,
      decoration: BoxDecoration(
        color: isActive ? AppColors.pine : AppColors.placeholderBorder,
        shape: BoxShape.circle,
      ),
    );
  }
}