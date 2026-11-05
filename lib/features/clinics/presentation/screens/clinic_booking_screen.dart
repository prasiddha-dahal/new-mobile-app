import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/clinic.dart';
import '../providers/clinic_providers.dart';

/// Confirm a clinic visit.
///
/// The screen is complete, but submitting it cannot be: `Session` has no
/// `clinicId`, so the visit has nowhere to go. Confirming surfaces the typed
/// failure from the repository rather than routing to a confirmation for a
/// booking that was never made.
class ClinicBookingScreen extends ConsumerStatefulWidget {
  const ClinicBookingScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  ConsumerState<ClinicBookingScreen> createState() =>
      _ClinicBookingScreenState();
}

class _ClinicBookingScreenState extends ConsumerState<ClinicBookingScreen> {
  String _paymentMethod = 'ESEWA';
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);

    final result = await ref
        .read(clinicActionsProvider)
        .bookVisit(clinicId: widget.clinicId, paymentMethod: _paymentMethod);

    if (!mounted) return;
    setState(() => _busy = false);

    result.match(
      (failure) => showUnavailableDialog(
        context,
        title: context.l10n.clinicBookingUnavailableTitle,
        body: context.l10n.clinicBookingUnavailableBody(failure.message),
      ),
      // `/clinics/booked` reads `clinic`, `address`, `hours`, `date` and
      // `time`. It has never read `ref`, so the receipt would have shown an
      // em dash where the address goes. Latent today only because confirm
      // always fails; this is the line that runs the hour the endpoint lands.
      // `date` and `time` are genuinely not known — there is no clinic-slots
      // endpoint — and the receipt already degrades to "as scheduled" for a
      // missing date rather than inventing one.
      (_) {
        final clinic = ref
            .read(clinicDetailProvider(widget.clinicId))
            .valueOrNull;
        final address = clinic == null
            ? ''
            : (clinic.address.trim().isEmpty
                  ? clinic.locationLabel
                  : clinic.address);
        context.go(
          Uri(
            path: '/clinics/booked',
            queryParameters: {
              if (clinic != null) 'clinic': clinic.name,
              if (address.isNotEmpty) 'address': address,
            },
          ).toString(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinicAsync = ref.watch(clinicDetailProvider(widget.clinicId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: clinicAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: context.l10n.clinicBookingTitle,
                onBack: () => _pop(context),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SkeletonList(count: 3, itemHeight: 96),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              PageHeader(
                title: context.l10n.clinicBookingTitle,
                onBack: () => _pop(context),
              ),
              Expanded(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () =>
                      ref.invalidate(clinicDetailProvider(widget.clinicId)),
                ),
              ),
            ],
          ),
          data: (clinic) => _buildForm(context, clinic),
        ),
      ),
      bottomNavigationBar: clinicAsync.hasValue
          ? _ConfirmBar(busy: _busy, onPressed: _confirm)
          : null,
    );
  }

  void _pop(BuildContext context) => context.canPop()
      ? context.pop()
      : context.go('/clinics/${widget.clinicId}');

  Widget _buildForm(BuildContext context, Clinic clinic) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        PageHeader(
          title: l10n.clinicBookingTitle,
          onBack: () => _pop(context),
        ),
        const SizedBox(height: 4),

        // --- Summary -------------------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.clinicVisitSummary,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              _SummaryRow(label: l10n.clinicLabelClinic, value: clinic.name),
              const SizedBox(height: 8),
              _SummaryRow(
                label: l10n.labelAddress,
                value: clinic.address.trim().isEmpty
                    ? clinic.locationLabel
                    : clinic.address,
              ),
              const SizedBox(height: 8),
              // No clinic slots endpoint means no date was ever chosen, and the
              // clinic model has no consultation fee to total up. Both stay
              // unfilled instead of being made up.
              // TODO(api): clinic slots and a consultation price on Clinic
              // (A12 in docs/TODO_REGISTER.md).
              _SummaryRow(
                label: l10n.clinicLabelDateTime,
                value: l10n.clinicNotScheduled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Payment method -------------------------------------------------
        Text(
          l10n.bookingPaymentLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        _PaymentOption(
          label: l10n.payoutEsewa,
          value: 'ESEWA',
          groupValue: _paymentMethod,
          onSelect: (v) => setState(() => _paymentMethod = v),
        ),
        const SizedBox(height: 8),
        _PaymentOption(
          label: l10n.payoutKhalti,
          value: 'KHALTI',
          groupValue: _paymentMethod,
          onSelect: (v) => setState(() => _paymentMethod = v),
        ),
        const SizedBox(height: 8),
        _PaymentOption(
          label: l10n.paymentPayAtClinic,
          value: 'CASH',
          groupValue: _paymentMethod,
          onSelect: (v) => setState(() => _paymentMethod = v),
        ),
        const SizedBox(height: 16),

        // --- Notice ---------------------------------------------------------
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.amberPale,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Text(
            l10n.clinicArriveEarly,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: Color(0xFF8A5A14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMid),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelect,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected
                ? AppColors.pine
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.pine
                      : Colors.black.withValues(alpha: 0.2),
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.pine,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.l10n.clinicConfirmVisit),
            ),
          ),
        ),
      ),
    );
  }
}
