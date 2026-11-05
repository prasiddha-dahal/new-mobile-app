import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding/welcome.webp',
              fit: BoxFit.fitWidth,
              //alignment: Alignment.bottomCenter,
            ),
          ),

          // Top fade: keeps the logo + tagline readable
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cream,
                    AppColors.cream.withAlpha(235),
                    AppColors.cream.withAlpha(0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Bottom fade: keeps the button + login link readable
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cream.withAlpha(0),
                    AppColors.cream.withAlpha(220),
                    AppColors.cream,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Foreground content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxxl,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  // Logo mark
                  SvgPicture.asset(
                    'assets/images/sahayatri-logo.svg',
                    height: 56,
                    semanticsLabel: 'Physioghar logo',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'Physioghar',
                    style: text.titleLarge!.copyWith(
                      fontSize: 28,
                      color: AppColors.pine,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    'Physioghar care\nwhere you need.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge!.copyWith(
                      height: 1.4,
                      color: AppColors.inkMid,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/onboardingFirst'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pine,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        textStyle: text.titleMedium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                      ),
                      child: const Text('Get Started'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  TextButton(
                    onPressed: () => context.go('/login'),
                    style: TextButton.styleFrom(textStyle: text.bodyMedium),
                    child: Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: text.bodyMedium,
                        children: [
                          TextSpan(
                            text: 'Log in',
                            style: text.titleSmall!.copyWith(
                              color: AppColors.pine,
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
        ],
      ),
    );
  }
}