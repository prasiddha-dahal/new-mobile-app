import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:sahayatri_care_connect/features/patient_onboarding/presentation/widgets/dot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPageFirst extends StatelessWidget {
  const OnboardingPageFirst({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        // Mark onboarding as completed
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hasSeenOnboarding', true);

                        // Then go to role selection screen
                        if (context.mounted) {
                          context.go('/role-selection');
                        }
                      },
                      style: TextButton.styleFrom(textStyle: text.titleSmall),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: AppColors.pine),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Quality physiotherapy,\nright at your home.',
                    style: text.titleLarge!.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Physioghar connects patients with verified physiotherapists for home or clinic sessions and helps professionals grow their practice.',
                    style: text.bodyLarge!.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),

            const Spacer(),

            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.25, 0.75, 1.0],
              ).createShader(rect),
              child: Image.asset(
                'assets/images/onboarding/onboarding1.webp',
                width: double.infinity,
                height: 300,
                fit: BoxFit.fitWidth,
              ),
            ),

            const Spacer(flex: 2),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Page indicators (centered)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Dot(isActive: true),
                        SizedBox(width: 6),
                        Dot(isActive: false),
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
                            context.push('/onboardingSecond');
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