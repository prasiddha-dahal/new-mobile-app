import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/widgets/feature_pill.dart';

class TherapistIntroScreen extends StatelessWidget {
  const TherapistIntroScreen({super.key});

  static const String _roleSelectionRoute = '/role-selection';
  static const String _signupRoute = '/signup?role=therapist';
  static const String _loginRoute = '/login';

  static const Color _background = Color(0xFFDDEFFD);

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_roleSelectionRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Blue top area
          Expanded(
            child: Container(
              width: double.infinity,
              color: _background,
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
                        child: IconButton(
                          onPressed: () => _goBack(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.ink,
                          ),
                          tooltip: 'Back',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Heading + subtitle
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                'Join a professional\nnetwork that values you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontSans,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Create an account to start receiving patient\nrequests.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontSans,
                                  fontSize: 15,
                                  height: 1.4,
                                  color: AppColors.inkMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Illustration + feature pills
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 130,
                              height: 150,
                              child: Image.asset(
                                'assets/images/onboarding/role_therapist.webp',
                                fit: BoxFit.cover,
                                alignment: Alignment.bottomCenter,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                children: [
                                  FeaturePill(
                                    icon: Icons.person,
                                    text: 'Build your profile',
                                  ),
                                  SizedBox(height: 12),
                                  FeaturePill(
                                    icon: Icons.calendar_today_outlined,
                                    text: 'Receive requests',
                                  ),
                                  SizedBox(height: 12),
                                  FeaturePill(
                                    icon: Icons.attach_money,
                                    text: 'Manage earnings',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Container(
            width: double.infinity,
            color: _background,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => context.push(_signupRoute),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pine,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontFamily: AppTypography.fontSans,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                          ),
                        ),
                        child: const Text('Continue as a Therapist'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go(_loginRoute),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: AppTypography.fontSans,
                          fontSize: 14,
                          letterSpacing: 0,
                        ),
                      ),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: AppColors.inkMid),
                          children: [
                            TextSpan(
                              text: 'Log in',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}