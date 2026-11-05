import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../domain/entities/session.dart';
import '../session_labels.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, this.session});

  /// The session the API just created. Null only if this route is reached
  /// directly (deep link, hot reload) rather than from a booking.
  final Session? session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final s = session;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Column(
                  children: [
                    const _SuccessBadge(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.bookingSuccessTitle,
                      textAlign: TextAlign.center,
                      style: text.titleLarge!.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pine,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s == null
                          ? l10n.bookingSuccessGeneric
                          : l10n.bookingSuccessDetail(
                              s.therapistName,
                              formatDateTime(s.date, s.time, l10n),
                            ),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium!.copyWith(height: 1.4),
                    ),
                    if (s != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        // The real session id, not an invented booking
                        // reference.
                        l10n.bookingRef(s.id.toUpperCase()),
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      _DetailsCard(session: s),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/patient/sessions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pine,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        // Buttons default to labelLarge (mono, spaced), so
                        // the style has to be given here.
                        textStyle: text.titleMedium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                      ),
                      child: Text(l10n.actionViewMySessions),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/patient/home'),
                      icon: const Icon(Icons.home_outlined, size: 20),
                      label: Text(l10n.actionBackToHome),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.pine,
                        side: const BorderSide(color: AppColors.pine),
                        textStyle: text.titleMedium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────

/// A pine check in a pale ring, with a few specks of confetti around it.
/// The check eases in when the screen opens.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pale ring
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              color: AppColors.pinePale.withAlpha(150),
              shape: BoxShape.circle,
            ),
          ),

          // Check
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.pine,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 42, color: Colors.white),
            ),
          ),

          // Confetti
          const _Speck(top: 10, left: 26, size: 7, color: AppColors.pineLight),
          const _Speck(top: 6, right: 40, size: 5, color: AppColors.pinePale),
          const _Speck(top: 28, right: 12, size: 8, color: AppColors.amberBrand),
          const _Speck(bottom: 34, left: 10, size: 6, color: AppColors.amberBrand),
          const _Speck(bottom: 14, right: 22, size: 6, color: AppColors.pineLight),
        ],
      ),
    );
  }
}

/// One small diamond of confetti.
class _Speck extends StatelessWidget {
  const _Speck({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(width: size, height: size, color: color),
      ),
    );
  }
}

// ── Details ──────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final locale = Localizations.localeOf(context).toString();

    String dateLabel;
    try {
      dateLabel = DateFormat('EEE, d MMM y', locale).format(s.date);
    } catch (_) {
      dateLabel = DateFormat('EEE, d MMM y').format(s.date);
    }

    const divider = Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // When
          _InfoRow(
            leading: const _IconTile(icon: Icons.calendar_today_outlined),
            title: dateLabel,
            subtitle:
                '${formatTime12h(s.time)} · ${l10n.bookingDurationValue}',
          ),
          divider,

          // Who
          _InfoRow(
            leading: ProfileAvatar(
              initials: getInitials(s.therapistName),
              photoUrl: s.therapistPhotoUrl,
              thumbUrl: s.therapistPhotoThumbUrl,
              tint: AppColors.pinePale,
              size: 44,
            ),
            title: s.therapistName,
            subtitle: sessionStatusLabel(s.status, l10n),
          ),
          divider,

          // Where
          _InfoRow(
            leading: _IconTile(
              icon: s.isHomeVisit
                  ? Icons.home_outlined
                  : Icons.local_hospital_outlined,
            ),
            title: s.isHomeVisit
                ? l10n.sessionHomeVisitAt(s.address)
                : l10n.sessionTypeAtClinic,
          ),
          divider,

          // Amount
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const _IconTile(icon: Icons.account_balance_wallet_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(l10n.labelFee, style: text.bodyMedium),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(s.fee, l10n),
                  style: text.titleLarge!.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A mint rounded square holding an icon.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.pinePale.withAlpha(150),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Icon(icon, size: 22, color: AppColors.pine),
    );
  }
}

/// A leading widget with a bold line and an optional small line.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.leading, required this.title, this.subtitle});

  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall!.copyWith(fontSize: 15),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}