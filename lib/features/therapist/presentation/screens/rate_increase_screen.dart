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
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';
import '../../../../core/validation/validators.dart';

/// Ask admin for a new session rate.
///
/// The `CURRENT` figure is the therapist's real rate from
/// `GET /therapists/me/profile`. Sending the request is not possible — see
/// [_requestUnavailable].
class RateIncreaseScreen extends ConsumerStatefulWidget {
  const RateIncreaseScreen({super.key});

  @override
  ConsumerState<RateIncreaseScreen> createState() => _RateIncreaseScreenState();
}

class _RateIncreaseScreenState extends ConsumerState<RateIncreaseScreen> {
  final _rateController = TextEditingController();
  final _justificationController = TextEditingController();

  bool _seeded = false;
  String? _error;

  @override
  void dispose() {
    _rateController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  /// Fills the rate field once, the first time the profile arrives.
  ///
  /// The prototype prefills a figure above the current rate. Picking an
  /// increase on a real therapist's behalf would be inventing their ask, so the
  /// field starts at what they charge today and they raise it themselves.
  void _seed(TherapistProfileDto profile) {
    if (_seeded) return;
    _seeded = true;
    _rateController.text = profile.price == 0
        ? ''
        : profile.price.toStringAsFixed(0);
  }

  void _submit() {
    // "Greater than zero" let Rs 1 and Rs 999,999 through alike, and an
    // admin reviewing the request could not tell a typo from an intent.
    final rateError = Validators.amount(
      context.l10n,
      context.l10n.fieldProposedRate,
      min: 100,
      max: 100000,
    )(_rateController.text);
    if (rateError != null) {
      setState(() => _error = rateError);
      return;
    }
    final whyError = Validators.longText(
      context.l10n,
      context.l10n.fieldRateReason,
      min: 15,
    )(
      _justificationController.text,
    );
    if (whyError != null) {
      setState(() => _error = whyError);
      return;
    }
    setState(() => _error = null);
    _requestUnavailable(context);
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go('/therapist/account');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(therapistProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: profile.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: l10n.rateIncreaseTitle, onBack: _close),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SkeletonList(count: 3, itemHeight: 96),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              PageHeader(title: l10n.rateIncreaseTitle, onBack: _close),
              Expanded(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(therapistProfileProvider),
                ),
              ),
            ],
          ),
          data: (data) {
            _seed(data);
            final proposed = double.tryParse(_rateController.text.trim());

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                PageHeader(title: l10n.rateIncreaseTitle, onBack: _close),
                const SizedBox(height: 16),
                Text(
                  l10n.rateIncreaseEyebrow,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.rateIncreaseHeading,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.rateIncreaseSubtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.inkMid,
                  ),
                ),
                const SizedBox(height: 20),

                // --- Current vs proposed ------------------------------------
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _RateCell(
                          label: l10n.rateCurrentLabel,
                          value: formatCurrency(data.price, l10n),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RateCell(
                          label: l10n.rateProposedLabel,
                          value: proposed == null
                              ? '—'
                              : formatCurrency(proposed, l10n),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Request form -------------------------------------------
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FieldLabel(l10n.rateIncreaseNewRateLabel),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _rateController,
                        keyboardType: TextInputType.number,
                        // PROPOSED mirrors the field as it is typed.
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.rateIncreaseAmountHint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FieldLabel(l10n.rateJustificationLabel),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _justificationController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: l10n.rateIncreaseReasonHint,
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
                          onPressed: _submit,
                          child: Text(l10n.rateIncreaseSubmit),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A rate change has no request/approval endpoint. Writing the new price
  /// straight to the profile would bypass the admin review this screen exists
  /// for, so the request stops here instead of looking like it was filed.
  /// TODO(api): rate-increase request + approval (A16 in docs/TODO_REGISTER.md).
  static void _requestUnavailable(BuildContext context) =>
      showUnavailableDialog(
        context,
        title: context.l10n.rateIncreaseUnavailableTitle,
        body: context.l10n.rateIncreaseUnavailableBody,
      );
}

class _RateCell extends StatelessWidget {
  const _RateCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 20,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
