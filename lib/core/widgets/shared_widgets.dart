import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Shared UI components for the Sahayarti app.

// ── Sahayatri Button ──
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = false,
    this.size = AppButtonSize.medium,
    this.disabled = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool fullWidth;
  final AppButtonSize size;
  final bool disabled;

  factory AppButton.text(
    String label, {
    Key? key,
    VoidCallback? onPressed,
    bool fullWidth = false,
    bool disabled = false,
    AppButtonVariant variant = AppButtonVariant.primary,
    AppButtonSize size = AppButtonSize.medium,
  }) {
    return AppButton(
      key: key,
      // One line, always. A button is a fixed-height box, so a label that
      // wraps does not make the button taller — it spills out of the bottom of
      // it. Ellipsising is the lesser failure, and it only ever happens where
      // the caller has already bounded the width.
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: onPressed,
      fullWidth: fullWidth,
      disabled: disabled,
      variant: variant,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (variant) {
      AppButtonVariant.primary => (AppColors.amberBrand, AppColors.ink),
      AppButtonVariant.secondary => (AppColors.pine, Colors.white),
      AppButtonVariant.outline => (Colors.transparent, AppColors.pine),
      AppButtonVariant.danger => (AppColors.dangerPale, AppColors.danger),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.inkMid),
    };

    final (double h, double fz) = switch (size) {
      AppButtonSize.small => (36.0, 12.0),
      AppButtonSize.medium => (48.0, 14.0),
      AppButtonSize.large => (56.0, 16.0),
    };

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: h,
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
          side: variant == AppButtonVariant.outline
              ? const BorderSide(color: AppColors.pine, width: 1.5)
              : null,
          padding: EdgeInsets.symmetric(
            horizontal: size == AppButtonSize.small ? 12 : 20,
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: fz,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
          child: child,
        ),
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, outline, danger, ghost }
enum AppButtonSize { small, medium, large }

// ── Avatar ──
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    this.tint = AppColors.pinePale,
    this.size = 40,
  });

  final String initials;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.fontSans,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
          color: AppColors.pine,
        ),
      ),
    );
  }
}

// ── Status Tag ──
class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.label,
    this.tone = TagTone.green,
  });

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      TagTone.green => (AppColors.pinePale, AppColors.pine),
      TagTone.amber => (AppColors.amberPale, const Color(0xFF8a5a14)),
      TagTone.red => (AppColors.dangerPale, AppColors.danger),
      TagTone.neutral => (AppColors.mist, AppColors.inkMid),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}

enum TagTone { green, amber, red, neutral }

// ── Section Header ──
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          // Expanded, not Text + Spacer: the label is monospaced with 1.8 of
          // letter-spacing, so a long one ("WHAT ARE YOU LOOKING FOR?") plus
          // an action ran off the right edge on a narrow phone — and off any
          // phone at a large text scale. Same layout as before, title left
          // and action right; it just has somewhere to give now.
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (action != null)
            action!
          else if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.pine,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.pine,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card wrapper ──
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color = AppColors.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: card,
        ),
      );
    }

    return card;
  }
}

// ── Menu Item ──
class MenuItem extends StatelessWidget {
  const MenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.meta,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final String? meta;
  final VoidCallback? onTap;

  factory MenuItem.icon({
    required String iconData,
    required String label,
    String? meta,
    VoidCallback? onTap,
  }) {
    return MenuItem(
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.pinePale,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        alignment: Alignment.center,
        child: Text(iconData, style: const TextStyle(fontSize: 18)),
      ),
      label: label,
      meta: meta,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    if (meta != null)
                      Text(
                        meta!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkMute,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkMute),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page Header ──
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.onBack,
    required this.title,
    this.right,
  });

  final VoidCallback? onBack;
  final String title;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    // 20 on the sides, not 16. The spec's app-bar padding is
    // `8 top / 20 sides / 12 bottom`, the shared `AppHeader` directly above
    // this one already uses `AppSpacing.page`, and every body below it is on a
    // 20 grid — so the back button was the one thing on a sub-page sitting 4px
    // outside the column everything else lines up to, on all fifty screens
    // that use this widget.
    //
    // `LayoutBuilder` is here only to give the trailing slot a width to cap
    // itself against; see the ConstrainedBox below.
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (onBack != null)
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppColors.ink),
                ),
              )
            else
              const SizedBox(width: 36),
            // Expanded + Center, not Spacer + Text + Spacer. The two spacers
            // gave the title no width of its own, so a long one — "Recovery
            // progress", "Certifications & license" — overflowed the row on a
            // narrow phone at a large text scale, by 481px in the worst case
            // measured. This centres it in exactly the same place and lets it
            // ellipsise instead. Same fix, same reason, as the section headers.
            Expanded(
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontSerif,
                    fontSize: 18,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            // A *minimum* of 36, not exactly 36. The spec calls this slot
            // "min-width 36px (empty, or a text/pill action)", and the one
            // action that exists — the `My packages` pill — is three times
            // that wide; a fixed 36 clipped it to a sliver. With `right` null
            // this still measures exactly 36, so the title stays centred on
            // every screen that has no trailing action.
            //
            // The maximum is the other half of it, and a golden found the need
            // for it: the title is `Expanded` and gives way, but an unbounded
            // trailing slot does not, so the Nepali pill at 1.6x text on a
            // 320dp phone burst the row by 48px. Capped at 45% the action
            // still keeps more room than the title beside it, and both give
            // way rather than overflowing. At any ordinary size the pill is
            // well inside the cap, so nothing moves.
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 36,
                maxWidth: constraints.maxWidth * 0.45 < 36
                    ? 36
                    : constraints.maxWidth * 0.45,
              ),
              child: right ?? const SizedBox(width: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KPI Card ──
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    this.isHighlighted = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final bool isHighlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.amberPale : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      // Every line is capped at one. These cards sit in grids with a fixed
      // childAspectRatio, so the height is not theirs to grow into: a label
      // or subtitle that wraps to a second line overflows the card rather
      // than making it taller. English fits on one line everywhere; several
      // of the Nepali translations do not, and this is where that showed up
      // first — by 39px on the performance grid.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.headlineSmall),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10 : null,
              color: AppColors.inkMid,
            ),
          ),
        ],
      ),
    );
  }
}
