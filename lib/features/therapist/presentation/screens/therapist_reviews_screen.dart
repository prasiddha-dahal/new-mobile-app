import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';

/// What patients have said about this therapist.
///
/// This used to be a hard-coded list -- a 4.9 average, "182 reviews" and three
/// invented patients -- so every therapist saw the same fabricated praise.
/// It now reads `GET /therapists/me/reviews`, and says so plainly when there is
/// nothing to show.
class TherapistReviewsScreen extends ConsumerWidget {
  const TherapistReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviews = ref.watch(therapistReviewsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(therapistReviewsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                PageHeader(
                  title: l10n.reviewsTitle,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/therapist/account'),
                ),
                const SizedBox(height: 24),
                reviews.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SkeletonList(count: 3, itemHeight: 110),
                  ),
                  error: (e, _) => ErrorStateView(
                    failure: e is Failure ? e : const UnknownFailure(),
                    onRetry: () => ref.invalidate(therapistReviewsProvider),
                  ),
                  data: (data) => _Body(data: data),
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
  const _Body({required this.data});

  final TherapistReviewsDto data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (data.reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: EmptyStateView(
          title: l10n.reviewsEmptyTitle,
          description: l10n.reviewsEmptyBody,
          icon: Icons.star_outline_rounded,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                data.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stars(filled: data.averageRating.round(), size: 20),
                  const SizedBox(height: 4),
                  Text(
                    l10n.reviewsCount(data.total),
                    style: const TextStyle(fontSize: 13, color: AppColors.inkMid),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionHeader(title: l10n.reviewsRecent),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [for (final r in data.reviews) _ReviewCard(review: r)],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final TherapistReviewDto review;

  @override
  Widget build(BuildContext context) {
    final created = review.created;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  initials: getInitials(review.name),
                  photoUrl: review.photo,
                  thumbUrl: review.photoThumb,
                  tint: AppColors.pinePale,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      if (created != null)
                        Text(
                          formatRelativeTime(created, context.l10n),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMute,
                          ),
                        ),
                    ],
                  ),
                ),
                _Stars(filled: review.stars, size: 14),
              ],
            ),
            if (review.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkMid,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Five stars, [filled] of them solid. The rating is what the reviewer gave,
/// not a row of five gold stars whatever it was.
class _Stars extends StatelessWidget {
  const _Stars({required this.filled, required this.size});

  final int filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final on = i < filled;
        return Icon(
          on ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: on ? AppColors.amberBrand : AppColors.inkMute,
        );
      }),
    );
  }
}
