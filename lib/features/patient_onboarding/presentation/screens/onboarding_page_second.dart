import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/widgets/dot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

class OnboardingPageSecond extends StatelessWidget {
  const OnboardingPageSecond({super.key});

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and steps
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skip
                  Align(
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

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    'How Physioghar Works',
                    style: text.titleLarge!.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Simple, safe and convenient for everyone.',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Steps
                  const _StepItem(
                    icon: Icons.search,
                    title: 'Find',
                    description:
                        'Discover verified physiotherapists near you.',
                  ),

                  const _StepItem(
                    icon: Icons.calendar_today_sharp,
                    title: 'Book',
                    description:
                        'Choose home or clinic sessions at your convenience.',
                  ),

                  const _StepItem(
                    icon: Icons.favorite_border,
                    title: 'Care',
                    description:
                        'Receive personalized treatment and follow-ups.',
                    isLast: true,
                  ),
                ],
              ),
            ),

            // Illustration
            Image.asset(
              'assets/images/onboarding/onboarding2.webp',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),

            const Spacer(),

            // Bottom navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                          ),
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
                        Dot(isActive: true),
                        SizedBox(width: 6),
                        Dot(isActive: false),
                        SizedBox(width: 6),
                        Dot(isActive: false),
                      ],
                    ),

                    // Next button
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: AppColors.pine,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            context.push('/onboardingThird');
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
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isLast;

  const _StepItem({
    required this.icon,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.pinePale.withAlpha(110),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.ink,
                    size: 20,
                  ),
                ),

                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.placeholderBorder,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Step title and description
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleLarge!.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    description,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}