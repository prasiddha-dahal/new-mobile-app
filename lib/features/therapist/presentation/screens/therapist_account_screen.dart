import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/therapist_providers.dart';

class TherapistAccountScreen extends ConsumerWidget {
  const TherapistAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(therapistProfileProvider);
    final dashboard = ref.watch(therapistDashboardProvider);

    final p = profile.valueOrNull;
    final name = p?.name ?? user?.name ?? '';
    final email = p?.email ?? user?.email ?? '';
    final d = dashboard.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(therapistProfileProvider);
            ref.invalidate(therapistDashboardProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  decoration: const BoxDecoration(
                    color: AppColors.pine,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      ProfileAvatar(
                        initials: name.isEmpty ? '··' : getInitials(name),
                        photoUrl: p?.photo ?? user?.photo,
                        thumbUrl: p?.photoThumb,
                        tint: const Color(0x2EFFFFFF),
                        size: 64,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? l10n.accountLoading : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Fraunces',
                                fontSize: 24,
                                color: AppColors.card,
                              ),
                            ),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  l10n.roleTherapist,
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Only an APPROVED therapist can reach these
                                // screens at all, but the badge now reflects
                                // the account's actual status.
                                if (user?.isApproved ?? false)
                                  Text(
                                    l10n.therapistVerified,
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      fontSize: 10,
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/therapist/edit-profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.pine,
                        side: const BorderSide(color: AppColors.pine),
                      ),
                      child: Text(l10n.accountEditProfile),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _MenuGroup(
                  title: l10n.therapistGroupProfessional,
                  children: [
                    MenuItem.icon(
                      iconData: '📍',
                      label: l10n.therapistServiceAreas,
                      meta: p?.city,
                      onTap: () => context.push('/therapist/service-areas'),
                    ),
                    MenuItem.icon(
                      iconData: '💰',
                      label: l10n.therapistRatePerSession,
                      meta: p == null ? null : formatCurrency(p.price, l10n),
                      onTap: () => context.push('/therapist/edit-profile'),
                    ),
                    // Directly under the rate it is about. Changing the figure
                    // on the profile above is the therapist's own edit; this
                    // one is a request put to admin, and spec §36 lists it as
                    // an Account row rather than a control on the profile.
                    MenuItem.icon(
                      iconData: '📈',
                      label: l10n.therapistRequestRateIncrease,
                      onTap: () => context.push('/therapist/rate-increase'),
                    ),
                    // One row, not two. "Specializations" and "Bio & portfolio"
                    // both opened /therapist/bio -- and that screen already
                    // carries both sections, so the menu was listing the same
                    // page twice under different names. The specialty stays as
                    // the meta line, which is all the removed row showed.
                    MenuItem.icon(
                      iconData: '✎',
                      label: l10n.therapistBioPortfolio,
                      meta: p?.specialty,
                      onTap: () => context.push('/therapist/bio'),
                    ),
                    MenuItem.icon(
                      iconData: '📄',
                      label: l10n.therapistCertifications,
                      // The profile payload carries no licence number.
                      // TODO(api): expose licenseNumber on the profile.
                      onTap: () => context.push('/therapist/certifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuGroup(
                  title: l10n.therapistGroupPerformance,
                  children: [
                    MenuItem.icon(
                      iconData: '★',
                      label: l10n.therapistRatingsReviews,
                      meta: d == null
                          ? null
                          : (d.averageRating == 0
                                ? l10n.therapistNotRatedYet
                                : l10n.therapistAverageMeta(d.averageRating)),
                      onTap: () => context.push('/therapist/reviews'),
                    ),
                    MenuItem.icon(
                      iconData: '✓',
                      label: l10n.therapistPatientsTreated,
                      meta: d == null
                          ? null
                          : l10n.therapistTotalMeta(d.totalPatients),
                      onTap: () => context.go('/therapist/patients'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuGroup(
                  title: l10n.accountGroupAccount,
                  children: [
                    MenuItem.icon(
                      iconData: '💳',
                      label: l10n.therapistPayoutMethods,
                      onTap: () => context.go('/therapist/earnings'),
                    ),
                    MenuItem.icon(
                      iconData: '🔔',
                      label: l10n.accountNotifications,
                      onTap: () => context.push('/notifications'),
                    ),
                    MenuItem.icon(
                      iconData: '🎁',
                      label: l10n.accountRewards,
                      onTap: () => context.push('/therapist/rewards'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuGroup(
                  title: l10n.accountGroupSupport,
                  children: [
                    MenuItem.icon(
                      iconData: '❔',
                      label: l10n.accountHelp,
                      onTap: () => context.push('/help'),
                    ),
                    MenuItem.icon(
                      iconData: '✉',
                      label: l10n.accountContact,
                      onTap: () => context.push('/contact'),
                    ),
                    // The mirror of `Report a therapist` on the patient
                    // Account menu, in the same group and the same position.
                    // Both file to `POST /admin/complaints`; until this row
                    // existed only one side of a home visit could report the
                    // other.
                    MenuItem.icon(
                      iconData: '⚠',
                      label: l10n.accountReportPatient,
                      onTap: () => context.push('/therapist/report-patient'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Therapists accept the Terms at signup, so they need a way to
                // read what they agreed to.
                _MenuGroup(
                  title: l10n.accountGroupAbout,
                  children: [
                    MenuItem.icon(
                      iconData: '🏥',
                      label: l10n.accountAboutUs,
                      onTap: () => context.push('/about'),
                    ),
                    MenuItem.icon(
                      iconData: '🔒',
                      label: l10n.accountPrivacy,
                      onTap: () => context.push('/about/privacy'),
                    ),
                    MenuItem.icon(
                      iconData: '📄',
                      label: l10n.accountTerms,
                      onTap: () => context.push('/about/terms'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmLogout(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.dangerPale),
                        backgroundColor: AppColors.dangerPale,
                      ),
                      child: Text(l10n.actionLogOut),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clears the stored token and cached user before navigating — navigating
  /// alone left the session live.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.logoutTitle),
        content: Text(context.l10n.therapistLogoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.logoutStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.actionLogOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authActionsProvider).logout();
    if (!context.mounted) return;

    // Cached views are cleared on the next sign-in rather than here — see
    // the note in resetAccountScopedProviders.
    context.go('/splash');
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
