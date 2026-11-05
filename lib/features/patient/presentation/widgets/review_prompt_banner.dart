import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../domain/entities/session.dart';
import '../providers/patient_providers.dart';
import '../providers/review_prompt_providers.dart';
import 'review_sheet.dart';

/// "How was your visit with Dr. X?" on Home, after a completed visit.
///
/// Renders nothing -- no height, no padding -- when there is nothing to ask,
/// so it can sit in the Home column unconditionally.
class ReviewPromptBanner extends ConsumerWidget {
  const ReviewPromptBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewPromptProvider);
    if (session == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          // Amber tint stays: this is the one prompt on Home that asks for
          // something, so it should stand out from the white cards.
          color: AppColors.amberPale,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: AppColors.amberBrand.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  initials: getInitials(session.therapistName),
                  photoUrl: session.therapistPhotoUrl,
                  thumbUrl: session.therapistPhotoThumbUrl,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.homeReviewPromptTitle(session.therapistName),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Both buttons share the row; neither can push the other off a
            // narrow screen at a large text size.
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _rate(context, ref, session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pine,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        // Buttons default to labelLarge (mono, spaced).
                        textStyle: text.titleSmall!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.row),
                        ),
                      ),
                      child: Text(
                        l10n.homeReviewPromptRate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: () => ref
                          .read(dismissedReviewPromptsProvider.notifier)
                          .dismiss(session.id),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkMid,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: text.titleSmall!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.row),
                        ),
                      ),
                      child: Text(
                        l10n.homeReviewPromptLater,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rate(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final choice = await showReviewSheet(context, session: session);
    if (choice == null) return;

    final result = await ref
        .read(patientActionsProvider)
        .review(
          sessionId: session.id,
          rating: choice.rating,
          comment: choice.comment,
        );
    // A refusal (usually "already reviewed") also drops the banner: the action
    // refreshes the reviewable list either way.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        result.match(
          (f) => SnackBar(
            content: Text(f.message),
            backgroundColor: AppColors.danger,
          ),
          (_) => SnackBar(content: Text(l10n.sessionReviewThanks)),
        ),
      );
  }
}