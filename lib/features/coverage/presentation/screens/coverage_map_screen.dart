import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/places_map.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/models/coverage_models.dart';
import '../providers/coverage_providers.dart';

/// Who can actually reach you, by area.
class CoverageMapScreen extends ConsumerWidget {
  const CoverageMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppTypography.textTheme;
    final areas = ref.watch(serviceAreasProvider);
    final coverage = ref.watch(coverageProvider);
    final selected = ref.watch(selectedAreaProvider);
    final tab = ref.watch(coverageTabProvider);

    // Pick the first area once the list arrives, so the screen opens with a
    // real answer instead of an empty prompt.
    ref.listen(serviceAreasProvider, (_, next) {
      final list = next.valueOrNull;
      if (list != null &&
          list.isNotEmpty &&
          ref.read(selectedAreaProvider) == null) {
        ref.read(selectedAreaProvider.notifier).state = list.first.id;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
          children: [
            // Back arrow
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/patient/home'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 28,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Text(
                context.l10n.coverageTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: _Heading(context.l10n.coverageYourArea),
            ),
            const SizedBox(height: AppSpacing.md),
            areas.when(
              loading: () => const SizedBox(height: 38),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(serviceAreasProvider),
                ),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      child: Text(
                        context.l10n.coverageNoAreas,
                        style: text.bodyMedium!.copyWith(
                          fontSize: 13,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    )
                  : _AreaChips(
                      areas: list,
                      selected: selected,
                      onPick: (id) =>
                          ref.read(selectedAreaProvider.notifier).state = id,
                    ),
            ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: _Tabs(
                current: tab,
                // Counts appear once the coverage has loaded.
                therapistCount: coverage.valueOrNull?.coveringCount,
                clinicCount: coverage.valueOrNull?.clinics.length,
                onPick: (t) => ref.read(coverageTabProvider.notifier).state = t,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: coverage.when(
                loading: () => const SkeletonBox(height: 240, announce: false),
                // The list below says what went wrong and offers a retry.
                error: (_, _) => const SizedBox.shrink(),
                data: (data) {
                  final areaName =
                      data.area?.name ?? context.l10n.coverageYourAreaFallback;
                  final area = data.area;

                  final places = <MapPlace>[
                    // The centre of the chosen area, when it has been geocoded.
                    if (area != null &&
                        _validPoint(area.latitude, area.longitude))
                      MapPlace(
                        id: area.id,
                        kind: PlaceKind.area,
                        title: areaName,
                        lat: area.latitude!,
                        lng: area.longitude!,
                      ),

                    // Clinics that have a pin. One without coordinates is simply left
                    // off the map; it still appears in the list below.
                    for (final c in data.clinics)
                      if (_validPoint(c.latitude, c.longitude))
                        MapPlace(
                          id: c.id,
                          kind: PlaceKind.clinic,
                          title: c.name,
                          subtitle: c.address.isNotEmpty
                              ? c.address
                              : [
                                  c.area,
                                  c.city,
                                ].where((p) => p.isNotEmpty).join(', '),
                          lat: c.latitude!,
                          lng: c.longitude!,
                        ),

                    // Therapists are not on the map yet: CoverageTherapistDto carries no
                    // coordinates, and a home-visit therapist's address should never be
                    // plotted.
                  ];

                  // Nothing to pin: show no map rather than an empty Google map.
                  if (places.isEmpty) return const SizedBox.shrink();

                  return PlacesMap(
                    height: 240,
                    places: places,
                    onPlaceTap: (p) {
                      switch (p.kind) {
                        case PlaceKind.clinic:
                          context.push('/clinics/${p.id}');
                        case PlaceKind.therapist:
                          context.push('/patient/therapist/${p.id}');
                        case PlaceKind.area:
                          break; // The area is a reference point, not a page.
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            coverage.when(
              loading: () => const SkeletonList(count: 3, itemHeight: 88),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(coverageProvider),
                ),
              ),
              data: (data) => tab == CoverageTab.therapists
                  ? _TherapistCoverage(data: data)
                  : _ClinicList(clinics: data.clinics),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading: bold Inter 18, in place of the mono small-caps label.
class _Heading extends StatelessWidget {
  const _Heading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.textTheme.titleMedium!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: AppColors.ink,
      ),
    );
  }
}

/// A small icon + text fact, used under the name on the list rows.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.inkMid),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              fontSize: 12,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
        ),
      ],
    );
  }
}

/// White card with the thin border and a ripple, for the list rows.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({
    required this.areas,
    required this.selected,
    required this.onPick,
  });

  final List<ServiceAreaDto> areas;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    // Selected = ink fill with white text; unselected = mist.
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: areas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final area = areas[i];
          final active = area.id == selected;
          return GestureDetector(
            onTap: () => onPick(area.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? AppColors.ink : AppColors.mist,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              alignment: Alignment.center,
              child: Text(
                area.name,
                style: text.titleSmall!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: active ? Colors.white : AppColors.inkMid,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Segmented control: a raised white segment on a mist track, each with an
/// optional count badge.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.onPick,
    this.therapistCount,
    this.clinicCount,
  });

  final CoverageTab current;
  final ValueChanged<CoverageTab> onPick;
  final int? therapistCount;
  final int? clinicCount;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        children: [
          for (final tab in CoverageTab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(tab),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 44,
                  decoration: BoxDecoration(
                    color: tab == current ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    boxShadow: tab == current
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          tab == CoverageTab.therapists
                              ? context.l10n.coverageTabTherapists
                              : context.l10n.coverageTabClinics,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: tab == current
                                ? AppColors.pine
                                : AppColors.inkMid,
                          ),
                        ),
                      ),
                      if ((tab == CoverageTab.therapists
                              ? therapistCount
                              : clinicCount) !=
                          null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tab == current
                                ? AppColors.pinePale
                                : Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadii.full),
                          ),
                          child: Text(
                            '${tab == CoverageTab.therapists ? therapistCount : clinicCount}',
                            style: text.bodySmall!.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: tab == current
                                  ? AppColors.pine
                                  : AppColors.inkMid,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TherapistCoverage extends StatelessWidget {
  const _TherapistCoverage({required this.data});

  final CoverageDto data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    if (data.therapists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: EmptyStateView(
          title: l10n.coverageNoTherapists,
          description: l10n.coverageNoTherapistsDesc,
          icon: Icons.person_search_outlined,
        ),
      );
    }

    final areaName = data.area?.name ?? l10n.coverageYourAreaFallback;
    final n = data.coveringCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Text(
            n == 0
                ? l10n.coverageNoneCover(areaName)
                : l10n.coverageCount(n, areaName),
            style: text.bodyMedium!.copyWith(
              fontSize: 14,
              height: 1.45,
              letterSpacing: 0,
              color: AppColors.inkMid,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: _Heading(l10n.coverageCovering),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            children: [
              for (final t in data.therapists) _CoverageRow(therapist: t),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.therapist});

  final CoverageTherapistDto therapist;

  @override
  Widget build(BuildContext context) {
    final t = therapist;
    final text = AppTypography.textTheme;

    // Out-of-range therapists stay listed but read as unavailable — hiding
    // them would make the area look empty.
    final dim = !t.covers;

    return _RowCard(
      onTap: () => context.push('/patient/therapist/${t.id}'),
      child: Row(
        children: [
          Opacity(
            opacity: dim ? 0.55 : 1,
            child: ProfileAvatar(
              initials: getInitials(t.name),
              photoUrl: t.photo,
              thumbUrl: t.photoThumb,
              tint: t.covers ? AppColors.pinePale : AppColors.mist,
              size: 52,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Opacity(
              opacity: dim ? 0.65 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and status share the top line.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusTag(
                        label: t.covers
                            ? context.l10n.coverageCoversYou
                            : context.l10n.coverageOutOfRange,
                        tone: t.covers ? TagTone.green : TagTone.neutral,
                      ),
                    ],
                  ),
                  if (t.specialty.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: 4,
                    children: [
                      if (t.serviceRadiusKm != null)
                        _Fact(
                          icon: Icons.radar,
                          label: context.l10n.coverageRadius(
                            t.serviceRadiusKm!.toDouble(),
                          ),
                        )
                      else if (!t.isBookable && t.clinic != null)
                        _Fact(
                          icon: Icons.local_hospital_outlined,
                          label: t.clinic!.name,
                        ),
                      if (t.distanceKm != null)
                        _Fact(
                          icon: Icons.place_outlined,
                          label: context.l10n.coverageDistanceAway(
                            t.distanceKm!,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: AppColors.inkMid,
          ),
        ],
      ),
    );
  }
}

class _ClinicList extends StatelessWidget {
  const _ClinicList({required this.clinics});

  final List<CoverageClinicDto> clinics;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    if (clinics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: EmptyStateView(
          title: context.l10n.coverageNoClinics,
          description: context.l10n.coverageNoClinicsDesc,
          icon: Icons.local_hospital_outlined,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        children: [
          for (final c in clinics)
            _RowCard(
              onTap: () => context.push('/clinics/${c.id}'),
              child: Row(
                children: [
                  // Mint tile with an icon in place of the hospital emoji.
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        AppColors.pinePale.withAlpha(150),
                        Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_hospital_outlined,
                      size: 26,
                      color: AppColors.pine,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: 4,
                          children: [
                            if ([c.area, c.city].any((p) => p.isNotEmpty))
                              _Fact(
                                icon: Icons.place_outlined,
                                label: [
                                  c.area,
                                  c.city,
                                ].where((p) => p.isNotEmpty).join(', '),
                              ),
                            if (c.hours.isNotEmpty)
                              _Fact(icon: Icons.schedule, label: c.hours),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (c.distanceKm != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mist,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        context.l10n.coverageDistanceKm(c.distanceKm!),
                        style: text.titleSmall!.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// True only for a point inside Nepal. Rejects null, (0, 0), placeholder
/// values and swapped latitude/longitude.
bool _validPoint(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  return lat >= 26.3 && lat <= 30.5 && lng >= 80.0 && lng <= 88.3;
}
