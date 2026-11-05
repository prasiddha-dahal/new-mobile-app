import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PatientContactScreen extends StatelessWidget {
  const PatientContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back arrow
              AppBackButton(onPressed: context.pop, gutter: false,),

              // Title and subtitle
              Text(
                l10n.contactTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.contactSubtitle,
                style: text.bodyMedium!.copyWith(
                  height: 1.4,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _ContactTile(
                icon: Icons.email_outlined,
                label: l10n.contactEmailLabel,
                detail: 'support@sahayatrihealth.com', // l10n:value
              ),
              const SizedBox(height: AppSpacing.md),
              _ContactTile(
                icon: Icons.phone_outlined,
                label: l10n.contactPhoneLabel,
                detail: '+977 1 590 1234',
              ),
              const SizedBox(height: AppSpacing.md),
              _ContactTile(
                icon: Icons.access_time_outlined,
                label: l10n.contactHoursLabel,
                detail: l10n.contactHoursValue,
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text(
                l10n.contactSendMessageLabel,
                style: text.titleMedium!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Disabled, and it says why. There is no support-message
              // endpoint of any kind, so before this the patient could
              // write five lines, press Send, and get nothing — no
              // snackbar, no error, no state change. They would believe
              // it had been sent. The email address and phone number
              // directly above this do work, and the copy points at
              // them; this is the same answer `chat_screen.dart` gives
              // for the same missing endpoint.
              // TODO(api): a support/contact endpoint (A13 in
              // docs/TODO_REGISTER.md covers the chat half of it).
              TextField(
                maxLines: 5,
                enabled: false,
                style: text.bodyMedium!.copyWith(letterSpacing: 0),
                decoration: InputDecoration(
                  hintText: l10n.contactMessageUnavailable,
                  hintStyle: text.bodyMedium!.copyWith(
                    height: 1.4,
                    letterSpacing: 0,
                    color: AppColors.inkMute,
                  ),
                  filled: true,
                  fillColor: AppColors.mist,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.pine.withAlpha(90),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    // Buttons default to labelLarge (mono, spaced).
                    textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                  ),
                  child: Text(l10n.contactSendMessage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.detail,
  });
  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                AppColors.pinePale.withAlpha(150),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: AppColors.pine),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall!.copyWith(
                    fontSize: 12,
                    letterSpacing: 0,
                    color: AppColors.inkMid,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: text.titleSmall!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}