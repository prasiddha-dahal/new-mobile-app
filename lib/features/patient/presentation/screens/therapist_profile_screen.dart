import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/media/profile_photo.dart';
import 'package:sahayatri_care_connect/core/widgets/profile_avatar.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/slot_pickers.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/therapist.dart';
import '../providers/patient_providers.dart';

class TherapistProfileScreen extends ConsumerStatefulWidget {
  const TherapistProfileScreen({super.key, required this.therapistId});
  final String therapistId;

  @override
  ConsumerState<TherapistProfileScreen> createState() =>
      _TherapistProfileScreenState();
}

class _TherapistProfileScreenState
    extends ConsumerState<TherapistProfileScreen> {
  /// `YYYY-MM-DD` of the day whose slots are on screen; null until the first
  /// batch of slots arrives and the earliest open day can be picked.

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/patient/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final therapist = ref.watch(therapistDetailProvider(widget.therapistId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: therapist.when(
        loading: () => SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: l10n.profileTitle, onBack: _back),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SkeletonList(count: 3, itemHeight: 96),
              ),
            ],
          ),
        ),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              PageHeader(title: l10n.profileTitle, onBack: _back),
              Expanded(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(
                    therapistDetailProvider(widget.therapistId),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (t) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _back,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                _ProfileHeader(therapist: t),
                const SizedBox(height: 16),
                _StatsRow(therapist: t),

                // Expertise
                const SizedBox(height: 24),
                _SectionTitle(title: l10n.signupSpecializationsLabel),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (t.specialty.isNotEmpty)
                      _ExpertiseChip(label: t.specialty),
                  ],
                ),

                // About
                if (t.bio.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(title: l10n.profileAbout),
                  const SizedBox(height: 8),
                  Text(t.bio, style: text.bodyMedium!.copyWith(height: 1.5)),
                ],

                if (t.workplace != null) ...[
                  const SizedBox(height: 24),
                  _LocationPhoneCard(workplace: t.workplace!),
                ] else if (t.city.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _LocationPhoneCard(
                    workplace: Workplace(id: '', name: t.city, city: t.city),
                  ),
                ],

                // Where the therapist works
                if (t.workplace != null) ...[
                  const SizedBox(height: 24),
                  _WorkplaceCard(workplace: t.workplace!),
                ],

                // TODO: "Patient Feedback" goes here once the app has a
                // reviews list for a therapist (see the notes in the reply).
              ],
            ),
          ),
        ),
      ),

      // An information-only therapist has nothing to book, so the bar is
      // absent rather than present-and-disabled — a greyed button invites
      // people to keep tapping it.
      bottomSheet:
          (therapist.valueOrNull == null || !therapist.value!.isBookable)
          ? null
          : _BookBar(
              fee: therapist.value!.fee,
              ready: true,
              hasTime: false,
              onBook: () =>
                  context.push('/patient/select-slot/${widget.therapistId}'),
            ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.therapist});
  final Therapist therapist;

  @override
  Widget build(BuildContext context) {
    final t = therapist;
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    final where = [
      if (t.workplace != null && t.workplace!.name.isNotEmpty)
        t.workplace!.name,
      if (t.city.isNotEmpty) t.city,
    ].join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoTile(
          photoUrl: t.photoUrl,
          thumbUrl: t.photoThumbUrl,
          initials: t.initials,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge!.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.verified_outlined,
                        size: 22,
                        color: AppColors.pine,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (t.specialty.isNotEmpty)
                  Text(
                    t.specialty,
                    style: text.titleSmall!.copyWith(
                      fontSize: 15,
                      color: AppColors.pine,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppColors.amberBrand,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t.isRated
                            ? '${t.rating} ${l10n.therapistReviewCount(t.reviewCount)}'
                            : l10n.ratingNew,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    where,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The big rounded portrait. Uses the same photo pipeline as [ProfileAvatar]
/// (resolve + cache), but keeps a rectangular crop for the profile layout.
class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    required this.photoUrl,
    required this.thumbUrl,
    required this.initials,
  });

  final String? photoUrl;
  final String? thumbUrl;
  final String initials;

  static const double _width = 148;
  static const double _height = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppTypography.textTheme;

    Widget fallback() => Container(
      color: AppColors.pinePale,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: text.titleLarge!.copyWith(fontSize: 40, color: AppColors.pine),
      ),
    );

    // Prefer full photo for this large tile; fall back to thumb.
    final url = ProfileAvatar.chooseUrl(
      size: _height, // > thumbMaxSize → prefers full photo
      photoUrl: photoUrl,
      thumbUrl: thumbUrl,
    );

    Widget child;
    if (url == null) {
      child = fallback();
    } else {
      final bytes = ref.watch(profilePhotoBytesProvider(url)).valueOrNull;
      if (bytes == null) {
        child = Container(color: AppColors.mist);
      } else {
        final target = (_width * MediaQuery.devicePixelRatioOf(context)).ceil();
        child = Image.memory(
          bytes,
          width: _width,
          height: _height,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: (target * 2).clamp(target, 1024),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback(),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sheet + 4),
      child: SizedBox(width: _width, height: _height, child: child),
    );
  }
}

