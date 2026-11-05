import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../domain/entities/package_purchase.dart';
import '../../domain/entities/therapy_package.dart';
import '../providers/package_providers.dart';
import 'package_card.dart';
import 'package_visuals.dart';

/// Opens the package detail → confirm → buy flow.
///
/// A bottom sheet rather than a route so the module needs no router changes;
/// see docs/packages_integration.md.
Future<void> showPackageDetailSheet(
  BuildContext context, {
  required TherapyPackage package,
  int tintIndex = 0,
  VoidCallback? onViewMyPackages,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => PackageDetailSheet(
      package: package,
      tintIndex: tintIndex,
      onViewMyPackages: onViewMyPackages,
    ),
  );
}

/// Payment methods the backend accepts. It records a `Payment` row, it does not
/// charge anything — real capture is TODO(api) A18.
/// Wire values, not labels: these are what the API stores.
const _paymentMethods = <String>['ESEWA', 'KHALTI', 'CASH'];

String _paymentLabel(String value, AppLocalizations l10n) => switch (value) {
  'ESEWA' => l10n.payoutEsewa,
  'KHALTI' => l10n.payoutKhalti,
  'CASH' => l10n.paymentCashOnVisit,
  _ => value,
};

/// The logo for a payment method, or null when there is none.
String? _paymentLogo(String value) => switch (value) {
  'ESEWA' => 'assets/images/paymentLogo/esewa-logo.webp',
  'KHALTI' => 'assets/images/paymentLogo/khalti-logo.webp',
  'CASH' => 'assets/images/paymentLogo/cash.png',
  _ => null,
};

enum _Stage { details, confirm, done }

class PackageDetailSheet extends ConsumerStatefulWidget {
  const PackageDetailSheet({
    super.key,
    required this.package,
    this.tintIndex = 0,
    this.onViewMyPackages,
  });

  final TherapyPackage package;
  final int tintIndex;

  /// Wired by the integrator to navigate to My packages; when null the success
  /// panel just closes.
  final VoidCallback? onViewMyPackages;

  @override
  ConsumerState<PackageDetailSheet> createState() => _PackageDetailSheetState();
}

class _PackageDetailSheetState extends ConsumerState<PackageDetailSheet> {
  _Stage _stage = _Stage.details;
  String _paymentMethod = 'ESEWA';
  bool _submitting = false;
  String? _error;
  PackagePurchase? _purchase;

