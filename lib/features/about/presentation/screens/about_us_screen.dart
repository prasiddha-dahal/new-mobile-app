import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'legal_scaffold.dart';

/// Who Sahayatri is, for a patient deciding whether to trust it with a
/// relative's care.
///
/// Deliberately carries no counts. The design mock showed "180+ therapists /
/// 12.4k home visits / 4.9 stars", but there is no endpoint for platform-wide
/// totals and the real numbers are nowhere near those, so printing them would
/// be a claim the product cannot stand behind. The three markers below say
/// what is true instead — and stay true as the network grows.
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xxxl,
          ),
          children: [
            // Back arrow
            AppBackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/patient/account'),
                  gutter: false,
            ),

            Text(
              l10n.aboutTitle,
              style: text.titleLarge!.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.aboutHeadline,
              style: text.titleLarge!.copyWith(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.aboutIntro,
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                height: 1.5,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _TrustRow(),
            const SizedBox(height: AppSpacing.xxl),
            LegalSection(
              title: l10n.aboutMissionTitle,
              body: l10n.aboutMissionBody,
            ),
            LegalSection(
              title: l10n.aboutVerifiedTitle,
              body: l10n.aboutVerifiedBody,
            ),
            LegalSection(title: l10n.aboutCareTitle, body: l10n.aboutCareBody),
            LegalSection(
              title: l10n.aboutAnywhereTitle,
              body: l10n.aboutAnywhereBody,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the platform can actually claim, in place of invented figures.
///
/// Same three-up shape as the design's stat card, but each cell states a fact
/// that holds however many therapists are on the platform on a given day.
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        // Mint tint, so the card reads as the page's one highlight.
        color: Color.alphaBlend(
          AppColors.pinePale.withAlpha(150),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Marker(
                title: context.l10n.aboutStatVerified,
                detail: context.l10n.aboutStatVerifiedSub,
              ),
            ),
            const _Divider(),
            Expanded(
              child: _Marker(
                title: context.l10n.aboutStatValleyWide,
                detail: context.l10n.aboutStatValleyWideSub,
              ),
            ),
            const _Divider(),
            Expanded(
              child: _Marker(
                title: context.l10n.aboutStatHomeOrClinic,
                detail: context.l10n.aboutStatHomeOrClinicSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: AppColors.pine.withValues(alpha: 0.15));
}

class _Marker extends StatelessWidget {
  const _Marker({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleSmall!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(
              fontSize: 12,
              height: 1.3,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
        ],
      ),
    );
  }
}
