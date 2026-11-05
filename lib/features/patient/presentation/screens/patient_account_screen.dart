import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/session.dart';
import '../providers/care_providers.dart';
import '../providers/patient_profile_providers.dart';
import '../providers/patient_providers.dart';

class PatientAccountScreen extends ConsumerWidget {
  const PatientAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final user = ref.watch(currentUserProvider);
    final sessions = ref.watch(patientSessionsProvider);
    final reports = ref.watch(reportsProvider);
    final profile = ref.watch(patientProfileProvider).valueOrNull;
    final given = ref.watch(myReviewsProvider);

    // Counts come from the same lists the destination screens render, so a
    // subtitle can never disagree with what the user finds after tapping.
    final upcoming = sessions.valueOrNull?.where((s) => s.isUpcoming).length;
    // Marked complete -- the same rule as the dashboard and the website. Past
    // also holds visits whose day went by without being closed, and counting
    // those as "completed" gave 20 here against 10 everywhere else (QA DATA-01).
    final completed = sessions.valueOrNull
        ?.where((s) => s.status == SessionStatus.completed)
        .length;
    final sessionMeta = (upcoming == null || completed == null)
        ? null
        : l10n.accountSessionMeta(upcoming, completed);
    final reportCount = reports.valueOrNull?.length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientSessionsProvider);
            ref.invalidate(reportsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  l10n.myProfile,
                  style: text.titleLarge!.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // Who
                Row(
                  children: [
                    // The camera badge opens Edit profile, where the photo is
                    // changed.
                    GestureDetector(
                      onTap: () => context.push('/patient/edit-profile'),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ProfileAvatar(
                              initials: user?.initials ?? '··',
                              // A patient's photo lives on the care record,
                              // not on the account row `currentUserProvider`
                              // reads.
                              photoUrl: profile?.photo,
                              thumbUrl: profile?.photoThumb,
                              tint: AppColors.pinePale,
                              size: 84,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.pine,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.cream,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? l10n.accountLoading,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge!.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // The API exposes no join date, so the second
                            // segment is the city rather than inventing a
                            // "member since" the backend cannot confirm.
                            [
                              (user?.role ?? '').toUpperCase(),
                              (user?.city ?? '').toUpperCase(),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Edit profile
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.push('/patient/edit-profile'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.pine,
                      side: const BorderSide(color: AppColors.pine),
                      textStyle: text.titleSmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: Text(l10n.accountEditProfile),
                  ),
                ),
                const SizedBox(height: 24),

                // Health
                _MenuGroup(
                  title: l10n.accountGroupHealth,
                  children: [
                    _MenuRow(
                      icon: Icons.event_available_outlined,
                      label: l10n.accountMySessions,
                      meta: sessionMeta,
                      onTap: () => context.go('/patient/sessions'),
                    ),
                    _MenuRow(
                      icon: Icons.description_outlined,
                      label: l10n.accountReportsFiles,
                      meta: reportCount == null
                          ? null
                          : l10n.accountReportsMeta(reportCount),
                      onTap: () => context.push('/patient/reports'),
                    ),
                    _MenuRow(
                      icon: Icons.bar_chart_rounded,
                      label: l10n.accountRecovery,
                      // Says up front what is real and what is not yet, so
                      // the screen's "coming soon" sections are no surprise.
                      meta: l10n.accountRecoveryMeta,
                      onTap: () => context.go('/patient/recovery'),
                    ),
                    // "Find a clinic" moved to Home's "What are you looking
                    // for?" block: it starts care, where the rest of this
                    // group is a record of care already had.
                  ],
                ),
                const SizedBox(height: 20),

                // Account
                _MenuGroup(
                  title: l10n.accountGroupAccount,
                  children: [
                    _MenuRow(
                      icon: Icons.location_on,
                      label: l10n.accountSavedAddresses,
                      onTap: () => context.push('/patient/addresses'),
                    ),
                    _MenuRow(
                      icon: Icons.credit_card_outlined,
                      label: l10n.accountPaymentMethods,
                      meta: l10n.accountPaymentMethodsMeta,
                      onTap: () => context.push('/patient/payment-methods'),
                    ),
                    _MenuRow(
                      icon: Icons.notifications_none_rounded,
                      label: l10n.accountNotifications,
                      onTap: () => context.push('/notifications'),
                    ),
                    _MenuRow(
                      icon: Icons.star_outline_rounded,
                      label: l10n.accountMyReviews,
                      meta: given.maybeWhen(
                        data: (list) => l10n.reviewsCount(list.length),
                        orElse: () => null,
                      ),
                      onTap: () => context.push('/patient/reviews'),
                    ),
                    _MenuRow(
                      icon: Icons.redeem_outlined,
                      label: l10n.accountRewards,
                      onTap: () => context.push('/patient/rewards'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Support
                _MenuGroup(
                  title: l10n.accountGroupSupport,
                  children: [
                    _MenuRow(
                      icon: Icons.help_outline_rounded,
                      label: l10n.accountHelp,
                      onTap: () => context.push('/patient/help'),
                    ),
                    _MenuRow(
                      icon: Icons.mail_outline_rounded,
                      label: l10n.accountContact,
                      onTap: () => context.push('/patient/contact'),
                    ),
                    _MenuRow(
                      icon: Icons.warning_amber_rounded,
                      label: l10n.accountReportTherapist,
                      onTap: () => context.push('/patient/report-therapist'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // About
                _MenuGroup(
                  title: l10n.accountGroupAbout,
                  children: [
                    _MenuRow(
                      icon: Icons.info_outline_rounded,
                      label: l10n.accountAboutUs,
                      onTap: () => context.push('/about'),
                    ),
                    _MenuRow(
                      icon: Icons.lock_outline_rounded,
                      label: l10n.accountPrivacy,
                      onTap: () => context.push('/about/privacy'),
                    ),
                    _MenuRow(
                      icon: Icons.article_outlined,
                      label: l10n.accountTerms,
                      onTap: () => context.push('/about/terms'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Log out
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: Text(l10n.actionLogOut),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.dangerPale,
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.dangerPale),
                      textStyle: text.titleSmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clears the stored token and cached user before navigating.
  ///
  /// Navigating alone left the session intact: the JWT stayed in secure
  /// storage, so the next launch resumed as the same signed-in user.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        title: Text(l10n.logoutTitle),
        titleTextStyle: text.titleLarge,
        content: Text(l10n.logoutBody),
        contentTextStyle: text.bodyMedium!.copyWith(height: 1.45),
        actions: [
          // Buttons default to labelLarge (mono, spaced), so the style is set
          // explicitly.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMid,
              textStyle: text.titleSmall,
            ),
            child: Text(l10n.logoutStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              textStyle: text.titleSmall,
            ),
            child: Text(l10n.actionLogOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authActionsProvider).logout();
    if (!context.mounted) return;

    // Cached views are cleared on the next sign-in rather than here: these
    // providers are not autoDispose, so invalidating them while this screen
    // is still listening would refetch without a token and leave a 401 behind.
    context.go('/splash');
  }
}

// ── Menu ─────────────────────────────────────────────────────────────

/// A small uppercase heading over a white card of rows with dividers.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            title.toUpperCase(),
            style: text.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Material, not a coloured Container, so each row's ripple shows
        // and is clipped to the card's rounded corners.
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// An icon, a label, an optional small line and a chevron.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.meta,
  });

  final IconData icon;
  final String label;
  final String? meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.ink),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.titleSmall!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (meta != null && meta!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta!, style: text.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.inkMid,
            ),
          ],
        ),
      ),
    );
  }
}
