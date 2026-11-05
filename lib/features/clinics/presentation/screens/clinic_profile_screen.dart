import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/clinic.dart';
import '../providers/clinic_providers.dart';

/// Clinic detail.
///
/// The prototype pairs this with a date and time picker. There is no clinic
/// availability endpoint, so that section renders an [ApiTodoState] instead of
/// a grid of times nobody can honour.
class ClinicProfileScreen extends ConsumerWidget {
  const ClinicProfileScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinicAsync = ref.watch(clinicDetailProvider(clinicId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: clinicAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onBack: () => _pop(context)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SkeletonList(count: 3, itemHeight: 96),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              _TopBar(onBack: () => _pop(context)),
              Expanded(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(clinicDetailProvider(clinicId)),
                ),
              ),
            ],
          ),
          data: (clinic) => _buildContent(context, clinic),
        ),
      ),
      bottomNavigationBar: clinicAsync.hasValue
          ? _ContinueBar(onPressed: () => context.go('/clinics/$clinicId/book'))
          : null,
    );
  }

  void _pop(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/clinics');

  Widget _buildContent(BuildContext context, Clinic clinic) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    TextStyle sectionStyle() => text.titleMedium!.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: AppColors.ink,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        _TopBar(onBack: () => _pop(context), padded: false),

        // --- Header --------------------------------------------------------
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mint tile with an icon in place of the hospital emoji.
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        AppColors.pinePale.withAlpha(150),
                        Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_hospital_outlined,
                      size: 28,
                      color: AppColors.pine,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clinic.name,
                          style: text.titleMedium!.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: 0,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // The prototype shows "· 1.2 km" after the location and
                        // a "★ 4.9 (214 reviews)" line beneath it. Clinics
                        // carry neither a distance nor reviews.
                        // TODO(api): rating/review count and distance on Clinic
                        // (A12 in docs/TODO_REGISTER.md).
                        Text(
                          clinic.locationLabel,
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
              const SizedBox(height: AppSpacing.lg),
              Column(
                // This card is a child of a vertical ListView, whose children
                // have unbounded height. Stretching across that unbounded
                // cross-axis can fail during layout/paint and leave only the
                // fixed booking bar visible. Let each fact tile size itself.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The second tile is `CONSULTATION · from Rs 1,200` in the
                  // prototype. Clinics have no price field, so the phone number
                  // — which they do have — takes the slot.
                  _InfoTile(
                    label: l10n.clinicOpeningHours,
                    value: clinic.hours,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoTile(label: l10n.labelPhone, value: clinic.phone),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // --- Services ------------------------------------------------------
        // FACILITIES (parking, wheelchair access, female therapist) is the next
        // section in the prototype; the clinic model has no facilities field, so
        // it is left out rather than guessed at.
        // TODO(api): facilities on Clinic (A12 in docs/TODO_REGISTER.md).
        if (clinic.services.isNotEmpty) ...[
          Text(l10n.labelServices, style: sectionStyle()),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final service in clinic.services)
                StatusTag(label: service, tone: TagTone.green),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],

        // --- Address -------------------------------------------------------
        if (clinic.address.trim().isNotEmpty) ...[
          Text(l10n.labelAddress, style: sectionStyle()),
          const SizedBox(height: AppSpacing.sm),
          Text(
            clinic.address,
            style: text.bodyMedium!.copyWith(
              fontSize: 14,
              height: 1.45,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],

        // --- Date & time ---------------------------------------------------
        Text(l10n.clinicPickDate, style: sectionStyle()),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: ApiTodoState(
            title: l10n.clinicTimesSoonTitle,
            description: clinic.phone.trim().isEmpty
                ? l10n.clinicTimesSoonDesc
                : l10n.clinicTimesSoonCall(clinic.phone),
            endpoint: 'GET /clinics/{id}/slots',
            icon: Icons.event_available_outlined,
          ),
        ),
      ],
    );
  }
}

/// Back arrow with the page title under it.
///
/// [padded] adds the page gutter; the data state already sits inside a padded
/// `ListView`, the loading and error states do not.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, this.padded = true});

  final VoidCallback onBack;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final gutter = padded ? AppSpacing.page : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: padded ? 8 : 0),
          child: IconButton(
            onPressed: onBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            padding: padded ? null : EdgeInsets.zero,
            alignment: padded ? null : Alignment.centerLeft,
            icon: const Icon(Icons.arrow_back, size: 28, color: AppColors.ink),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.lg),
          child: Text(
            context.l10n.clinicTitle,
            style: text.titleLarge!.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// One tile in the two-column facts grid under the clinic name.
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.pinePale.withAlpha(150),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.bodySmall!.copyWith(
              fontSize: 12,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '—' : value,
            style: text.titleSmall!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
              letterSpacing: 0,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed bottom CTA bar.
class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      color: AppColors.cream,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pine,
                foregroundColor: Colors.white,
                // Buttons default to labelLarge (mono, spaced).
                textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: Text(context.l10n.clinicContinueToBooking),
            ),
          ),
        ),
      ),
    );
  }
}
