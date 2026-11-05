import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../../../patient/presentation/providers/care_providers.dart';
import '../../../patient/data/models/care_models.dart';
import '../providers/therapist_providers.dart';
import '../../../../core/validation/validators.dart';

/// File a complaint about a patient with the admin team.
///
/// Uses the same `POST /admin/complaints` endpoint as the patient-side report,
/// with `type: Patient` and the therapist as complainant.
class ReportPatientScreen extends ConsumerStatefulWidget {
  const ReportPatientScreen({super.key});

  @override
  ConsumerState<ReportPatientScreen> createState() =>
      _ReportPatientScreenState();
}

class _ReportPatientScreenState extends ConsumerState<ReportPatientScreen> {
  final _detailsController = TextEditingController();

  String? _patientId;
  String? _patientName;
  String _category = 'Unsafe environment';
  bool _busy = false;
  String? _error;

  /// Values, not labels: the chosen category is sent to the API as it is.
  static const _categories = [
    'Unsafe environment',
    'Harassment',
    'Repeated no-show',
    'Non-payment',
    'Other',
  ];

  String _categoryLabel(String value, AppLocalizations l10n) =>
      switch (value) {
        'Unsafe environment' => l10n.complaintUnsafeEnvironment,
        'Harassment' => l10n.complaintHarassment,
        'Repeated no-show' => l10n.complaintRepeatedNoShow,
        'Non-payment' => l10n.complaintNonPayment,
        'Other' => l10n.optionOther,
        _ => value,
      };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _detailsController.text.trim();
    if (_patientId == null) {
      setState(() => _error = context.l10n.reportPatientChoose);
      return;
    }
    final detailError = Validators.longText(
      context.l10n,
      context.l10n.fieldWhatHappened,
      min: 20,
      max: 2000,
    )(details);
    if (detailError != null) {
      setState(() => _error = detailError);
      return;
    }

    final me = ref.read(currentUserProvider);
    if (me == null) {
      setState(() => _error = context.l10n.reportPatientSignInAgain);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(careApiProvider)
          .createComplaint(
            ComplaintCreateDto(
              type: 'Patient',
              complainantId: me.id,
              complainantName: me.name,
              againstId: _patientId!,
              againstName: _patientName ?? '',
              category: _category,
              description: details,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.complaintSent)),
        );
      _close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = context.l10n.reportPatientFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go('/therapist/account');

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
            PageHeader(title: l10n.reportPatientTitle, onBack: _close),
            const SizedBox(height: 16),
            Text(
              l10n.complaintEyebrow,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.complaintHeading,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.complaintSubtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(l10n.labelPatient.toUpperCase()),
                  const SizedBox(height: 6),
                  patients.when(
                    loading: () => const SkeletonBox(
                      height: 48,
                      radius: AppRadii.full,
                    ),
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
                            onChanged: (v) => setState(() {
                              _patientId = v;
                              _patientName = list
                                  .firstWhere((p) => p.id == v)
                                  .name;
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(l10n.complaintCategoryLabel),
                  const SizedBox(height: 8),
                  ChipSelector(
                    options: _categories,
                    selected: _category,
                    display: (v) => _categoryLabel(v, l10n),
                    onSelected: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(l10n.complaintWhatHappenedLabel),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _detailsController,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: l10n.reportPatientDetailsHint,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pine,
                        foregroundColor: Colors.white,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.complaintSubmit),
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