  TherapyPackage get _package => widget.package;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(packageActionsProvider)
        .purchase(packageId: _package.id, paymentMethod: _paymentMethod);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _submitting = false;
        _error = _messageFor(failure, context.l10n);
      }),
      (purchase) => setState(() {
        _submitting = false;
        _purchase = purchase;
        _stage = _Stage.done;
      }),
    );
  }

  /// Turns a typed failure into something a patient can act on.
  ///
  /// 403 ("only patients can purchase") arrives as [UnauthorizedFailure] and
  /// 400 (gone, inactive, or already holding an active package) as
  /// [ValidationFailure] — both carry the backend's own sentence, which is more
  /// specific than anything generic written here, so it is preferred when set.
  static String _messageFor(Failure failure, AppLocalizations l10n) {
    final detail = failure.message.trim();
    return switch (failure) {
      UnauthorizedFailure() when detail.isEmpty =>
        l10n.packagesErrorPatientOnly,
      ValidationFailure() when detail.isEmpty => l10n.packagesErrorUnavailable,
      NotFoundFailure() => l10n.packagesErrorNotEnabled,
      _ => detail.isEmpty ? l10n.packagesErrorGeneric : detail,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                switch (_stage) {
                  _Stage.details => _details(),
                  _Stage.confirm => _confirmStep(),
                  _Stage.done => _success(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Details ────────────────────────────────────────────────────────

  Widget _details() {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PackageIconTile(
              icon: _package.icon,
              tintIndex: widget.tintIndex,
              size: 56,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_package.tag.isNotEmpty) ...[
                    StatusTag(label: _package.tag, tone: TagTone.neutral),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    _package.name,
                    style: text.titleLarge!.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_package.blurb.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(_package.blurb, style: text.bodyMedium!.copyWith(height: 1.5)),
        ],
        if (_package.points.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            l10n.packagesIncluded,
            style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final point in _package.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.pine,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: text.bodyMedium!.copyWith(
                        height: 1.45,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        _TermsBox(package: _package),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: l10n.packagesBuy,
          onPressed: () => setState(() => _stage = _Stage.confirm),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.packagesBuyNote,
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

  // ── Confirm ────────────────────────────────────────────────────────

  /// The money step: everything being committed to, in words, before the call.
  Widget _confirmStep() {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/patient/packages'),
          gutter: false,
        ),
        Text(
          l10n.packagesConfirmTitle,
          style: text.titleLarge!.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.packagesConfirmSubtitle,
          style: text.bodyMedium!.copyWith(height: 1.45),
        ),
        const SizedBox(height: 16),

        // What is being bought
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: l10n.packagesLabelPackage,
                value: _package.name,
              ),
              _SummaryRow(
                label: l10n.packagesLabelSessions,
                value: _package.sessionCount > 0
                    ? l10n.packagesSessionCount(_package.sessionCount)
                    : l10n.packagesNotSpecified,
              ),
              _SummaryRow(
                label: l10n.packagesLabelValidFor,
                value: _package.validityDays > 0
                    ? l10n.packagesValidFromToday(_package.validityDays)
                    : l10n.packagesNotSpecified,
              ),
              if (_package.cadence.trim().isNotEmpty)
                _SummaryRow(
                  label: l10n.packagesLabelBilled,
                  value: _package.cadence.trim(),
                ),
              const Divider(height: 24, color: AppColors.border),
              _SummaryRow(
                label: l10n.packagesLabelTotal,
                value: formatCurrency(_package.price.toDouble(), l10n),
                emphasis: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Payment
        Text(
          l10n.bookingPaymentLabel,
          style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final value in _paymentMethods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PaymentOption(
              label: _paymentLabel(value, l10n),
              logo: _paymentLogo(value),
              selected: _paymentMethod == value,
              onTap: _submitting
                  ? null
                  : () => setState(() => _paymentMethod = value),
            ),
          ),
        const SizedBox(height: 2),
        Text(
          l10n.packagesPaymentNote,
          style: text.bodySmall!.copyWith(height: 1.4),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerPale,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: text.bodySmall!.copyWith(
                      height: 1.4,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _PrimaryButton(
          label: l10n.packagesConfirmAndPay(
            formatCurrency(_package.price.toDouble(), l10n),
          ),
          loading: _submitting,
          onPressed: _confirm,
        ),
        const SizedBox(height: 4),
        _GhostButton(
          label: l10n.actionBackShort,
          onPressed: _submitting
              ? null
              : () => setState(() => _stage = _Stage.details),
        ),
      ],
    );
  }

  // ── Success ────────────────────────────────────────────────────────

  Widget _success() {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final purchase = _purchase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.pine,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.packagesActivated,
                style: text.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          purchase == null
              ? l10n.packagesActivatedGeneric(_package.name)
              : '${l10n.packagesActivatedDetail(purchase.packageName, purchase.sessionsRemaining, purchase.sessionsTotal)}'
                    '${purchase.expiresAt == null ? '' : l10n.packagesActivatedUntil(formatShortDate(purchase.expiresAt!, l10n))}.',
          style: text.bodyMedium!.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: l10n.packagesViewMine,
          onPressed: () {
            Navigator.of(context).pop();
            widget.onViewMyPackages?.call();
          },
        ),
        const SizedBox(height: 4),
        _GhostButton(
          label: l10n.actionDone,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────

/// The full-width pine button. Shows a spinner while [loading].
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pine,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.pine.withAlpha(90),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          // Buttons default to labelLarge (mono, spaced), so the style has to
          // be given here.
          textStyle: text.titleMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// A quiet text button for the secondary action under a primary one.
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkMid,
          textStyle: text.titleSmall,
        ),
        child: Text(label),
      ),
    );
  }
}

class _TermsBox extends StatelessWidget {
  const _TermsBox({required this.package});

  final TherapyPackage package;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.pinePale.withAlpha(150),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCurrency(package.price.toDouble(), context.l10n),
            style: text.titleLarge!.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            packageTermsLine(package, context.l10n),
            style: text.bodyMedium!.copyWith(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: emphasis
                  ? text.titleLarge!.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )
                  : text.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.logo,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? logo;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  AppColors.pinePale.withAlpha(110),
                  Colors.white,
                )
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? AppColors.pine : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Method logo
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.row),
                border: Border.all(color: AppColors.border),
              ),
              child: logo == null
                  ? const Icon(Icons.payments_outlined, color: AppColors.pine)
                  : Image.asset(
                      logo!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.payments_outlined,
                        color: AppColors.pine,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: text.titleSmall!.copyWith(fontSize: 15),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? AppColors.pine : AppColors.inkMute,
            ),
          ],
        ),
      ),
    );
  }
}
