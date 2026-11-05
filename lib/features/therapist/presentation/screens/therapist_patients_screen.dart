import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';
import '../widgets/patient_tints.dart';

class TherapistPatientsScreen extends ConsumerWidget {
  const TherapistPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(myPatientsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.therapistPatientsEyebrow,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.therapistPatientsHeading,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: patients.when(
                loading: () => const SkeletonList(
                  count: 4,
                  itemHeight: 96,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(myPatientsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyStateView(
                      title: context.l10n.therapistPatientsEmptyTitle,
                      description: context.l10n.therapistPatientsEmptyDesc,
                      icon: Icons.people_outline,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myPatientsProvider),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _PatientRow(patient: list[i], tintIndex: i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.tintIndex});
  final MyPatientDto patient;
  final int tintIndex;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final last = p.lastVisit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            ProfileAvatar(
              initials: getInitials(p.name),
              photoUrl: p.photo,
              thumbUrl: p.photoThumb,
              tint: patientTintFor(tintIndex),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    [
                      if (p.condition.isNotEmpty) p.condition,
                      context.l10n.patientSessionCount(p.sessions),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMid,
                    ),
                  ),
                  Text(
                    // An empty last-visit string means the patient has no
                    // recorded visit, not a visit at epoch zero.
                    last == null
                        ? context.l10n.patientNoVisits
                        : context.l10n.patientLastVisit(
                            formatRelativeTime(last, context.l10n),
                          ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMute,
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
