import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/therapist.dart';
import '../providers/patient_providers.dart';

/// One review the signed-in patient wrote, joined to the therapist and the
/// visit so the row can show a name instead of an id.
class GivenReview {
  const GivenReview({
    required this.review,
    required this.therapistName,
    this.specialty = '',
    this.city = '',
    this.photoUrl,
    this.photoThumbUrl,
    this.theirRating,
    this.theirReviewCount,
    this.visit,
  });

  final MyReview review;
  final String therapistName;
  final String specialty;
  final String city;
  final String? photoUrl;
  final String? photoThumbUrl;
  final double? theirRating;
  final int? theirReviewCount;
  final Session? visit;
}

/// `GET /reviews`, newest first, with therapist names filled in.
///
/// The review payload only carries `therapistId`. The name, photo and the
/// therapist's own standing come from `GET /therapists/{id}`. The visit date
/// comes from the patient's sessions when that session is in the list.
final givenReviewsProvider = FutureProvider<List<GivenReview>>((ref) async {
  final reviews = await ref.watch(myReviewsProvider.future);
  final sessions = await ref.watch(patientSessionsProvider.future);
  final bySession = {for (final session in sessions) session.id: session};
  final repo = ref.watch(patientRepositoryProvider);

  final therapists = <String, Therapist>{};
  for (final id in reviews.map((review) => review.therapistId).toSet()) {
    final result = await repo.getTherapist(id);
    result.fold((_) {}, (therapist) => therapists[id] = therapist);
  }

  return [
    for (final review in reviews)
      GivenReview(
        review: review,
        therapistName:
            therapists[review.therapistId]?.name ??
            bySession[review.sessionId]?.therapistName ??
            '',
        specialty: therapists[review.therapistId]?.specialty ?? '',
        city: therapists[review.therapistId]?.city ?? '',
        photoUrl:
            therapists[review.therapistId]?.photoUrl ??
            bySession[review.sessionId]?.therapistPhotoUrl,
        photoThumbUrl:
            therapists[review.therapistId]?.photoThumbUrl ??
            bySession[review.sessionId]?.therapistPhotoThumbUrl,
        theirRating: therapists[review.therapistId]?.rating,
        theirReviewCount: therapists[review.therapistId]?.reviewCount,
        visit: bySession[review.sessionId],
      ),
  ];
});

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final reviews = ref.watch(givenReviewsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myReviewsProvider);
            ref.invalidate(patientSessionsProvider);
            ref.invalidate(givenReviewsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back arrow, lined up with the title.
                AppBackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/patient/account'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  child: Text(
                    l10n.myReviewsTitle,
                    style: text.titleLarge!.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                reviews.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    child: SkeletonList(count: 3, itemHeight: 120),
                  ),
                  error: (error, _) => ErrorStateView(
                    failure: error is Failure ? error : const UnknownFailure(),
                    onRetry: () => ref.invalidate(givenReviewsProvider),
                  ),
                  data: (data) => _Body(reviews: data),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.reviews});

  final List<GivenReview> reviews;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    if (reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: EmptyStateView(
          title: l10n.reviewsEmptyTitle,
          description: l10n.myReviewsEmptyBody,
          icon: Icons.star_outline_rounded,
        ),
      );
    }

    final average =
        reviews.fold<int>(0, (sum, row) => sum + row.review.rating) /
        reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary: the average on a mint card.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                AppColors.pinePale.withAlpha(150),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              children: [
                Text(
                  average.toStringAsFixed(1),
                  style: text.titleLarge!.copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Stars(filled: average.round(), size: 22),
                      const SizedBox(height: 4),
                      Text(
                        l10n.myReviewsAverage(
                          l10n.reviewsCount(reviews.length),
                        ),
                        style: text.bodyMedium!.copyWith(
                          fontSize: 13,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Text(
            l10n.reviewsRecent,
            style: text.titleMedium!.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            children: [
              for (final row in reviews)
                _ReviewCard(
                  row: row,
                  timesForTherapist: reviews
                      .where(
                        (other) =>
                            other.review.therapistId == row.review.therapistId,
                      )
                      .length,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.row, required this.timesForTherapist});

  final GivenReview row;
  final int timesForTherapist;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final name = row.therapistName.isEmpty ? l10n.therapist : row.therapistName;
    final place = [
      row.specialty,
      row.city,
    ].where((part) => part.isNotEmpty).join(' · ');
    final comment = row.review.comment?.trim() ?? '';
    final visit = row.visit;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatar(
                  initials: getInitials(name),
                  photoUrl: row.photoUrl,
                  thumbUrl: row.photoThumbUrl,
                  tint: AppColors.pinePale,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: AppColors.ink,
                        ),
                      ),
                      if (place.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(
                            fontSize: 13,
                            letterSpacing: 0,
                            color: AppColors.inkMid,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        [
                          l10n.myReviewsYouGave(row.review.rating),
                          if (visit != null)
                            formatDateTime(visit.date, visit.time, l10n),
                          if (timesForTherapist > 1)
                            l10n.myReviewsTimes(timesForTherapist),
                        ].join(' · '),
                        style: text.bodySmall!.copyWith(
                          fontSize: 12,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Stars(filled: row.review.rating, size: 14),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              // The patient's own words, on a quiet mist block.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: Text(
                  comment,
                  style: text.bodyMedium!.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
            if (row.theirRating != null && (row.theirReviewCount ?? 0) > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.amberBrand,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.myReviewsTheirStanding(
                        row.theirRating!.toStringAsFixed(1),
                        row.theirReviewCount!,
                      ),
                      style: text.bodySmall!.copyWith(
                        fontSize: 12,
                        letterSpacing: 0,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.filled, required this.size});

  final int filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final on = index < filled;
        return Icon(
          on ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: on ? AppColors.amberBrand : AppColors.inkMute,
        );
      }),
    );
  }
}
