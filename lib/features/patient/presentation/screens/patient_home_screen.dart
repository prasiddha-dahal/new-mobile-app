import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:sahayatri_care_connect/core/utils/formatters.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_profile_providers.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../packages/presentation/widgets/active_package_card.dart';
import '../../domain/entities/therapist.dart';
import '../providers/patient_providers.dart';
import '../widgets/review_prompt_banner.dart';
import '../widgets/therapist_row.dart' show avatarTintFor;

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  String _selectedChip = 'All';

  static const _chips = [
    'All',
    'Sports',
    'Neuro',
    'Pediatric',
    'Geriatric',
    'Post-op',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final user = ref.watch(currentUserProvider);
    final dashboard = ref.watch(patientDashboardProvider);
    final featured = ref.watch(featuredTherapistsProvider);
    final next = dashboard.valueOrNull?.nextSession;
    final profile = ref.watch(patientProfileProvider).valueOrNull;

    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim().split(' ').first
        : 'there';

    final nextDate = next == null ? null : DateTime.tryParse(next.date);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientDashboardProvider);
            ref.invalidate(featuredTherapistsProvider);
            ref.invalidate(patientSessionsProvider);
            ref.invalidate(reviewableSessionIdsProvider);
            ref.invalidate(patientProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──────────────────────────────────────
                Row(
                  children: [
                    ProfileAvatar(
                      initials: user?.initials ?? 'P',
                      photoUrl: profile?.photo,
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting(l10n)},',
                            style: text.bodyMedium!.copyWith(fontSize: 15),
                          ),
                          Text(
                            displayName,
                            style: text.titleLarge!.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.homeHeroTitle,
                            style: text.bodySmall!.copyWith(
                              fontSize: 13,
                              height: 1.3,
                              color: AppColors.inkMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Search ────────────────────────────────────────
                GestureDetector(
                  onTap: () => context.push('/patient/find?focus=search'),
                  child: Hero(
                    tag: 'patient-search-bar',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 22,
                              color: AppColors.inkMid,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.homeSearchHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyMedium!.copyWith(
                                  color: AppColors.inkMid,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Upcoming Appointment ──────────────────────────
                _SectionHeader(
                  title: l10n.homeUpcomingTitle,
                  actionLabel: l10n.actionViewAll,
                  onAction: () => context.go('/patient/sessions'),
                ),
                const SizedBox(height: 12),

                if (next != null)
                  _UpcomingCard(
                    therapistName: next.therapistName,
                    specialty: next.type.toUpperCase() == 'HOME_VISIT'
                        ? l10n.homeVisit
                        : l10n.clinicTitle,
                    clinic: '', // or next.address if that field exists
                    dateLabel: formatDayLabelFromString(next.date, l10n),
                    dateSubLabel: nextDate == null
                        ? null
                        : formatFullDate(nextDate, l10n),
                    timeLabel: formatTime12h(next.time),
                    // TODO: pass "(45 minutes)" here once the session model
                    // carries a duration.
                    timeSubLabel: null,
                    therapistPhotoUrl: next.therapistPhotoUrl,
                    therapistPhotoThumbUrl: next.therapistPhotoThumbUrl,
                    onReschedule: () => context.go('/patient/sessions'),
                    onViewProfile: () =>
                        context.push('/patient/therapist/${next.therapistId}'),
                  )
                else
                  _NoUpcomingCard(onFind: () => context.push('/patient/find')),

                const SizedBox(height: 8),
                const ReviewPromptBanner(),

                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ActivePackageCard(
                    onOpen: () => context.push('/patient/packages/mine'),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Quick actions ─────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior:
                      Clip.none, // lets tiles slide out to the screen edge
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _QuickAction(
                        icon: Icons.person_search_outlined,
                        label: l10n.quickActionFindTherapistShort,
                        onTap: () => context.push('/patient/find'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.add_box_outlined,
                        label: l10n.discoveryFindClinicTitle,
                        onTap: () => context.push('/clinics'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.map_outlined,
                        label: l10n.discoveryViewOnMapTitle,
                        onTap: () => context.push('/patient/coverage'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.description_outlined,
                        label: l10n.navReports,
                        onTap: () => context.push('/patient/reports'),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.storefront_outlined,
                        label: l10n.discoveryEquipmentTitle,
                        onTap: () => context.push('/shop'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // ── Popular Physiotherapists ──────────────────────
                _SectionHeader(
                  title: l10n.homeTopTherapists,
                  actionLabel: l10n.actionSeeAll,
                  onAction: () => context.push('/patient/find'),
                ),
                const SizedBox(height: 12),

                // Filter chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _chips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final chip = _chips[i];
                      final active = chip == _selectedChip;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedChip = chip),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: active ? AppColors.ink : AppColors.mist,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                          ),
                          child: Text(
                            chip,
                            style: text.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w500,
                              color: active ? Colors.white : AppColors.inkMid,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Therapist cards (horizontal)
                featured.when(
                  loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => InlineRetry(
                    message: l10n.homeCouldNotLoadTherapists,
                    onRetry: () => ref.invalidate(featuredTherapistsProvider),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return EmptyStateView(
                        title: l10n.homeNoTherapists,
                        icon: Icons.person_search_outlined,
                        compact: true,
                      );
                    }
                    final filtered = _selectedChip == 'All'
                        ? list
                        : list
                              .where(
                                (t) => t.specialty.toLowerCase().contains(
                                  _selectedChip.toLowerCase().split(' ').first,
                                ),
                              )
                              .toList();
                    final show = (filtered.isEmpty ? list : filtered)
                        .take(8)
                        .toList();

                    return SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: show.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final t = show[i];
                          return _PopularTherapistCard(
                            therapist: t,
                            tintIndex: i,
                            onTap: () =>
                                context.push('/patient/therapist/${t.id}'),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers & small widgets ─────────────────────────────────────────

String _greeting(AppLocalizations l10n) {
  final hour = DateTime.now().hour;
  if (hour < 12) return l10n.greetingMorning;
  if (hour < 17) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}

/// A section title on the left and a "View All >" link on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: text.titleSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return SizedBox(
      width: 80,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.mist,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 25, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              // Fixed height so tiles with one- and two-line labels match.
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The soft mint the upcoming-appointment card sits on.
const Color _mint = Color.fromARGB(255, 203, 230, 208);

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.therapistName,
    required this.specialty,
    required this.clinic,
    required this.dateLabel,
    this.dateSubLabel,
    required this.timeLabel,
    this.timeSubLabel,
    this.therapistPhotoUrl,
    this.therapistPhotoThumbUrl,
    required this.onReschedule,
    required this.onViewProfile,
  });

  final String therapistName;
  final String specialty;
  final String clinic;
  final String dateLabel;
  final String? dateSubLabel;
  final String timeLabel;
  final String? timeSubLabel;
  final String? therapistPhotoUrl;
  final String? therapistPhotoThumbUrl;
  final VoidCallback onReschedule;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: AppColors.pinePale),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -34,
            child: Opacity(
              opacity: 0.12,
              child: SvgPicture.asset(
                'assets/images/sahayatri-logo.svg',
                width: 120,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Therapist
                Row(
                  children: [
                    ProfileAvatar(
                      initials: getInitials(therapistName),
                      photoUrl: therapistPhotoUrl,
                      thumbUrl: therapistPhotoThumbUrl,
                      size: 60,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            therapistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specialty,
                            style: text.bodyMedium!.copyWith(fontSize: 13),
                          ),
                          if (clinic.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.pine,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    clinic,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall!.copyWith(
                                      color: AppColors.inkMid,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),

                // Date and time 
                Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        icon: Icons.calendar_today_outlined,
                        title: dateLabel,
                        subtitle: dateSubLabel,
                      ),
                    ),
                    Expanded(
                      child: _InfoBlock(
                        icon: Icons.access_time,
                        title: timeLabel,
                        subtitle: timeSubLabel,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: onReschedule,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.pine,
                            side: const BorderSide(color: AppColors.pine),
                            textStyle: text.titleSmall,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                          ),
                          child: Text(context.l10n.actionReschedule),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: onViewProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pine,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            textStyle: text.titleSmall,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                          ),
                          child: Text(context.l10n.actionViewProfile),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon with a bold line and an optional small line under it.
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.ink),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium!.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoUpcomingCard extends StatelessWidget {
  const _NoUpcomingCard({required this.onFind});
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(context.l10n.homeNothingBooked, style: text.bodyMedium),
          ),
          TextButton(
            onPressed: onFind,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pine,
              textStyle: text.titleSmall,
            ),
            child: Text(context.l10n.homeFindCta),
          ),
        ],
      ),
    );
  }
}

class _PopularTherapistCard extends StatelessWidget {
  const _PopularTherapistCard({
    required this.therapist,
    required this.tintIndex,
    required this.onTap,
  });

  final Therapist therapist;
  final int tintIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Center(
                  child: ProfileAvatar(
                    initials: getInitials(therapist.name),
                    photoUrl: therapist.photoUrl,
                    thumbUrl: therapist.photoThumbUrl,
                    size: 72,
                    tint: avatarTintFor(tintIndex),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              therapist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              therapist.specialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(color: AppColors.inkMid),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: AppColors.amberBrand,
                ),
                const SizedBox(width: 2),
                Text(
                  therapist.isRated
                      ? '${therapist.rating}'
                      : context.l10n.ratingNew,
                  style: text.bodySmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (therapist.isRated)
                  Text(
                    ' (${therapist.reviewCount})',
                    style: text.bodySmall!.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
