import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/widgets/feature_pill.dart';

class PatientIntroScreen extends StatelessWidget {
  const PatientIntroScreen({super.key});

  static const String _roleSelectionRoute = '/role-selection';
  static const String _signupRoute = '/signup';
  static const String _loginRoute = '/login';

  static const Color _background = Color(0xFFE3F7EE);

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
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
                    child: IconButton(
                      onPressed: () => _goBack(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                      tooltip: 'Back',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Heading + subtitle
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          "You're one step closer to\nbetter movement.",
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
                          'Create an account to find verified\nphysiotherapists near you.',
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

                  const SizedBox(height: 36),

                  // Illustration + feature pills
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 178,
                        child: Image.asset(
                          'assets/images/onboarding/role_patient.webp',
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 24),
                          child: Column(
                            children: [
                              FeaturePill(
                                icon: Icons.search,
                                text: 'Explore therapists',
                              ),
                              SizedBox(height: 12),
                              FeaturePill(
                                icon: Icons.calendar_today_outlined,
                                text: 'Book a session',
                              ),
                              SizedBox(height: 12),
                              FeaturePill(
                                icon: Icons.favorite_border,
                                text: 'Manage your care',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // CTA + login link
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
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
                                borderRadius:
                                    BorderRadius.circular(AppRadii.tile),
                              ),
                            ),
                            child: const Text('Continue as a Patient'),
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
                                    color: AppColors.pine,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
