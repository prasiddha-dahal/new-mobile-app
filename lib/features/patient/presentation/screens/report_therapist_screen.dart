import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_field.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../providers/care_providers.dart';
import '../providers/patient_providers.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/state_views.dart';

/// Files a complaint about a therapist with the admin team.
///
/// Uses the pine CTA rather than the usual amber — the prototype reserves amber
/// for commercial actions and pine for trust/admin ones.
class ReportTherapistScreen extends ConsumerStatefulWidget {
  const ReportTherapistScreen({super.key});

  @override
  ConsumerState<ReportTherapistScreen> createState() =>
      _ReportTherapistScreenState();
}

class _ReportTherapistScreenState extends ConsumerState<ReportTherapistScreen> {
  final _detailsController = TextEditingController();

  /// The therapist's **id**, not their name.
  ///
  /// This was a free-text name field and the id was sent as `''` -- which the
  /// API rejects outright (`againstId` is min_length=1), so every report came
  /// back 422 and no complaint was ever filed. Picking from the real list is
  /// what makes the feature work, and it is also the only way admin can tie a
  /// complaint to an account.
  String? _therapistId;

  String _category = 'Rude behaviour';
  int _rating = 2;
  bool _busy = false;
  String? _error;

  /// Values, not labels: `_category` is sent to the API as it is, so the
  /// list stays English and [_categoryLabel] is what the chip shows.
  static const _categories = [
    'Rude behaviour',
    'Unprofessional conduct',
    'Late / no-show',
    'Safety concern',
    'Other',
  ];

  /// Name for [id] from the loaded list, so the complaint carries both.
  String _nameFor(String id) {
    final list = ref.read(therapistListProvider).valueOrNull ?? const [];
    for (final t in list) {
      if (t.id == id) return t.name;
    }
    return '';
  }

  String _categoryLabel(String value, AppLocalizations l10n) =>
      switch (value) {
        'Rude behaviour' => l10n.complaintRudeBehaviour,
        'Unprofessional conduct' => l10n.complaintUnprofessional,
        'Late / no-show' => l10n.complaintLateNoShow,
        'Safety concern' => l10n.complaintSafety,
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
    final therapistId = _therapistId;

    if (therapistId == null || therapistId.isEmpty) {
      setState(() => _error = context.l10n.complaintPickTherapistError);
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

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(careActionsProvider)
        .reportTherapist(
          therapistId: therapistId,
          therapistName: _nameFor(therapistId),
          category: _category,
          description: details,
          rating: _rating,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    result.match((failure) => setState(() => _error = failure.message), (_) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.complaintSent)),
        );
      _close();
    });
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go('/patient/account');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Theme(
          // Rounded white fields with the sage border, shared with the auth
          // screens.
          data: appFieldTheme(Theme.of(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.xxxl,
            ),
            children: [
              // Back arrow
              AppBackButton(onPressed: _close, gutter: false,),

              // Title and a line saying what this is. The mono eyebrow
              // (`complaintEyebrow`) and the Fraunces heading
              // (`complaintHeading`) are dropped: the title already says it.
              Text(
                l10n.complaintTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.complaintSubtitle,
                style: text.bodyMedium!.copyWith(
                  height: 1.45,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A picker over the real directory, not a free-text name:
                    // the API needs the therapist's id and rejects an empty
                    // one.
                    ref
                        .watch(therapistListProvider)
                        .when(
                          loading: () => const SkeletonBox(height: 56),
                          error: (_, _) => InlineRetry(
                            message: l10n.complaintTherapistsUnavailable,
                            onRetry: () =>
                                ref.invalidate(therapistListProvider),
                          ),
                          data: (therapists) => therapists.isEmpty
                              ? Text(
                                  l10n.complaintNoTherapists,
                                  style: text.bodyMedium!.copyWith(
                                    fontSize: 13,
                                    letterSpacing: 0,
                                    color: AppColors.inkMid,
                                  ),
                                )
                              : AppChoiceField(
                                  label: l10n.fieldTherapistNameLabel,
                                  hint: l10n.complaintPickTherapistHint,
                                  // Ids are the value; names are what is
                                  // shown.
                                  options: [for (final t in therapists) t.id],
                                  initialValue: _therapistId,
                                  display: (id) => _nameFor(id),
                                  onChanged: (v) =>
                                      setState(() => _therapistId = v),
                                ),
                        ),
                    const SizedBox(height: AppSpacing.xl),

                    _Label(l10n.complaintCategoryLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _CategoryChips(
                      options: _categories,
                      selected: _category,
                      display: (v) => _categoryLabel(v, l10n),
                      onSelected: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _Label(l10n.complaintRateLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: List.generate(5, (i) {
                        final value = i + 1;
                        final filled = value <= _rating;
                        return IconButton(
                          onPressed: () => setState(() => _rating = value),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.only(right: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 34,
                            color: filled
                                ? AppColors.amberBrand
                                : Colors.black.withValues(alpha: 0.15),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _Label(l10n.complaintWhatHappenedLabel),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _detailsController,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.complaintDetailsHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AuthErrorBanner(message: _error!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit: pine, as the note on the class says.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.pine.withAlpha(90),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    // Buttons default to labelLarge (mono, spaced), so the
                    // style has to be given here.
                    textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
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
      ),
    );
  }
}

/// A field label above its control, in Inter.
class _Label extends StatelessWidget {
  const _Label(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.textTheme.titleSmall!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.ink,
      ),
    );
  }
}

/// Single-select category pills: selected = ink fill, unselected = mist.
///
/// Same inputs as the shared `ChipSelector` it replaces here.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.options,
    required this.selected,
    required this.display,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final String Function(String) display;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onSelected(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: o == selected ? AppColors.ink : AppColors.mist,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                display(o),
                style: text.titleSmall!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: o == selected ? Colors.white : AppColors.inkMid,
                ),
              ),
            ),
          ),
      ],
    );
  }
}