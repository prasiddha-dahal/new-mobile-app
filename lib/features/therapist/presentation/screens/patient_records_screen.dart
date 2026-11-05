import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/nav_bars.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../patient/presentation/widgets/therapist_row.dart'
    show avatarTintFor;
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';

/// Session archive with handoff notes.
///
/// The roster is real (`GET /patients/my-patients`). There is no records entity
/// behind it, so the archive itself — notes and the SHAREABLE/PRIVATE flag —
/// lives in the detail sheet as an API-TODO.
/// TODO(api): patient-records sharing (A17 in docs/TODO_REGISTER.md).
class PatientRecordsScreen extends ConsumerWidget {
  const PatientRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(myPatientsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            navBarReservedHeight,
          ),
          children: [
            PageHeader(
              title: context.l10n.recordsTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/therapist/account'),
              right: _AddPill(onTap: () => _recordsUnavailable(context)),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.recordsEyebrow,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.recordsHeading,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.recordsSubtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: 20),
            patients.when(
              loading: () => const SkeletonList(count: 4, itemHeight: 76),
              error: (e, _) => ErrorStateView(
                failure: e is Failure ? e : const UnknownFailure(),
                onRetry: () => ref.invalidate(myPatientsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyStateView(
                    title: context.l10n.recordsEmptyTitle,
                    description: context.l10n.recordsEmptyDesc,
                    icon: Icons.folder_outlined,
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _RecordRow(patient: list[i], tintIndex: i),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Adding a record needs somewhere to store it. Nothing on the backend holds
  /// a diagnosis, a treatment plan or a handoff note, so the pill explains
  /// rather than opening a form that could not save.
  static void _recordsUnavailable(BuildContext context) =>
      showUnavailableDialog(
        context,
        title: context.l10n.recordsUnavailableTitle,
        body: context.l10n.recordsUnavailableBody,
      );
}

/// The `+ Add` pill in the app bar's trailing slot.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.pine,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          context.l10n.recordsAdd,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.patient, required this.tintIndex});

  final MyPatientDto patient;
  final int tintIndex;

  @override
  Widget build(BuildContext context) {
    final lastVisit = patient.lastVisit;
    final condition = patient.condition.isEmpty
        ? context.l10n.recordsNoCondition
        : patient.condition;

    return AppCard(
      onTap: () => showRecordSheet(context, patient: patient),
      child: Row(
        children: [
          ProfileAvatar(
            initials: getInitials(patient.name),
            photoUrl: patient.photo,
            thumbUrl: patient.photoThumb,
            size: 40,
            tint: avatarTintFor(tintIndex),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  context.l10n.recordsConditionSessions(
                    condition,
                    context.l10n.patientSessionCount(patient.sessions),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.inkMid),
                ),
                Text(
                  lastVisit == null
                      ? context.l10n.recordsNoRecordedVisit
                      : context.l10n.patientLastShort(
                          formatDayLabel(lastVisit, context.l10n),
                        ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          // The prototype's trailing SHAREABLE / PRIVATE badge is deliberately
          // absent: no record exists to carry a sharing flag, and a badge here
          // would assert a sharing state nobody set.
          const Text(
            '›',
            style: TextStyle(fontSize: 18, color: AppColors.inkMute),
          ),
        ],
      ),
    );
  }
}

/// Record detail for one patient.
///
/// The identifying rows come from the my-patients row itself; everything the
/// screen exists for — diagnosis, treatment plan, progress, handoff notes and
/// the SHAREABLE/PRIVATE toggle — has no endpoint, so the body is an
/// [ApiTodoState] rather than a set of empty fields and dead buttons.
Future<void> showRecordSheet(
  BuildContext context, {
  required MyPatientDto patient,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Push onto the root navigator: the shell's bottom nav would
    // otherwise paint over a sheet opened on the shell's own navigator.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _RecordSheet(patient: patient),
  );
}

class _RecordSheet extends StatelessWidget {
  const _RecordSheet({required this.patient});
  final MyPatientDto patient;

  @override
  Widget build(BuildContext context) {
    final lastVisit = patient.lastVisit;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              patient.name,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 18,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AGE is not on the my-patients row and there is no patient
                    // detail endpoint for a therapist, so it is left out.
                    _DetailRow(
                      label: context.l10n.labelContact,
                      value: patient.phone.isEmpty ? '—' : patient.phone,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: context.l10n.labelCondition,
                      value: patient.condition.isEmpty
                          ? '—'
                          : patient.condition,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: context.l10n.labelSessions,
                      value: '${patient.sessions}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: context.l10n.recordsLastVisitLabel,
                      value: lastVisit == null
                          ? '—'
                          : formatDayLabel(lastVisit, context.l10n),
                    ),
                    const SizedBox(height: 8),
                    ApiTodoState(
                      title: context.l10n.recordsWrittenSoonTitle,
                      description: context.l10n.recordsWrittenSoonDesc,
                      endpoint: 'GET /patients/{id}/records',
                      icon: Icons.description_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
