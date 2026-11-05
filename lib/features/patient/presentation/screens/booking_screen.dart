
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/location/geo_point.dart';
import '../../../../core/location/place_description.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/system_bar_inset.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rewards/presentation/providers/points_providers.dart';
import '../providers/patient_profile_providers.dart';
import '../providers/patient_providers.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    required this.therapistId,
    required this.date,
    required this.time,
  });

  final String therapistId;

  /// YYYY-MM-DD, chosen on the profile screen.
  final String date;

  /// HH:MM, chosen on the profile screen.
  final String time;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  String _paymentMethod = 'esewa';

  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();

  /// The visit's exact point, when the patient chose their current location.
  /// Null for a typed address.
  GeoPoint? _pin;

  bool _submitting = false;
  bool _prefilled = false;
  bool _showAddressErrors = false;

  String? _prefilledText;

  final _addressFormKey = GlobalKey<FormState>();

  /// Points the patient chose to spend.
  int _pointsToUse = 0;

  @override
  void initState() {
    super.initState();

    _addressController.addListener(() {
      if (!_showAddressErrors &&
          _prefilledText != null &&
          _addressController.text != _prefilledText) {
        setState(() => _showAddressErrors = true);
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final therapist = ref.watch(
      therapistDetailProvider(widget.therapistId),
    );

    final user = ref.watch(currentUserProvider);
    final feePercent = ref.watch(platformFeePercentProvider);

    // Total fee includes the platform fee.
    // The platform fee is not displayed separately.
    final percent = feePercent.valueOrNull;
    final sessionFee = therapist.valueOrNull?.fee;

    final pointToNpr =
        ref.watch(pointBalanceProvider).valueOrNull?.pointToNpr ?? 1.0;

    final double? total = percent == null || sessionFee == null
        ? null
        : bookingTotal(
            sessionFee: sessionFee,
            percent: percent,
            points: _pointsToUse,
            pointToNpr: pointToNpr,
          );

    // Prefill the address from the patient's saved profile.
    final profile = ref.watch(patientProfileProvider);
    final savedAddress = profile.valueOrNull?.address;

    if (!_prefilled && _addressController.text.isEmpty) {
      final home = savedAddress?.trim() ?? '';
      final city = user?.city?.trim() ?? '';

      if (home.isNotEmpty) {
        _prefilledText = home;
        _addressController.text = home;
        _prefilled = true;
      } else if (city.isNotEmpty && !profile.isLoading) {
        _prefilledText = city;
        _addressController.text = city;
        _prefilled = true;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: therapist.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                onBack: () => context.pop(),
                title: l10n.bookingTitle,
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
                onBack: () => context.pop(),
                title: l10n.bookingTitle,
              ),
              Expanded(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(
                    therapistDetailProvider(widget.therapistId),
                  ),
                ),
              ),
            ],
          ),
          data: (t) {
            final where = [
              if (t.workplace != null && t.workplace!.name.isNotEmpty)
                t.workplace!.name,
              if (t.city.isNotEmpty) t.city,
            ].join(', ');

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 28,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Screen title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      l10n.reviewAndConfirm,
                      style: AppTypography.textTheme.titleLarge?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Therapist information
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppRadii.card,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ProfileAvatar(
                                initials: t.initials,
                                photoUrl: t.photoUrl,
                                thumbUrl: t.photoThumbUrl,
                                size: 56,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: AppTypography.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      t.specialty.isNotEmpty
                                          ? t.specialty
                                          : 'Physiotherapist',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.inkMid,
                                      ),
                                    ),
                                    if (where.isNotEmpty)
                                      Text(
                                        'at $where',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkMute,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Visit details
                        _DetailRow(
                          icon: Icons.home_outlined,
                          value: l10n.homeVisit,
                        ),
                        const SizedBox(height: 14),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          value: formatDayLabelFromString(
                            widget.date,
                            l10n,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailRow(
                          icon: Icons.access_time,
                          value: formatTime12h(widget.time),
                        ),

                        const SizedBox(height: 20),

                        // Visit address
                        Form(
                          key: _addressFormKey,
                          autovalidateMode: _showAddressErrors
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          child: LocationAutocompleteField(
                            validator: Validators.visitAddress(
                              l10n,
                              cities: supportedCities,
                            ),
                            controller: _addressController,
                            detail: LocationDetail.address,
                            pinnable: true,
                            onPinChanged: (point) => _pin = point,
                            maxLines: 1,
                            textCapitalization:
                                TextCapitalization.sentences,
                            style: AppTypography.textTheme.bodyMedium
                                ?.copyWith(
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.bookingAddressLabel,
                              hintText: l10n.bookingAddressHint,
                              labelStyle: AppTypography.textTheme.bodySmall,
                              hintStyle: AppTypography.textTheme.bodySmall,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.tile,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.tile,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.tile,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.pine,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Landmark
                        TextField(
                          controller: _landmarkController,
                          maxLength: 300,
                          textCapitalization:
                              TextCapitalization.sentences,
                          style: AppTypography.textTheme.bodyMedium
                              ?.copyWith(
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.bookingLandmarkLabel,
                            hintText: l10n.bookingLandmarkHint,
                            labelStyle: AppTypography.textTheme.bodySmall,
                            hintStyle: AppTypography.textTheme.bodySmall,
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.pine,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Payment method
                        Text(
                          l10n.choosePaymentMethod,
                          style: AppTypography.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          total == null
                              ? '${l10n.amountToPay}: …'
                              : '${l10n.amountToPay}: '
                                  '${formatCurrency(total, l10n)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMid,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppRadii.card,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              for (final entry in [
                                (
                                  l10n.esewa,
                                  l10n.payoutEsewa,
                                  'assets/images/paymentLogo/esewa-logo.webp',
                                ),
                                (
                                  l10n.khalti,
                                  l10n.payoutKhalti,
                                  'assets/images/paymentLogo/khalti-logo.webp',
                                ),
                                (
                                  'cash',
                                  l10n.paymentCashOnVisit,
                                  'assets/images/paymentLogo/cash.png',
                                ),
                              ]) ...[
                                if (entry.$1 != 'esewa')
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                _PaymentMethodTile(
                                  label: entry.$2,
                                  logoPath: entry.$3,
                                  active: _paymentMethod == entry.$1,
                                  onTap: () {
                                    setState(() {
                                      _paymentMethod = entry.$1;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (_paymentMethod != 'cash') ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.bookingWalletCheckoutNote,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMute,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Reward points
                        _PointsRow(
                          fee: t.fee,
                          selected: _pointsToUse,
                          onChanged: (v) {
                            setState(() => _pointsToUse = v);
                          },
                        ),

                        const SizedBox(height: 20),

                        // Total fee (consultation + platform fee)
                        Text(
                          l10n.totalFee,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMid,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          percent == null
                              ? '…'
                              : formatCurrency(
                                  bookingTotal(
                                    sessionFee: t.fee,
                                    percent: percent,
                                    points: 0,
                                    pointToNpr: pointToNpr,
                                  ),
                                  l10n,
                                ),
                          style: const TextStyle(
                            fontFamily: AppTypography.fontSans,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),

                        if (_pointsToUse > 0) ...[
                          const SizedBox(height: 12),
                          _PriceRow(
                            label: l10n.bookingPointsApplied(
                              _pointsToUse,
                            ),
                            value:
                                '- ${formatCurrency(_pointsToUse * pointToNpr, l10n)}',
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),

                        // Final payable amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.youPay,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              total == null
                                  ? '…'
                                  : formatCurrency(total, l10n),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pine,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Text(
                          l10n.bookingFeeNote,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMute,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            );
          },
        ),
      ),

      // Bottom confirmation button
      bottomSheet: therapist.valueOrNull == null
          ? null
          : Container(
              color: AppColors.cream,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SystemBarInset(
                inset: SystemBarInset.of(context),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitting || total == null
                        ? null
                        : () => _confirm(therapist.value!.fee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pine,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.pine.withAlpha(90),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      textStyle: AppTypography.textTheme.titleMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppRadii.tile,
                        ),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            total == null
                                ? 'Confirm & Pay'
                                : l10n.bookingConfirmAndPay(
                                    formatCurrency(total, l10n),
                                  ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _confirm(double fee) async {
      debugPrint('BOOK pin = ${_pin?.latitude}, ${_pin?.longitude}');
    final address = _addressController.text.trim();

    setState(() => _showAddressErrors = true);

    final form = _addressFormKey.currentState;

    if (form != null && !form.validate()) {
      final fieldContext = _addressFormKey.currentContext;

      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          alignment: 0.2,
        );
      }

      return;
    }

    setState(() => _submitting = true);

    final result = await ref
        .read(patientActionsProvider)
        .book(
          therapistId: widget.therapistId,
          date: DateTime.parse(widget.date),
          time: widget.time,
          address: address,
          fee: fee,
          paymentMethod: _paymentMethod.toUpperCase(),
          point: _pin,
          landmark: _landmarkController.text,
          pointsToUse: _pointsToUse,
        );

    if (!mounted) return;

    setState(() => _submitting = false);

    await result.match(
      (failure) async {
        _toast(failure.message, isError: true);
      },
      (outcome) async {
        final session = outcome.session;

        // Gateway bookings must complete checkout before confirmation.
        if (outcome.needsCheckout) {
          context.pushReplacement(
            '/patient/checkout',
            extra: outcome,
          );
          return;
        }

        if (_pointsToUse > 0) {
          ref.invalidate(pointBalanceProvider);
        }

        if (!mounted) return;

        context.pushReplacement(
          '/patient/booking-success',
          extra: session,
        );
      },
    );
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.label,
    required this.logoPath,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String logoPath;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.pinePale.withValues(alpha: 0.48)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: active ? AppColors.pine : AppColors.border,
                width: active ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 38,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.row),
                  ),
                  child: Image.asset(
                    logoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.inkMute,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.pine : Colors.transparent,
                    border: Border.all(
                      color: active ? AppColors.pine : AppColors.inkMute,
                      width: active ? 1 : 1.3,
                    ),
                  ),
                  child: active
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Offers spendable points, capped at half the consultation fee.
class _PointsRow extends ConsumerWidget {
  const _PointsRow({
    required this.fee,
    required this.selected,
    required this.onChanged,
  });

  final double fee;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(spendablePointsProvider);

    if (available <= 0) return const SizedBox.shrink();

    final maxUsable = Validators.maxRedeemablePoints(
      available: available,
      fee: fee,
    );

    if (maxUsable <= 0) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.pointsYouHave(available),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Switch(
                value: selected > 0,
                onChanged: (on) {
                  onChanged(on ? maxUsable : 0);
                },
              ),
            ],
          ),
          Text(
            selected > 0
                ? context.l10n.pointsUsing(selected)
                : context.l10n.pointsUseUpTo(maxUsable),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.inkMid,
            ),
          ),
          if (available > maxUsable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.pointsHalfCap,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.inkMute,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A label and an amount on the price summary.
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkMid,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.inkMid),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
