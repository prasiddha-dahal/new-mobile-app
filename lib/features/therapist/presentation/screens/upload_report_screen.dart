import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../providers/therapist_providers.dart';

/// Share a medical file with a patient.
///
/// `POST /reports` is multipart-only and needs a real file, which requires a
/// file-picker package the project does not depend on yet. The form is complete
/// and the patient list is real; only the file step and submit are blocked.
/// TODO(api): wire POST /reports once a file picker is added (needs file_picker
/// or image_picker in pubspec).
class UploadReportScreen extends ConsumerStatefulWidget {
  const UploadReportScreen({super.key});

  @override
  ConsumerState<UploadReportScreen> createState() => _UploadReportScreenState();
}

class _UploadReportScreenState extends ConsumerState<UploadReportScreen> {
  final _notesController = TextEditingController();
  String? _patientId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _uploadUnavailable() => showUnavailableDialog(
    context,
    title: context.l10n.uploadReportUnavailableTitle,
    body: context.l10n.uploadReportUnavailableBody,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final patients = ref.watch(myPatientsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            PageHeader(
              title: l10n.uploadReportTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/therapist/account'),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.uploadReportEyebrow,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.uploadReportHeading,
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('PATIENT'),
                  const SizedBox(height: 6),
                  patients.when(
                    loading: () => const SkeletonBox(height: 48, radius: AppRadii.full),
                    error: (e, _) => ErrorStateView(
                      failure: e is Failure ? e : const UnknownFailure(),
                      onRetry: () => ref.invalidate(myPatientsProvider),
                      compact: true,
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return Text(
                          l10n.therapistNoPatients,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMid,
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _patientId,
                            isExpanded: true,
                            hint: Text(
                              l10n.choosePatient,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.inkMute,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            items: [
                              for (final p in list)
                                DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                            ],
                            onChanged: (v) => setState(() => _patientId = v),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(l10n.labelFile),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _uploadUnavailable,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.pinePale,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(
                          color: AppColors.pine.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('📎', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.uploadReportSelectHint,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(l10n.uploadReportNotesLabel),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: l10n.uploadReportNotesHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _uploadUnavailable,
                      child: Text(l10n.uploadReportSubmit),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.uploadReportRecent,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            AppCard(
              child: ApiTodoState(
                title: l10n.uploadReportEmptyTitle,
                description: l10n.uploadReportEmptyDesc,
                endpoint: 'POST /reports (multipart)',
                icon: Icons.upload_file_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

