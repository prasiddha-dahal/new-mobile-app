import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/therapist_providers.dart';

class TherapistBioScreen extends ConsumerWidget {
  const TherapistBioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(therapistProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              PageHeader(
                title: l10n.therapistBioPortfolio,
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.profileAbout),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: profile.when(
                  loading: () => const SkeletonBox(height: 168),
                  error: (e, _) => ErrorStateView(
                    failure: e is Failure ? e : const UnknownFailure(),
                    onRetry: () => ref.invalidate(therapistProfileProvider),
                  ),
                  data: (p) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.bio.isEmpty ? l10n.therapistBioEmpty : p.bio,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.bio.isEmpty
                                ? AppColors.inkMute
                                : AppColors.inkMid,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/therapist/edit-profile'),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(
                              p.bio.isEmpty
                                  ? l10n.therapistWriteBio
                                  : l10n.therapistEditBio,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.therapistSpecializations),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Builder(
                  builder: (context) {
                    // The profile stores one specialty string, not a list, so
                    // this renders what is actually set rather than a fixed
                    // menu of five.
                    // TODO(api): multiple specializations per therapist.
                    final specialty = profile.valueOrNull?.specialty ?? '';
                    if (specialty.isEmpty) {
                      return Text(
                        l10n.therapistNoSpecialization,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMute,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specialty
                          .split(RegExp(r'[,&]'))
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pinePale,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.pine,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
