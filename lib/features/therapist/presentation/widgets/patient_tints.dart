import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar fills cycle by list position, as in the prototype's patient lists.
const _tints = [AppColors.pinePale, AppColors.amberPale, AppColors.mist];

Color patientTintFor(int index) => _tints[index % _tints.length];
