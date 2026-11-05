import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PatientHelpScreen extends StatefulWidget {
  const PatientHelpScreen({super.key});

  @override
  State<PatientHelpScreen> createState() => _PatientHelpScreenState();
}

class _PatientHelpScreenState extends State<PatientHelpScreen> {
  int? _expandedIndex;

  /// Built per-build rather than held `const`: the copy comes from the ARB
  /// files, which need a context.
  static List<_FaqData> _faqs(AppLocalizations l10n) => [
    _FaqData(question: l10n.faqBookQuestion, answer: l10n.faqBookAnswer),
    _FaqData(question: l10n.faqCancelQuestion, answer: l10n.faqCancelAnswer),
    _FaqData(question: l10n.faqPaymentQuestion, answer: l10n.faqPaymentAnswer),
    _FaqData(question: l10n.faqReportsQuestion, answer: l10n.faqReportsAnswer),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final faqs = _faqs(l10n);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back arrow
              AppBackButton(onPressed: context.pop, gutter: false),

              Text(
                l10n.helpTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.helpSubtitle,
                style: text.bodyMedium!.copyWith(
                  height: 1.4,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              ...List.generate(faqs.length, (i) {
                final faq = faqs[i];
                final isExpanded = _expandedIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Material(
                    // Mint tint while open, so the active question stands out.
                    color: isExpanded
                        ? Color.alphaBlend(
                            AppColors.pinePale.withAlpha(150),
                            Colors.white,
                          )
                        : Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      side: BorderSide(
                        color: isExpanded ? AppColors.pine : AppColors.border,
                        width: isExpanded ? 1.2 : 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => setState(
                        () => _expandedIndex = isExpanded ? null : i,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    faq.question,
                                    style: text.titleSmall!.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      letterSpacing: 0,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 24,
                                  color: isExpanded
                                      ? AppColors.pine
                                      : AppColors.inkMid,
                                ),
                              ],
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                faq.answer,
                                style: text.bodyMedium!.copyWith(
                                  fontSize: 14,
                                  height: 1.5,
                                  letterSpacing: 0,
                                  color: AppColors.inkMid,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqData {
  const _FaqData({required this.question, required this.answer});
  final String question;
  final String answer;
}
