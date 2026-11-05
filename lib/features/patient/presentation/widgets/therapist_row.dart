import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar fills cycle through these three tints by list position, as in the
/// prototype.
const _avatarTints = [AppColors.pinePale, AppColors.amberPale, AppColors.mist];

Color avatarTintFor(int index) => _avatarTints[index % _avatarTints.length];
