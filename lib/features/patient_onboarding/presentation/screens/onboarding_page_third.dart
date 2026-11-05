import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/widgets/dot.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/widgets/feature_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

class OnboardingPageThird extends StatelessWidget {
  const OnboardingPageThird({super.key});

  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (context.mounted) {
      context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _finishOnboarding(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pine,
                    textStyle: text.titleSmall,
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),

            // Hero image
            AspectRatio(
              aspectRatio: 366 / 250,
              child: Image.asset(
                'assets/images/onboarding/for_patients.webp',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading
                    Text(
                      'For Patients',
                      style: text.titleLarge!.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      'Find trusted physiotherapists and manage your care.',
                      style: text.bodyMedium!.copyWith(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Feature list
                    const FeatureItem(
                      icon: Icons.verified_user_outlined,
                      text: 'Verified professionals',
                    ),
                    const SizedBox(height: 14),

                    const FeatureItem(
                      icon: Icons.home_outlined,
                      text: 'Home or clinic sessions',
                    ),
                    const SizedBox(height: 14),

                    const FeatureItem(
                      icon: Icons.calendar_today_outlined,
                      text: 'Easy online booking',
                    ),
                    const SizedBox(height: 14),

                    const FeatureItem(
                      icon: Icons.description_outlined,
                      text: 'Treatment plans & progress',
                    ),

                    const Spacer(),

                    // Bottom navigation
                    SizedBox(
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Back
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context.pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.ink,
                                padding: EdgeInsets.zero,
                                textStyle: text.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),

                          // Page indicators
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Dot(isActive: false),
                              SizedBox(width: 6),
                              Dot(isActive: false),
                              SizedBox(width: 6),
                              Dot(isActive: true),
                              SizedBox(width: 6),
                              Dot(isActive: false),
                            ],
                          ),

                          // Next
                          Align(
                            alignment: Alignment.centerRight,
                            child: Material(
                              color: AppColors.pine,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  context.push('/onboardingFourth');
                                },
                                child: const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
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
          ],
        ),
      ),
    );
  }
}