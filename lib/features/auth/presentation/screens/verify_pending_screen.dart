import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class VerifyPendingScreen extends StatelessWidget {
  const VerifyPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.amberPale,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('⏳', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amberPale,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.pendingBadge,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 10,
                    letterSpacing: 1.8,
                    color: Color(0xFF8a5a14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.pendingTitle,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pendingBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.inkMid),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.pendingStatusLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMute,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amberPale,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.statusPending,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 10,
                              color: Color(0xFF8a5a14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/therapist/home'),
                  child: Text(l10n.pendingPreviewDashboard),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pendingFullAccessNote,
                style: const TextStyle(fontSize: 11, color: AppColors.inkMute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
