import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const Color _patientCard = Color(0xFFE6F4EF);
  static const Color _therapistCard = Color(0xFFDBEBFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    // Logo + name
                    SvgPicture.asset(
                      'assets/images/sahayatri-logo.svg',
                      height: 64,
                      semanticsLabel: 'Physioghar logo',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Physioghar',
                      style: TextStyle(
                        fontFamily: AppTypography.fontSans,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.pine,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Heading
                    const Text(
                      'How would you like to\nuse Physioghar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontSans,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppColors.ink,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Role cards
                    _RoleCard(
                      color: _patientCard,
                      imageAsset: 'assets/images/onboarding/role_patient.webp',
                      title: 'I need\nphysiotherapy',
                      description:
                          'Find a therapist, book sessions and manage your treatment.',
                      onTap: () => context.push('/patient-intro'),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      color: _therapistCard,
                      imageAsset:
                          'assets/images/onboarding/role_therapist.webp',
                      title: 'I provide\nphysiotherapy',
                      description:
                          'Join as a verified professional and grow your practice.',
                      onTap: () => context.push('/therapist-intro'),
                    ),

                    const Spacer(),
                    const SizedBox(height: 24),

                    // Already have an account
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: AppTypography.fontSans,
                          fontSize: 14,
                          letterSpacing: 0,
                        ),
                      ),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Already have an account?  ',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Color color;
  final String imageAsset;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.color,
    required this.imageAsset,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.card);

    return Semantics(
      button: true,
      label: title.replaceAll('\n', ' '),
      child: Material(
        color: color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 142,
            child: Row(
              children: [
                SizedBox(
                  width: 132,
                  height: double.infinity,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black, Colors.black, Colors.transparent],
                      stops: [0.0, 0.7, 1.0],
                    ).createShader(rect),
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontSans,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontSans,
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: AppColors.inkMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}