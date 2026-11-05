import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/therapist.dart';
import '../providers/patient_providers.dart';

/// Rehab progress.
///
/// The session counts are real — they come from the patient dashboard. The
/// prototype's streak, pain reduction and milestone timeline have no backing
/// model, so they are not fabricated here.
class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final dashboard = ref.watch(patientDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            8,
            AppSpacing.page,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              l10n.recoveryTitle,
              style: text.titleLarge!.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            dashboard.when(
              loading: () => const SkeletonList(count: 3, itemHeight: 120),
              error: (e, _) => ErrorStateView(
                failure: e is Failure ? e : const UnknownFailure(),
                onRetry: () => ref.invalidate(patientDashboardProvider),
              ),
              data: (data) => _Content(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data});
  final PatientDashboard data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final total = data.totalSessions;
    final done = data.completedSessions;
    // With no care-plan model there is no target session count, so "progress"
    // is simply how much of what was booked has happened.
    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress card. The mono eyebrow (`recoveryEyebrow`) is dropped.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total == 0
                    ? l10n.recoveryNoSessions
                    : l10n.recoveryPercentThrough(percent),
                style: text.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.recoveryOverall,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 13,
                      letterSpacing: 0,
                      color: AppColors.inkMid,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: text.titleSmall!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.pine,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Solid pine on a mist track, as elsewhere in the app.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Container(color: AppColors.mist),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(color: AppColors.pine),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Stats sit on a mint-tinted strip.
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColors.pinePale.withAlpha(150),
                    Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _Stat(
                        value: '$done / $total',
                        label: l10n.recoveryStatSessions,
                      ),
                      const VerticalDivider(width: 1, color: AppColors.border),
                      _Stat(
                        value: '${data.upcomingSessions}',
                        label: l10n.recoveryStatUpcoming,
                      ),
                      const VerticalDivider(width: 1, color: AppColors.border),
                      // TODO(api): streak and pain reduction need a milestones /
                      // pain-tracking model (A8 in docs/TODO_REGISTER.md).
                      _Stat(value: '—', label: l10n.recoveryStatPain),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          l10n.recoveryMilestones,
          style: text.titleMedium!.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: ApiTodoState(
            title: l10n.recoveryMilestonesSoonTitle,
            description: l10n.recoveryMilestonesSoonDesc,
            endpoint: 'milestones / pain-tracking model',
            icon: Icons.timeline_outlined,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          children: [
            Text(
              value,
              style: text.titleMedium!.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}