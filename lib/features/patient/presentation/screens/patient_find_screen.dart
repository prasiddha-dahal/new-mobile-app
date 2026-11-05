import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/therapist.dart';
import '../providers/availability_providers.dart';
import '../providers/patient_providers.dart';
import '../widgets/availability_filter_bar.dart';
import '../widgets/discovery_section.dart';
import '../widgets/next_free_slot_line.dart';
import '../widgets/therapist_row.dart' show avatarTintFor;

class PatientFindScreen extends ConsumerStatefulWidget {
  const PatientFindScreen({super.key, this.autofocusSearch = false});

  final bool autofocusSearch;

  @override
  ConsumerState<PatientFindScreen> createState() => _PatientFindScreenState();
}

class _PatientFindScreenState extends ConsumerState<PatientFindScreen> {
  String _filter = 'All';
  final _searchController = TextEditingController();
  Timer? _debounce;

  final _filters = [
    'All',
    'Sports',
    'Neuro',
    'Pediatric',
    'Geriatric',
    'Post-op',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing before querying, so a five-letter search is
  /// one request rather than five.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(therapistQueryProvider.notifier).state = ref
          .read(therapistQueryProvider)
          .copyWith(search: value.trim());
    });
  }

  /// Chips filter on the client.
  ///
  /// The backend matches `specialty` exactly, so sending "Sports" would return
  /// nothing against the stored "Sports & post-surgery". Typed text still goes
  /// to the server, which does a case-insensitive contains.
  List<Therapist> _applyChip(List<Therapist> all) {
    if (_filter == 'All') return all;
    final needle = _filter.toLowerCase();
    return all
        .where((t) => t.specialty.toLowerCase().contains(needle))
        .toList();
  }

  /// What a filter chip shows for the value it filters on.
  ///
  /// The values are matched against the stored `specialty`, so they stay
  /// English; only the label changes. 'All' is not a specialism at all — it
  /// is the absence of one — which is why it has its own key.
  String _filterLabel(String value, AppLocalizations l10n) => switch (value) {
    'All' => l10n.filterAll,
    'Sports' => l10n.filterSports,
    'Neuro' => l10n.optionNeuro,
    'Pediatric' => l10n.optionPediatric,
    'Geriatric' => l10n.optionGeriatric,
    'Post-op' => l10n.optionPostOp,
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final therapists = ref.watch(therapistListProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBackButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/patient/home'),
                          gutter: false,
                        ),
                        Text(
                          l10n.findTitle,
                          style: text.titleLarge!.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
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
                                Icons.search_rounded,
                                size: 22,
                                color: AppColors.inkMid,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: widget.autofocusSearch,
                                  onChanged: _onSearchChanged,
                                  textInputAction: TextInputAction.search,
                                  style: text.bodyMedium!.copyWith(
                                    color: AppColors.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.findSearchHint,
                                    hintStyle: text.bodyMedium!.copyWith(
                                      color: AppColors.inkMid,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _searchController,
                                builder: (context, value, _) {
                                  if (value.text.isEmpty) {
                                    return const SizedBox(width: 8);
                                  }
                                  return GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: const BoxDecoration(
                                        color: AppColors.mist,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // The specialism is a dropdown rather than a row of chips:
                  // six chips ran off the right edge, so the last ones were
                  // reachable only by guessing that the row scrolled. A menu
                  // shows every option at once and leaves room beside it for
                  // the availability filter, which narrows on a different
                  // axis: "a neuro physio, on Thursday afternoon" is one
                  // question.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Each control gets exactly half the row, whatever the label says.
                        const gap = 8.0;
                        final half = (constraints.maxWidth - gap) / 2;
                        return Row(
                          children: [
                            SizedBox(
                              width: half,
                              child: _SpecialtyDropdown(
                                value: _filter,
                                options: _filters,
                                labelOf: (v) => _filterLabel(v, l10n),
                                allLabel: l10n.findSpecialtyAll,
                                onChanged: (v) => setState(() => _filter = v),
                              ),
                            ),
                            const SizedBox(width: gap),
                            SizedBox(
                              width: half,
                              child: const AvailabilityFilterBar(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // The other two ways to find care, offered where someone is
                  // already looking. They sit above the results on purpose:
                  // a row at the top of the scroll is still reachable after a
                  // hundred therapists, where anything inside the list would
                  // not be.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        for (var i = 0; i < discoveryShortcuts.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          // Equal halves rather than natural widths, so a
                          // longer label or a large text scale ellipsises
                          // instead of running off the right edge.
                          Expanded(
                            child: DiscoveryShortcut(
                              entry: discoveryShortcuts[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                    ],
                ),
            Expanded(
              child: therapists.when(
                loading: () => const SkeletonList(
                  count: 4,
                  itemHeight: 96,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(therapistListProvider),
                ),
                data: (all) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(therapistListProvider);
                    ref
                        .read(therapistAvailabilityProvider.notifier)
                        .refreshAll();
                  },
                  child: _results(_applyChip(all), l10n),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list, narrowed by the availability filter when one is set.
  ///
  /// Three outcomes have to stay distinguishable, and collapsing any pair of
  /// them would lie to the reader:
  ///
  /// * **Nobody matched the search at all** — the existing empty state.
  /// * **Everyone was checked and none is free then** — a real answer, which
  ///   must not look like a failure.
  /// * **We have not finished asking** — a short list with a footer saying so,
  ///   because a partial list presented as final is the worst of the three.
  Widget _results(List<Therapist> chipped, AppLocalizations l10n) {
    if (chipped.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          EmptyStateView(
            title: l10n.findNoMatches,
            icon: Icons.search_off_outlined,
          ),
        ],
      );
    }

    final filter = ref.watch(availabilityFilterProvider);
    if (filter == null) return _cards(chipped);

    // The filter cannot hide anyone without knowing their calendar, so every
    // candidate is asked about. That is N requests against an API with no
    // bulk endpoint — bounded to four in flight, cached per therapist, and
    // behind an explicit user action. Safe during build: the notifier queues
    // and drains in a microtask.
    ref
        .read(therapistAvailabilityProvider.notifier)
        .request(chipped.where((t) => t.isBookable).map((t) => t.id));

    final partition = partitionByAvailability(
      therapists: chipped,
      lookups: ref.watch(therapistAvailabilityProvider),
      filter: filter,
    );

    if (partition.isDefinitelyEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          EmptyStateView(
            title: l10n.findNoneFreeTitle,
            description: l10n.findNoneFreeDesc,
            icon: Icons.event_busy_outlined,
          ),
        ],
      );
    }

    return _cards(
      partition.matching,
      footer: _PartitionFooter(
        pending: partition.pending.length,
        unchecked: partition.unchecked.length,
        onRetry: () => ref
            .read(therapistAvailabilityProvider.notifier)
            .retry(partition.unchecked.map((t) => t.id)),
      ),
    );
  }

  Widget _cards(List<Therapist> list, {Widget? footer}) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: list.length + (footer == null ? 0 : 1),
      itemBuilder: (_, i) {
        if (i == list.length) return footer!;
        return _TherapistCard(
          therapist: list[i],
          tintIndex: i,
          onOpen: () => context.push('/patient/therapist/${list[i].id}'),
        );
      },
    );
  }
}

/// The line under a filtered list saying what is not in it yet, and why.
///
/// Renders nothing when there is nothing to say, so the common case — the
/// answer is in and complete — carries no furniture.
class _PartitionFooter extends StatelessWidget {
  const _PartitionFooter({
    required this.pending,
    required this.unchecked,
    required this.onRetry,
  });

  final int pending;
  final int unchecked;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    if (pending == 0 && unchecked == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending > 0)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.pine,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.findCheckingMore(pending),
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          if (unchecked > 0)
            Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: 14,
                  color: AppColors.inkMute,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.findCouldNotCheck(unchecked),
                    style: text.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pine,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: text.titleSmall!.copyWith(fontSize: 12),
                  ),
                  child: Text(l10n.actionTryAgain),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  const _TherapistCard({
    required this.therapist,
    required this.tintIndex,
    required this.onOpen,
  });

  final Therapist therapist;
  final int tintIndex;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = therapist;
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Person at the very top.
            GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  ProfileAvatar(
                    initials: t.initials,
                    photoUrl: t.photoUrl,
                    thumbUrl: t.photoThumbUrl,
                    tint: avatarTintFor(tintIndex),
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.inkMid,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                t.city,
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Specialty and experience
            Row(
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  size: 15,
                  color: AppColors.inkMid,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  ' · ${l10n.therapistYearsExp(t.experienceYears)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Rating
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: AppColors.amberBrand,
                ),
                const SizedBox(width: 3),
                Text(
                  t.isRated ? '${t.rating}' : l10n.ratingNew,
                  style: text.titleSmall!.copyWith(fontSize: 13),
                ),
                if (t.isRated)
                  Text(
                    ' ${l10n.therapistReviewCount(t.reviewCount)}',
                    style: text.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // The answer to "who can see me soonest", on the card rather
            // than three taps inside the profile. Only a therapist who is
            // booked through the app has slots at all; an information-only
            // listing is visited at their clinic, so there is nothing here
            // to promise.
            if (t.isBookable) NextFreeSlotLine(therapistId: t.id),
            const SizedBox(height: 12),

            // Price and Book now.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible, because the fee and the button are the only two
                // things on this row and the button must not be pushed off
                // the edge: Nepali runs longer than English, a five-figure
                // fee is longer again, and a reader with large text has both.
                Flexible(
                  child: Text.rich(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatCurrency(t.fee, l10n),
                          style: text.titleMedium,
                        ),
                        TextSpan(
                          text: ' ${l10n.therapistPerSession}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pine,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      minimumSize: Size.zero,
                      // Buttons default to labelLarge (mono, spaced), so the
                      // style has to be given here.
                      textStyle: text.titleSmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: Text(l10n.actionBookNow),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill that opens a menu of every specialism.
///
/// Styled to match the availability pill beside it, and highlighted the same
/// way when it is narrowing the list, so the two read as one control strip.
class _SpecialtyDropdown extends StatelessWidget {
  const _SpecialtyDropdown({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.allLabel,
    required this.onChanged,
  });

  /// The selected value -- `'All'` for no narrowing.
  final String value;

  /// Values, not labels: matched against the stored `specialty`, so they stay
  /// English while [labelOf] translates what is shown.
  final List<String> options;
  final String Function(String value) labelOf;

  /// What the pill says while nothing is chosen. "All" alone, on a pill, does
  /// not say all of what.
  final String allLabel;
  final ValueChanged<String> onChanged;

  bool get _active => value != 'All';

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final label = _active ? labelOf(value) : allLabel;
    final fg = _active ? AppColors.pine : AppColors.inkMid;

    TextStyle sans(Color color, FontWeight weight, double size) =>
        text.bodyMedium!.copyWith(
          fontFamily: AppTypography.fontSans,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: 0,
          color: color,
        );

    return LayoutBuilder(
      builder: (context, constraints) => PopupMenuButton<String>(
        constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
        initialValue: value,
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: const BorderSide(color: AppColors.border),
        ),
        itemBuilder: (_) => [
          for (final option in options)
            PopupMenuItem<String>(
              value: option,
              height: 44,
              textStyle: sans(AppColors.ink, FontWeight.w500, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option == 'All' ? allLabel : labelOf(option),
                      style: sans(
                        option == value ? AppColors.pine : AppColors.ink,
                        option == value ? FontWeight.w600 : FontWeight.w500,
                        14,
                      ),
                    ),
                  ),
                  if (option == value)
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.pine,
                    ),
                ],
              ),
            ),
        ],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _active ? AppColors.pinePale : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: _active ? AppColors.pine : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(Icons.medical_services_outlined, size: 16, color: fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(
                    fg,
                    _active ? FontWeight.w600 : FontWeight.w500,
                    13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
