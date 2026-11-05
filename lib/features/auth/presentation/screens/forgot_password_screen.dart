import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/password_field.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';
import '../../../../core/validation/validators.dart';

/// Password recovery, in the three steps the backend requires:
/// `POST /auth/forgot-password` sends a code, `POST /auth/verify-otp` with
/// purpose `password_reset` marks it used, and `POST /auth/reset-password`
/// then accepts the new password.
enum _Step { email, code, password }

/// The codes this backend issues are six digits.
const int _codeLength = 6;

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // Keeps the Verify button's enabled state in step with the code boxes.
    _codeController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    if (seconds <= 0) return;
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await action();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendCode() => _run(() async {
    final email = _emailController.text.trim();
    final emailError = Validators.email(context.l10n)(email);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    final result = await ref
        .read(authActionsProvider)
        .forgotPassword(email: email);
    result.fold((f) => setState(() => _error = f.message), (resendAfter) {
      setState(() => _step = _Step.code);
      _startResendCountdown(resendAfter);
    });
  });

  Future<void> _verifyCode() => _run(() async {
    final code = _codeController.text.trim();
    // A half-typed code would only fail on the server.
    final codeError = Validators.otp(context.l10n)(code);
    if (codeError != null) {
      setState(() => _error = codeError);
      return;
    }
    final result = await ref
        .read(authActionsProvider)
        .verifyOtp(
          email: _emailController.text.trim(),
          code: code,
          purpose: 'password_reset',
        );
    result.fold(
      (f) => setState(() => _error = f.message),
      (_) => setState(() => _step = _Step.password),
    );
  });

  Future<void> _resetPassword() => _run(() async {
    final password = _passwordController.text;
    // The same policy signup applies. Length alone let someone reset to a
    // password their own signup form would have refused.
    final passwordError = Validators.password(context.l10n)(password);
    if (passwordError != null) {
      setState(() => _error = passwordError);
      return;
    }
    final confirmError = Validators.confirmPassword(
      context.l10n,
      () => password,
    )(_confirmController.text);
    if (confirmError != null) {
      setState(() => _error = confirmError);
      return;
    }
    final result = await ref
        .read(authActionsProvider)
        .resetPassword(
          email: _emailController.text.trim(),
          code: _codeController.text.trim(),
          newPassword: password,
        );
    result.fold((f) => setState(() => _error = f.message), (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.resetDone)),
      );
      context.go('/login');
    });
  });

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  VoidCallback? _primaryAction() {
    if (_busy) return null;
    return switch (_step) {
      _Step.email => _sendCode,
      _Step.code =>
        _codeController.text.length < _codeLength ? null : _verifyCode,
      _Step.password => _resetPassword,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final isCode = _step == _Step.code;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Theme(
          data: _fieldTheme(Theme.of(context)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _goBack,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: AppColors.ink,
                    ),
                  ),
                ),

                // Illustration (code step only)
                if (isCode) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/resetPassword/reset-password.webp',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 12),

                // Heading
                Text(
                  switch (_step) {
                    _Step.email => l10n.resetTitleEmail,
                    _Step.code => l10n.resetTitleCode,
                    _Step.password => l10n.resetTitlePassword,
                  },
                  textAlign: TextAlign.center,
                  style: text.titleLarge!.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (_step) {
                    _Step.email => l10n.resetSubtitleEmail,
                    _Step.code => l10n.resetSubtitleCode(
                      _emailController.text.trim(),
                    ),
                    _Step.password => l10n.resetSubtitlePassword(
                      Validators.passwordMinLength,
                    ),
                  },
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 28),

                ..._stepFields(l10n),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),

                // Primary action. Disabled (pale mint) until the step's
                // input is ready, as in the design.
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _primaryAction(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pine,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Color.alphaBlend(
                        AppColors.pinePale.withAlpha(160),
                        Colors.white,
                      ),
                      disabledForegroundColor: AppColors.pine,
                      elevation: 0,
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
                        : Text(switch (_step) {
                            _Step.email => l10n.resetSendCode,
                            _Step.code => l10n.resetVerifyCode,
                            _Step.password => l10n.resetUpdatePassword,
                          }),
                  ),
                ),

                // Resend (code step only)
                if (isCode) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: _resendIn > 0
                        ? Text(
                            l10n.resetResendIn(_resendIn),
                            style: text.bodyMedium!.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                            ),
                          )
                        : TextButton(
                            onPressed: _busy ? null : _sendCode,
                            style: TextButton.styleFrom(
                              textStyle: text.titleSmall!.copyWith(
                                fontSize: 13,
                                letterSpacing: 0,
                              ),
                            ),
                            child: Text(
                              l10n.otpResendCode,
                              style: const TextStyle(color: AppColors.pine),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepFields(AppLocalizations l10n) {
    switch (_step) {
      case _Step.email:
        return [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: l10n.fieldEmailLabel,
              prefixIcon: const Icon(Icons.mail_outline, size: 20),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendCode(),
          ),
        ];
      case _Step.code:
        return [
          _OtpBoxes(
            controller: _codeController,
            length: _codeLength,
            hasError: _error != null,
          ),
        ];
      case _Step.password:
        return [
          PasswordField(
            controller: _passwordController,
            decoration: InputDecoration(
              hintText: l10n.fieldNewPasswordLabel,
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
            ),
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 14),
          PasswordField(
            controller: _confirmController,
            decoration: InputDecoration(
              hintText: l10n.fieldConfirmPasswordLabel,
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
            ),
            onFieldSubmitted: (_) => _resetPassword(),
          ),
        ];
    }
  }
}

/// Six separate digit boxes backed by ONE hidden text field.
///
/// Tapping anywhere on the boxes focuses the hidden field, so typing,
/// backspace, paste and the SMS/email one-time-code autofill all work as they
/// would in a normal field, and [controller] always holds the whole code.
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerPale,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.textTheme.bodySmall!.copyWith(
                height: 1.35,
                letterSpacing: 0,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft sage used for field borders (same as the signup and login screens).
final Color _sage = Color.alphaBlend(
  AppColors.pineLight.withAlpha(90),
  Colors.white,
);

/// Rounded, white, outlined fields — the same look as signup and login.
/// Duplicated; worth moving to core/theme so all three share one copy.
ThemeData _fieldTheme(ThemeData base) {
  final body = AppTypography.textTheme.bodyMedium!;
  final small = AppTypography.textTheme.bodySmall!;

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: body.copyWith(color: AppColors.inkMid, letterSpacing: 0),
      labelStyle: body.copyWith(color: AppColors.inkMid, letterSpacing: 0),
      floatingLabelStyle: body.copyWith(
        color: AppColors.pine,
        letterSpacing: 0,
      ),
      errorStyle: small.copyWith(color: AppColors.danger, letterSpacing: 0),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIconColor: AppColors.inkMid,
      suffixIconColor: AppColors.inkMid,
      enabledBorder: border(_sage),
      border: border(_sage),
      focusedBorder: border(AppColors.pine, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
  );
}