import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../../../patient/presentation/providers/patient_providers.dart'
    show formatDateKey;
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';
import '../../../../core/validation/validators.dart';

/// Request urgent leave. An admin approves it — the calendar is not blocked
/// straight away, which the copy makes clear.
class DayOffScreen extends ConsumerStatefulWidget {
  const DayOffScreen({super.key});

  @override
  ConsumerState<DayOffScreen> createState() => _DayOffScreenState();
}

class _DayOffScreenState extends ConsumerState<DayOffScreen> {
  final _detailsController = TextEditingController();

  DateTime? _date;
  String _reason = 'Medical emergency';
  bool _busy = false;
  String? _error;

  /// Values, not labels: the chosen reason is sent to the API as it is.
  static const _reasons = ['Medical emergency', 'Family', 'Travel', 'Other'];

  String _reasonLabel(String value, AppLocalizations l10n) => switch (value) {
    'Medical emergency' => l10n.dayOffReasonMedical,
    'Family' => l10n.dayOffReasonFamily,
    'Travel' => l10n.dayOffReasonTravel,
    'Other' => l10n.optionOther,
    _ => value,
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final dateError = Validators.notInThePast(
      context.l10n,
      context.l10n.fieldDayOffDate,
    )(_date);
    if (dateError != null) {
      setState(() => _error = dateError);
      return;
    }
    // The reason reaches an admin, so an over-long one is trimmed at source
    // rather than truncated somewhere downstream.
    final detailError = Validators.optional(
      Validators.maxLength(context.l10n, context.l10n.fieldDetails, 300),
    )(_detailsController.text);
    if (detailError != null) {
      setState(() => _error = detailError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final details = _detailsController.text.trim();
    final result = await ref
        .read(therapistActionsProvider)
        .requestDayOff(
          dateFrom: formatDateKey(_date!),
          dateTo: formatDateKey(_date!),
          partsOfDay: const ['Morning', 'Afternoon', 'Evening'],
          reason: details.isEmpty
              ? _reason
              : context.l10n.dayOffReasonDetail(_reason, details),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    result.match((failure) => setState(() => _error = failure.message), (_) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.dayOffSent)),
        );
      setState(() {
        _date = null;
        _detailsController.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final requests = ref.watch(blockRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            PageHeader(
              title: l10n.dayOffTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/therapist/account'),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dayOffEyebrow,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.dayOffHeading,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.dayOffSubtitle,
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
                  FieldLabel(l10n.dayOffDateLabel),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _date == null
                                  ? l10n.dayOffChooseDate
                                  : formatShortDate(_date!, l10n),
                              style: TextStyle(
                                fontSize: 14,
                                color: _date == null
                                    ? AppColors.inkMute
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppColors.inkMute,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(l10n.fieldReasonLabel),
                  const SizedBox(height: 8),
                  ChipSelector(
                    options: _reasons,
                    selected: _reason,
                    display: (v) => _reasonLabel(v, l10n),
                    onSelected: (v) => setState(() => _reason = v),
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(l10n.dayOffDetailsLabel),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _detailsController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: l10n.dayOffDetailsHint,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(
                          color: AppColors.pine,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.ink,
                              ),
                            )
                          : Text(l10n.dayOffSubmit),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.dayOffRecent,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            requests.when(
              loading: () => const SkeletonList(count: 2, itemHeight: 72),
              error: (e, _) => AppCard(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(blockRequestsProvider),
                  compact: true,
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return AppCard(
                    child: Text(
                      l10n.dayOffNoRequests,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMid,
                      ),
                    ),
                  );
                }
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        _RequestRow(request: list[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});
  final BlockRequestItemDto request;

  @override
  Widget build(BuildContext context) {
    final label = request.dateFrom.isEmpty
        ? request.reason
        : context.l10n.dayOffDateReason(
            formatDayLabelFromString(request.dateFrom, context.l10n),
            request.reason,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  // The key already existed — it is this screen's own title.
                  context.l10n.dayOffTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusTag(
            label: request.status.toUpperCase(),
            tone: switch (request.status.toLowerCase()) {
              'approved' => TagTone.green,
              'rejected' => TagTone.red,
              _ => TagTone.amber,
            },
          ),
        ],
      ),
    );
  }
}
