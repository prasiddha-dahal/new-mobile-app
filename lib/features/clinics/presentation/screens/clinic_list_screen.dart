import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/clinic.dart';
import '../providers/clinic_providers.dart';

/// Browse in-person clinics.
class ClinicListScreen extends ConsumerStatefulWidget {
  const ClinicListScreen({super.key});

  @override
  ConsumerState<ClinicListScreen> createState() => _ClinicListScreenState();
}

class _ClinicListScreenState extends ConsumerState<ClinicListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Chip labels from the prototype. `All` clears the filter; the rest are sent
  /// as the backend's `city` query parameter.
  static const _cities = ['All', 'Lalitpur', 'Kathmandu', 'Pokhara'];

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(clinicQueryProvider).search;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing so each keystroke does not fire a request.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(clinicQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  void _onCityTap(String label) {
    final notifier = ref.read(clinicQueryProvider.notifier);
    if (label == 'All') {
      notifier.update((q) => q.copyWith(clearCity: true));
    } else {
      notifier.update((q) => q.copyWith(city: label));
    }
  }

  /// City keys are sent to the API as the `city` query parameter, so they
  /// stay English; only the chip label changes.
  String _cityLabel(String value, AppLocalizations l10n) => switch (value) {
    'All' => l10n.filterAll,
    'Lalitpur' => l10n.cityLalitpur,
    'Kathmandu' => l10n.cityKathmandu,
    'Pokhara' => l10n.cityPokhara,
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final query = ref.watch(clinicQueryProvider);
    final results = ref.watch(clinicListProvider);
    final activeCity = query.city ?? 'All';

    // A `Scaffold`, like every other list screen. Without one this was the
    // only list in the app with no cream ground under it, so it drew on
    // whatever the parent happened to be.
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back arrow
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.clinicsTitle,
                    style: text.titleLarge!.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.clinicsSubtitle,
                    style: text.bodyMedium!.copyWith(
                      height: 1.4,
                      letterSpacing: 0,
                      color: AppColors.inkMid,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // City chips: selected = ink fill, unselected = mist.
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: _cities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final label = _cities[i];
                  return _CityChip(
                    label: _cityLabel(label, l10n),
                    selected: label == activeCity,
                    onTap: () => _onCityTap(label),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: results.when(
                loading: () => const SkeletonList(
                  count: 4,
                  itemHeight: 108,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(clinicListProvider),
                ),
                data: (clinics) {
                  if (clinics.isEmpty) {
                    return EmptyStateView(
                      title: l10n.clinicsEmptyTitle,
                      description: query.search.isEmpty
                          ? l10n.clinicsTryAnotherCity
                          : l10n.clinicsNoMatch(query.search),
                      icon: Icons.search_off_outlined,
                      action: const _HomeVisitButton(),
                    );
                  }
                  return ListView(
                    // `AppSpacing.xxl`, not `navBarReservedHeight`. `/clinics`
                    // is a top-level route, outside both `StatefulShellRoute`s,
                    // so no bottom bar is mounted over it — the 96px was
                    // clearing a bar that is not there, leaving a screen's worth
                    // of dead scroll under the last clinic.
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.xxl,
                    ),
                    children: [
                      for (final clinic in clinics) ...[
                        _ClinicResultCard(
                          clinic: clinic,
                          onOpen: () => context.go('/clinics/${clinic.id}'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      const _HomeVisitButton(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White pill, 54px, with a grey circle to clear the text.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 16, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 22, color: AppColors.inkMid),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.l10n.clinicsSearchHint,
                hintStyle: text.bodyMedium!.copyWith(
                  letterSpacing: 0,
                  color: AppColors.inkMute,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                fillColor: Colors.transparent,
                filled: false,
              ),
              style: text.bodyMedium!.copyWith(
                fontSize: 15,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
          ),
          // Clear button, only while there is text. Goes through the same
          // `onChanged` as typing, so the debounce and query update are
          // unchanged.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.mist,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.inkMid,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: text.titleSmall!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: selected ? Colors.white : AppColors.inkMid,
          ),
        ),
      ),
    );
  }
}

class _ClinicResultCard extends StatelessWidget {
  const _ClinicResultCard({required this.clinic, required this.onOpen});

  final Clinic clinic;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mint tile with an icon in place of the hospital emoji.
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
                child: const Icon(
                  Icons.local_hospital_outlined,
                  size: 24,
                  color: AppColors.pine,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clinic.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall!.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The prototype appends a distance to this line and puts a
                    // star rating and a "from Rs …" price in the card footer.
                    // The clinic model carries none of the three.
                    // TODO(api): rating, consultation price and distance on
                    // Clinic (A12 in docs/TODO_REGISTER.md).
                    Text(
                      clinic.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: AppColors.inkMid,
                      ),
                    ),
                    if (clinic.services.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final service in clinic.services)
                            StatusTag(label: service, tone: TagTone.neutral),
                        ],
                      ),
                    ],
                    if (clinic.hours.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: AppColors.inkMute,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              clinic.hours,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall!.copyWith(
                                fontSize: 12,
                                letterSpacing: 0,
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
        ),
      ),
    );
  }
}

/// Secondary escape hatch back to the home-visit flow: white, pine outline.
class _HomeVisitButton extends StatelessWidget {
  const _HomeVisitButton();

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () => context.go('/patient/find'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.pine,
          side: const BorderSide(color: AppColors.pine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          // Buttons default to labelLarge (mono, spaced).
          textStyle: text.titleSmall!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        child: Text(context.l10n.clinicsBookHomeInstead),
      ),
    );
  }
}