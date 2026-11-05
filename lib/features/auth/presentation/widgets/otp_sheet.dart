import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';
import '../../../../core/validation/validators.dart';

/// The codes this backend issues are six digits.
const int _codeLength = 6;

/// Collects the emailed signup code and verifies it.
///
/// `POST /auth/signup` refuses to create the account unless a `signup` OTP for
/// that address has already been verified, so this has to run before the
/// account is created, not after.
///
/// Returns true once the code is accepted, null/false if the user backs out.
Future<bool?> showOtpSheet(
  BuildContext context, {
  required String email,
  required String name,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    // Backing out must be deliberate: dismissing loses the sent code.
    isDismissible: false,
    builder: (_) => _OtpSheet(email: email, name: name),
  );
}

class _OtpSheet extends ConsumerStatefulWidget {
  const _OtpSheet({required this.email, required this.name});
  final String email;
  final String name;

  @override
  ConsumerState<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends ConsumerState<_OtpSheet> {
  final _codeController = TextEditingController();
  bool _busy = false;
  bool _sending = true;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  /// Keeps the Verify button in step with the boxes, and verifies as soon as
  /// the sixth digit lands.
  void _onCodeChanged() {
    if (!mounted) return;
    setState(() {});
    if (_codeController.text.length == _codeLength && !_busy && !_sending) {
      _verify();
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    if (seconds <= 0) return;
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(authActionsProvider)
        .sendSignupOtp(email: widget.email, name: widget.name);
    if (!mounted) return;
    setState(() => _sending = false);
    result.fold((f) => setState(() => _error = f.message), _startCountdown);
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    final codeError = Validators.otp(context.l10n)(code);
    if (codeError != null) {
      setState(() => _error = codeError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(authActionsProvider)
        .verifyOtp(email: widget.email, code: code, purpose: 'signup');
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (f) => setState(() => _error = f.message),
      (_) => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ready = _codeController.text.length >= _codeLength;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        // viewInsets above lifts the sheet clear of the keyboard; this keeps
        // it clear of the system buttons, which is a separate inset. With the
        // keyboard up SafeArea reports nothing, so `minimum` still applies.
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Heading
              Text(
                l10n.otpTitle,
                textAlign: TextAlign.center,
                style: text.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _sending
                    ? l10n.otpSending(widget.email)
                    : l10n.otpSent(widget.email),
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(
                  height: 1.5,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: 28),

              // Six digit boxes, one hidden field behind them.
              _OtpBoxes(
                controller: _codeController,
                length: _codeLength,
                hasError: _error != null,
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerPale,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: text.bodySmall!.copyWith(
                            height: 1.35,
                            letterSpacing: 0,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Verify. Pale mint until the code is complete, as in the
              // design.
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_busy || _sending || !ready) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Color.alphaBlend(
                      AppColors.pinePale.withAlpha(160),
                      Colors.white,
                    ),
                    disabledForegroundColor: AppColors.pine,
                    elevation: 0,
                    // Buttons default to labelLarge (mono, spaced).
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
                            color: AppColors.pine,
                          ),
                        )
                      : Text(l10n.otpVerifyAndCreate),
                ),
              ),
              const SizedBox(height: 16),

              // Resend, centred under the button.
              Center(
                child: _resendIn > 0
                    ? Text(
                        l10n.otpResendIn(_resendIn),
                        style: text.bodyMedium!.copyWith(
                          fontSize: 13,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      )
                    : TextButton(
                        onPressed: (_busy || _sending) ? null : _send,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.pine,
                          textStyle: text.titleSmall!.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        child: Text(l10n.otpResendCode),
                      ),
              ),

              // The sheet is not dismissible, so the way out stays — quieter
              // than the design's single link, but without it nobody could
              // back out of signup from here.
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkMid,
                    textStyle: text.titleSmall!.copyWith(
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(l10n.actionCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six separate digit boxes backed by ONE hidden text field.
///
/// Tapping anywhere on the boxes focuses the hidden field, so typing,
/// backspace, paste and the SMS/email one-time-code autofill all work as they
/// would in a normal field, and [controller] always holds the whole code.
///
/// Same widget as the one in the forgot-password screen; worth moving to
/// `core/widgets/otp_boxes.dart` so both share one copy.
class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.controller,
    required this.length,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final bool hasError;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([widget.controller, _focusNode]),
                builder: (context, _) {
                  final code = widget.controller.text;
                  // The box the next digit will land in (the last one when
                  // the code is complete).
                  final activeIndex = code.length >= widget.length
                      ? widget.length - 1
                      : code.length;

                  return Row(
                    children: [
                      for (var i = 0; i < widget.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        Expanded(
                          child: _OtpBox(
                            digit: i < code.length ? code[i] : '',
                            isActive: _focusNode.hasFocus && i == activeIndex,
                            hasError: widget.hasError,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              // Invisible input on top: it receives the taps and the typing.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  final String digit;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError
        ? AppColors.danger
        : isActive
        ? AppColors.pine
        : AppColors.inkMute;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.row),
        border: Border.all(color: borderColor, width: isActive ? 1.6 : 1),
      ),
      child: Text(
        digit,
        style: AppTypography.textTheme.titleLarge!.copyWith(
          fontSize: 20,
          letterSpacing: 0,
        ),
      ),
    );
  }
}