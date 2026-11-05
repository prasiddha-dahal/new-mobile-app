import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/password_field.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/providers/session_reset.dart';
import '../providers/auth_provider.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/state_views.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _roleSelectionRoute = '/role-selection';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_roleSelectionRoute);
    }
  }

  Future<void> _handleLogin() async {
    // Catches an empty or malformed address before a round trip that would
    // come back as a generic "invalid credentials".
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final authActions = ref.read(authActionsProvider);
    final result = await authActions.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.danger,
          ),
        );
      },
      (tokens) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Clear any account-scoped cache left by a previous session before
        // the new user's screens mount.
        resetAccountScopedProviders(ref);
        if (tokens.user.role == 'THERAPIST') {
          context.go('/therapist/home');
        } else {
          context.go('/patient/home');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Theme(
          data: _fieldTheme(Theme.of(context)),
          child: Form(
            key: _formKey,
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
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 28,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Heading
                  Text(
                    l10n.loginTitle,
                    textAlign: TextAlign.center,
                    style: text.titleLarge!.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(letterSpacing: 0),
                  ),
                  const SizedBox(height: 28),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: l10n.fieldEmailLabel,
                      prefixIcon: const Icon(Icons.mail_outline, size: 20),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: Validators.email(l10n),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  PasswordField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: l10n.fieldPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
                    // Presence only. Applying the strength rules here would
                    // tell someone with an older account that their real
                    // password is invalid while they are trying to use it.
                    validator: Validators.loginPassword(l10n),
                  ),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        textStyle: text.titleSmall!.copyWith(
                          fontSize: 13,
                          letterSpacing: 0,
                        ),
                      ),
                      child: Text(
                        l10n.loginForgotPassword,
                        style: const TextStyle(color: AppColors.pine),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Log in
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pine,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.pine.withAlpha(90),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.actionLogIn),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Or continue with
                  // The label sizes to its own text and the rules take the
                  // rest; capped at 60% of the row so a longer translation
                  // truncates instead of overflowing.
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        const Expanded(
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.6,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              l10n.loginOrContinueWith,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall!.copyWith(
                                color: AppColors.inkMid,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Google
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      // TODO(api): Google sign-in (A1 in docs/TODO_REGISTER.md).
                      // The server route exists; the OAuth client IDs and the
                      // Dart package do not.
                      onPressed: () => showUnavailableDialog(
                        context,
                        title: l10n.loginGoogleUnavailableTitle,
                        body: l10n.loginGoogleUnavailableBody,
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        side: BorderSide(color: _sage),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                        textStyle: text.titleSmall!.copyWith(
                          fontSize: 14,
                          letterSpacing: 0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Transform.scale(
                              scale: 1.4,
                              child: Image.asset(
                                'assets/images/googleLogo/google-logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              l10n.loginContinueWithGoogle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // No account? Sign up
                  // Wrap, not Row: the two halves fit one line in English and
                  // overflowed in Nepali. Identical layout while they fit; a
                  // second centred line when they do not.
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${l10n.loginNoAccount} ',
                          style: text.bodyMedium!.copyWith(
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                        GestureDetector(
                          // Role is picked first, then the matching signup.
                          onTap: () => context.push(_roleSelectionRoute),
                          child: Text(
                            l10n.loginSignUpFree,
                            style: text.titleSmall!.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                              decoration: TextDecoration.underline,
                              color: AppColors.pine,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft sage used for field and button borders (same as the signup screen).
final Color _sage = Color.alphaBlend(
  AppColors.pineLight.withAlpha(90),
  Colors.white,
);

/// Rounded, white, outlined fields — the same look as the signup form.
/// Duplicated from signup_screen.dart; worth moving to core/theme so both
/// screens share one copy.
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
