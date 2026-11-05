import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// One heading-and-paragraph block.
///
/// Shared by all three about screens so the rhythm between sections is set in
/// one place rather than re-spaced per page.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium!.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: text.bodyMedium!.copyWith(
              fontSize: 14,
              height: 1.55,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shell the policy pages share: a title, a "last updated" line, a lead
/// paragraph, then sections.
///
/// A policy that does not say when it last changed is not much use to anyone
/// trying to work out what they agreed to, so the date is part of the shell
/// rather than optional.
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.lede,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final String lede;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
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
              title,
              style: text.titleLarge!.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.legalLastUpdated(lastUpdated),
              style: text.bodySmall!.copyWith(
                fontSize: 13,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              lede,
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                height: 1.55,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ...sections,
          ],
        ),
      ),
    );
  }
}
