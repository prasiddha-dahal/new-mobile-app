import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/providers/session_reset.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/password_field.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/form_fields.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_sheet.dart';
import '../../../../core/widgets/state_views.dart';

/// What a chip shows for the value it carries.
///
/// The values below are what the form stores and, for specialism and city,
/// what reaches the API — so they stay English and only the label changes.
/// A value with no entry falls through unchanged rather than disappearing.
String signupOptionLabel(String value, AppLocalizations l10n) =>
    switch (value) {
      'Back pain' => l10n.optionBackPain,
      'Post-surgery' => l10n.optionPostSurgery,
      'Sports injury' => l10n.optionSportsInjury,
      'Neuro' => l10n.optionNeuro,
      'Pediatric' => l10n.optionPediatric,
      'Geriatric' => l10n.optionGeriatric,
      'Other' => l10n.optionOther,
      'Sports & post-surgery' => l10n.optionSportsPostSurgery,
      'Musculoskeletal' => l10n.optionMusculoskeletal,
      'Post-op' => l10n.optionPostOp,
      'Kathmandu' => l10n.cityKathmandu,
      'Lalitpur' => l10n.cityLalitpur,
      'Bhaktapur' => l10n.cityBhaktapur,
      'Pokhara' => l10n.cityPokhara,
      'Chitwan' => l10n.cityChitwan,
      'Biratnagar' => l10n.cityBiratnagar,
      'Sun' => l10n.dayShortSun,
      'Mon' => l10n.dayShortMon,
      'Tue' => l10n.dayShortTue,
      'Wed' => l10n.dayShortWed,
      'Thu' => l10n.dayShortThu,
      'Fri' => l10n.dayShortFri,
      'Sat' => l10n.dayShortSat,
      'Morning' => l10n.timeBlockMorning,
      'Afternoon' => l10n.timeBlockAfternoon,
      'Evening' => l10n.timeBlockEvening,
      'eSewa' => l10n.payoutEsewa,
      'Khalti' => l10n.payoutKhalti,
      'Bank' => l10n.payoutBank,
      _ => value,
    };

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.startAsTherapist = false});

  /// Which half of the form to open on.
  ///
  /// The landing screen's "I'm a physiotherapist" button used to push
  /// `/signup` with no argument, which opened the patient form -- so the one
  /// control on the whole screen that says "I am a therapist" put the reader
  /// into the wrong flow.
  final bool startAsTherapist;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  late bool _isPatientFlow = !widget.startAsTherapist;

  Future<void> _handlePatientSignup({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? city,
    String? gender,
    String? dob,
    String? referralCode,
  }) async {
    // The account cannot be created until the address is verified, so the
    // code is collected first and `signup` only runs once it is accepted.
    final verified = await showOtpSheet(context, email: email, name: name);
    if (verified != true || !mounted) return;

    final authActions = ref.read(authActionsProvider);
    final result = await authActions.signup(
      name: name,
      email: email,
      password: password,
      role: 'PATIENT',
      phone: phone,
      city: city,
      gender: gender,
      dob: dob,
      referralCode: referralCode,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.danger,
          ),
        );
      },
      (_) {
        resetAccountScopedProviders(ref);
        context.go('/patient/home');
      },
    );
  }

  Future<void> _handleTherapistSignup({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? city,
    String? specialty,
    String? license,
    int? experience,
    double? fee,
  }) async {
    final verified = await showOtpSheet(context, email: email, name: name);
    if (verified != true || !mounted) return;

    final authActions = ref.read(authActionsProvider);
    final result = await authActions.signup(
      name: name,
      email: email,
      password: password,
      role: 'THERAPIST',
      phone: phone,
      city: city,
      specialty: specialty,
      license: license,
      experience: experience,
      fee: fee,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.danger,
          ),
        );
      },
      (_) {
        resetAccountScopedProviders(ref);
        context.go('/verify-pending');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: _isPatientFlow
            ? _PatientSignupForm(
                onBack: () => context.pop(),
                onComplete: _handlePatientSignup,
                switchToTherapist: () => setState(() => _isPatientFlow = false),
              )
            : _TherapistSignupForm(
                onBack: () => context.pop(),
                onComplete: _handleTherapistSignup,
                switchToPatient: () => setState(() => _isPatientFlow = true),
              ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        letterSpacing: 0,
        color: AppColors.inkMid,
      ),
    );
  }
}