// ── Stats ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.therapist});
  final Therapist therapist;

  @override
  Widget build(BuildContext context) {
    final t = therapist;
    final l10n = context.l10n;

    return Row(
      children: [
        _StatTile(
          icon: Icons.medical_services_outlined,
          label: l10n.statExperience,
          value: l10n.statYears(t.experienceYears),
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.people_outline_rounded,
          label: l10n.statReviews,
          value: '${t.reviewCount}',
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.star_border_rounded,
          label: l10n.statRating,
          value: t.isRated ? '${t.rating}' : '—',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppColors.pine),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge!.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expertise & section headers ──────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pine,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: text.titleSmall,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _ExpertiseChip extends StatelessWidget {
  const _ExpertiseChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: text.bodyMedium!.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Availability ─────────────────────────────────────────────────────

class _AllSlotsSheet extends StatefulWidget {
  const _AllSlotsSheet({
    required this.openTimes,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  final Map<String, List<String>> openTimes;
  final String date;
  final String? time;
  final ValueChanged<String> onPickDate;
  final ValueChanged<String> onPickTime;

  @override
  State<_AllSlotsSheet> createState() => _AllSlotsSheetState();
}

class _AllSlotsSheetState extends State<_AllSlotsSheet> {
  late String _date = widget.date;
  late String? _time = widget.time;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.profileBookSlot,
              style: text.titleLarge!.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SlotPickerFields(
              openTimes: widget.openTimes,
              date: _date,
              time: _time,
              onDate: (d) {
                setState(() {
                  _date = d;
                  _time = null;
                });
                widget.onPickDate(d);
              },
              onTime: (t) {
                setState(() => _time = t);
                widget.onPickTime(t);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pine,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: text.titleMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
                child: Text(l10n.actionDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Where to visit ───────────────────────────────────────────────────



/// Address, hours, phone and services, all read from the linked clinic so
/// they have one source of truth.
class _WorkplaceCard extends StatelessWidget {
  const _WorkplaceCard({required this.workplace});
  final Workplace workplace;

  @override
  Widget build(BuildContext context) {
    final w = workplace;
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final address = w.address.isNotEmpty ? w.address : w.location;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkplaceLine(
            icon: Icons.location_on_outlined,
            title: w.name,
            subtitle: address,
          ),
          if (w.hours.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WorkplaceLine(
              icon: Icons.access_time,
              title: w.hours,
              semanticLabel: l10n.labelHours,
            ),
          ],
          if (w.phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WorkplaceLine(
              icon: Icons.phone_outlined,
              title: w.phone,
              semanticLabel: l10n.labelPhone,
            ),
          ],
          if (w.services.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Text(l10n.labelServices, style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final service in w.services)
                  StatusTag(label: service, tone: TagTone.neutral),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkplaceLine extends StatelessWidget {
  const _WorkplaceLine({
    required this.icon,
    required this.title,
    this.subtitle,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Semantics(
      label: semanticLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.pine),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: subtitle == null
                      ? text.bodyMedium!.copyWith(color: AppColors.ink)
                      : text.titleSmall!.copyWith(fontSize: 15),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ───────────────────────────────────────────────────────

/// Fee on the left, Book Appointment on the right.
class _BookBar extends StatelessWidget {
  const _BookBar({
    required this.fee,
    required this.ready,
    required this.hasTime,
    required this.onBook,
  });

  final double fee;
  final bool ready;
  final bool hasTime;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profilePriceLabel, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(fee, l10n),
                  style: text.titleLarge!.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: ready ? onBook : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.pine.withAlpha(90),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    // Buttons default to labelLarge (mono, spaced), so the
                    // style has to be given here.
                    textStyle: text.titleMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          hasTime
                              ? l10n.profileContinueCta
                              : l10n.profilePickSlotCta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasTime) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact location + phone row, matching the profile design.
class _LocationPhoneCard extends StatelessWidget {
  const _LocationPhoneCard({required this.workplace});

  final Workplace workplace;

  @override
  Widget build(BuildContext context) {
    final w = workplace;
    final text = AppTypography.textTheme;
    final title = w.name.isNotEmpty
        ? w.name
        : [w.area, w.city].where((s) => s.isNotEmpty).join(', ');
    final subtitle = w.address.isNotEmpty
        ? w.address
        : [w.area, w.city].where((s) => s.isNotEmpty).join(', ');

    if (title.isEmpty && w.phone.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (title.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.pine,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleSmall!.copyWith(fontSize: 14),
                      ),
                      if (subtitle.isNotEmpty && subtitle != title)
                        Text(subtitle, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          if (title.isNotEmpty && w.phone.isNotEmpty)
            const SizedBox(height: 12),
          if (w.phone.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: AppColors.pine,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    w.phone,
                    style: text.bodyMedium!.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
