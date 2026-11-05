import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The back arrow every sub-page uses, lined up with the page title.
///
/// [gutter] adds the page's 20px side padding. Pass `false` when the arrow
/// already sits inside a list or column that has that padding.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.onPressed, this.gutter = true});

  final VoidCallback onPressed;
  final bool gutter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter ? AppSpacing.page : 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          // The arrow glyph has about 3px of whitespace on its left; this
          // pulls its visible edge onto the title's left edge.
          offset: const Offset(-3, 0),
          child: IconButton(
            onPressed: onPressed,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(
              Icons.arrow_back,
              size: 28,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}