/// See [ChipSelector] in auth_form_widgets.dart, which this duplicates.
/// [options] are values sent to the API; [display] is what the reader sees.
class _ChipSelector extends StatelessWidget {
  const _ChipSelector({
    required this.options,
    this.selected,
    this.onSelected,
    this.display,
  });

  final List<String> options;
  final String? selected;
  final void Function(String)? onSelected;
  final String Function(String)? display;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isActive = selected == opt;
        return GestureDetector(
          onTap: () => onSelected?.call(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.pine : AppColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive ? AppColors.pine : AppColors.border,
              ),
            ),
            child: Text(
              display?.call(opt) ?? opt,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.card : AppColors.inkMid,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

typedef PatientSignupCallback =
    Future<void> Function({
      required String name,
      required String email,
      required String password,
      String? phone,
      String? city,
      String? gender,
      String? dob,
      String? referralCode,
    });

ThemeData _figmaFieldTheme(ThemeData base) {
  final sage = Color.alphaBlend(
    AppColors.pineLight.withAlpha(90),
    Colors.white,
  );

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
      helperStyle: small.copyWith(letterSpacing: 0),
      errorStyle: small.copyWith(color: AppColors.danger, letterSpacing: 0),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIconColor: AppColors.inkMid,
      suffixIconColor: AppColors.inkMid,
      enabledBorder: border(sage),
      border: border(sage),
      focusedBorder: border(AppColors.pine, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
  );
}

class _PatientSignupForm extends StatefulWidget {
  const _PatientSignupForm({
    required this.onBack,
    required this.onComplete,
    required this.switchToTherapist,
  });

  final VoidCallback onBack;
  final PatientSignupCallback onComplete;
  final VoidCallback switchToTherapist;

  @override
  State<_PatientSignupForm> createState() => _PatientSignupFormState();
}

class _PatientSignupFormState extends State<_PatientSignupForm> {
  static const bool _showGoogleSignIn = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _cityController = TextEditingController();
  final _referralController = TextEditingController();
  bool _agreed = false;
  bool _isLoading = false;
  String _concern = 'Back pain';
  String? _gender;
  DateTime? _dob;

  final concerns = [
    'Back pain',
    'Post-surgery',
    'Sports injury',
    'Neuro',
    'Pediatric',
    'Geriatric',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _cityController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Every field, including the pickers, answers to this one call.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    await widget.onComplete(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim(),
      gender: _gender,
      dob: _dob == null
          ? null
          : '${_dob!.year.toString().padLeft(4, '0')}-'
                '${_dob!.month.toString().padLeft(2, '0')}-'
                '${_dob!.day.toString().padLeft(2, '0')}',
      referralCode: _referralController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Theme(
      data: _figmaFieldTheme(Theme.of(context)),
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
                  onPressed: widget.onBack,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
              // TODO(l10n): move these two strings into the ARB files.
              const Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Let's get started.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: 28),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.fieldFullNameLabel,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.fullName(l10n),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: l10n.fieldPhoneLabel,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  ...Validators.phoneInputFormatters,
                  LengthLimitingTextInputFormatter(10),
                ],
                textInputAction: TextInputAction.next,
                validator: Validators.phone(l10n),
              ),
              const SizedBox(height: 14),
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
              PasswordField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: l10n.fieldPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.password(l10n),
                // Re-checks the confirm field so it stops complaining as soon
                // as the two agree, rather than on its own next edit.
                onChanged: (_) {
                  if (_confirmController.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
              ),

              const SizedBox(height: 14),
              PasswordField(
                controller: _confirmController,
                decoration: InputDecoration(
                  hintText: l10n.fieldConfirmLabel,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.confirmPassword(
                  l10n,
                  () => _passwordController.text,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    // Validated when a date is given, but not yet sent:
                    // SignupRequest has no `dob` field.
                    child: AppDateField(
                      label: l10n.fieldDateOfBirthLabel,
                      hint: l10n.fieldSelectDateHint,
                      lastDate: DateTime.now(),
                      onChanged: (v) => setState(() => _dob = v),
                      validator: (v) =>
                          v == null ? null : Validators.dateOfBirth(l10n)(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GenderField(
                      value: _gender,
                      onChanged: (v) => _gender = v,
                      isRequired: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LocationAutocompleteField(
                controller: _cityController,
                detail: LocationDetail.city,
                decoration: InputDecoration(
                  hintText: l10n.fieldCityAreaLabel,
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                ),
                textInputAction: TextInputAction.done,
                validator: Validators.required(l10n, l10n.fieldCityOrArea),
              ),
              const SizedBox(height: 14),
              // Attribution is only ever captured here; there is no second
              // chance to enter a referral code.
              TextFormField(
                controller: _referralController,
                decoration: InputDecoration(
                  hintText: l10n.fieldReferralLabel,
                  helperText: l10n.fieldReferralHelper,
                  prefixIcon: const Icon(
                    Icons.card_giftcard_outlined,
                    size: 20,
                  ),
                ),
                validator: Validators.optional(Validators.referralCode(l10n)),
              ),
              const SizedBox(height: 22),
              _Label(l10n.signupConcernLabel),
              const SizedBox(height: 8),
              _ChipSelector(
                options: concerns,
                selected: _concern,
                display: (v) => signupOptionLabel(v, l10n),
                onSelected: (v) => setState(() => _concern = v),
              ),
              const SizedBox(height: 20),

              // Consent
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    activeColor: AppColors.pine,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.inkMid,
                        ),
                        children: [
                          TextSpan(text: l10n.signupAgreeTo),
                          TextSpan(
                            text: l10n.legalTerms,
                            style: const TextStyle(
                              color: AppColors.pine,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: l10n.legalAnd),
                          TextSpan(
                            text: l10n.legalPrivacyPolicy,
                            style: const TextStyle(
                              color: AppColors.pine,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: l10n.legalFullStop),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Continue
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreed && !_isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.pine.withAlpha(90),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
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
                      // TODO(l10n): "Continue"
                      : const Text('Continue'),
                ),
              ),

              if (_showGoogleSignIn) ...[
                const SizedBox(height: 20),
                const _OrDivider(),
                const SizedBox(height: 20),
                _GoogleButton(
                  onPressed: () => showUnavailableDialog(
                    context,
                    // TODO(l10n) + TODO(api): wire up Google sign-in.
                    title: 'Google sign-up',
                    body:
                        'Signing up with Google is not available yet. '
                        'Please create an account with your email.',
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: widget.switchToTherapist,
                  child: Text(
                    l10n.signupSwitchToTherapist,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      letterSpacing: 0,
                      color: AppColors.pine,
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

/// ── Or continue with ──
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(height: 1, color: AppColors.border));
    return const Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            // TODO(l10n)
            'Or Continue With',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.inkMid,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sage = Color.alphaBlend(
      AppColors.pineLight.withAlpha(90),
      Colors.white,
    );

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          side: BorderSide(color: sage),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
            // TODO(l10n)
            const Text('Google'),
          ],
        ),
      ),
    );
  }
}

typedef TherapistSignupCallback =
    Future<void> Function({
      required String name,
      required String email,
      required String password,
      String? phone,
      String? city,
      String? specialty,
      String? license,
      int? experience,
      double? fee,
    });

class _TherapistSignupForm extends StatefulWidget {
  const _TherapistSignupForm({
    required this.onBack,
    required this.onComplete,
    required this.switchToPatient,
  });

  final VoidCallback onBack;
  final TherapistSignupCallback onComplete;
  final VoidCallback switchToPatient;

  @override
  State<_TherapistSignupForm> createState() => _TherapistSignupFormState();
}

class _TherapistSignupFormState extends State<_TherapistSignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _feeController = TextEditingController();

  bool _agreed = false;
  bool _isLoading = false;
  String _specialty = 'Sports & post-surgery';
  String _city = 'Kathmandu';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    await widget.onComplete(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      city: _city,
      specialty: _specialty,
      license: _licenseController.text.trim(),
      experience: int.tryParse(_experienceController.text.trim()),
      fee: double.tryParse(_feeController.text.trim().replaceAll(',', '')),
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Theme(
      data: _figmaFieldTheme(Theme.of(context)),
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
                  onPressed: widget.onBack,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                l10n.signupApplyToJoin,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.signupTherapistSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: 28),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.fieldFullNameHintTherapist,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.fullName(l10n),
              ),
              const SizedBox(height: 14),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: l10n.fieldPhoneLabel,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  ...Validators.phoneInputFormatters,
                  LengthLimitingTextInputFormatter(10),
                ],
                textInputAction: TextInputAction.next,
                validator: Validators.phone(l10n),
              ),
              const SizedBox(height: 14),

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
                textInputAction: TextInputAction.next,
                validator: Validators.password(l10n),
                onChanged: (_) {
                  if (_confirmController.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
              ),
              const SizedBox(height: 14),

              // Confirm Password
              PasswordField(
                controller: _confirmController,
                decoration: InputDecoration(
                  hintText: l10n.fieldConfirmLabel,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.confirmPassword(
                  l10n,
                  () => _passwordController.text,
                ),
              ),
              const SizedBox(height: 14),

              // NMC Licence
              TextFormField(
                controller: _licenseController,
                decoration: InputDecoration(
                  hintText: l10n.fieldNmcLicenceLabel,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.required(l10n, l10n.fieldNmcLicence),
              ),
              const SizedBox(height: 14),

              // Upload document
              GestureDetector(
                onTap: () => showUnavailableDialog(
                  context,
                  title: l10n.signupUploadUnavailableTitle,
                  body: l10n.signupUploadUnavailableBody,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    border: Border.all(
                      color: Color.alphaBlend(
                        AppColors.pineLight.withAlpha(90),
                        Colors.white,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.upload_file_outlined,
                        size: 20,
                        color: AppColors.inkMid,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.uploadTapToUpload,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.inkMid,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      Text(
                        l10n.uploadFileHint,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkMute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Experience + Fee
              TextFormField(
                controller: _experienceController,
                decoration: InputDecoration(
                  hintText: l10n.fieldYearsExperienceLabel,
                  prefixIcon: const Icon(Icons.work_outline, size: 20),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: Validators.wholeNumber(
                  l10n,
                  l10n.fieldYearsOfExperience,
                  max: 70,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _feeController,
                decoration: InputDecoration(
                  hintText: l10n.fieldRatePerSessionLabel,
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: Validators.amount(
                  l10n,
                  l10n.fieldRatePerSession,
                  min: 100,
                  max: 100000,
                ),
              ),
              const SizedBox(height: 22),

              // Specializations
              _Label(l10n.signupSpecializationsLabel),
              const SizedBox(height: 8),
              _ChipSelector(
                options: const [
                  'Sports & post-surgery',
                  'Neuro',
                  'Pediatric',
                  'Geriatric',
                  'Musculoskeletal',
                  'Post-op',
                ],
                selected: _specialty,
                display: (v) => signupOptionLabel(v, l10n),
                onSelected: (v) => setState(() => _specialty = v),
              ),
              const SizedBox(height: 22),

              // Service Cities
              _Label(l10n.signupServiceCitiesLabel),
              const SizedBox(height: 8),
              _ChipSelector(
                options: const ['Kathmandu', 'Lalitpur', 'Bhaktapur'],
                selected: _city,
                display: (v) => signupOptionLabel(v, l10n),
                onSelected: (v) => setState(() => _city = v),
              ),
              const SizedBox(height: 20),

              // Info box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: Text(
                  l10n.signupSetUpAfterApproval,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.inkMid,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Consent
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    activeColor: AppColors.pine,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.inkMid,
                        ),
                        children: [
                          TextSpan(text: l10n.signupTherapistConsent),
                          TextSpan(
                            text: l10n.legalTerms,
                            style: const TextStyle(
                              color: AppColors.pine,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: l10n.legalAndWord),
                          TextSpan(
                            text: l10n.legalCodeOfConduct,
                            style: const TextStyle(
                              color: AppColors.pine,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: l10n.legalFullStop),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreed && !_isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.pine.withAlpha(90),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
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
                      : Text(l10n.signupSubmitApplication),
                ),
              ),
              const SizedBox(height: 16),

              // Switch to patient
              Center(
                child: TextButton(
                  onPressed: widget.switchToPatient,
                  child: Text(
                    l10n.signupSwitchToPatient,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      letterSpacing: 0,
                      color: AppColors.pine,
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
