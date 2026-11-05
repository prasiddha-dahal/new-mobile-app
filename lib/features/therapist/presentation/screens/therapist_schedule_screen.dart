import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/utils/formatters.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../patient/domain/entities/session.dart';
import '../../../patient/domain/entities/therapist.dart';
import '../../../patient/presentation/providers/patient_providers.dart'
    show formatDateKey;
import '../providers/therapist_providers.dart';

/// Weekday keys, Sunday-indexed to match the API's `days` payload
/// (`isoweekday() % 7`, so Sunday is 0). Values, not labels — [_dayLabel]
/// supplies what the column heading shows.
const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _dayLabel(int index, AppLocalizations l10n) => switch (index) {
  0 => l10n.dayShortSun,
  1 => l10n.dayShortMon,
  2 => l10n.dayShortTue,
  3 => l10n.dayShortWed,
  4 => l10n.dayShortThu,
  5 => l10n.dayShortFri,
  _ => l10n.dayShortSat,
};

/// The three buckets `POST /availability/recurring` accepts. Sent verbatim,
/// so these stay English and [_periodLabel] is what the chip shows.
const _periods = ['Morning', 'Afternoon', 'Evening'];

String _periodLabel(String period, AppLocalizations l10n) => switch (period) {
  'Morning' => l10n.timeBlockMorning,
  'Afternoon' => l10n.timeBlockAfternoon,
  'Evening' => l10n.timeBlockEvening,
  _ => period,
};

class TherapistScheduleScreen extends ConsumerStatefulWidget {
  const TherapistScheduleScreen({super.key});

  @override
  ConsumerState<TherapistScheduleScreen> createState() =>
      _TherapistScheduleScreenState();
}

class _TherapistScheduleScreenState
    extends ConsumerState<TherapistScheduleScreen> {
  final _recurringDays = <int>{1, 2, 3, 4, 5};
  final _recurringPeriods = <String>{'Morning', 'Evening'};
  bool _savingRecurring = false;
  String? _togglingKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final slots = ref.watch(ownSlotsProvider);
    final sessions = ref.watch(therapistSessionsProvider);

    // The next seven days, as real dates — the prototype's abstract Sun–Sat
    // grid could not be tapped against a real calendar.
    final today = DateTime.now();
    final week = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day + i),
    );

    final canSave =
        !_savingRecurring &&
        _recurringDays.isNotEmpty &&
        _recurringPeriods.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownSlotsProvider);
            ref.invalidate(therapistSessionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Title and hint. The mono eyebrow (`scheduleEyebrow`) is
                // dropped. No back arrow: this is a tab, with the app header
                // above it.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.availabilityTitle,
                        style: text.titleLarge!.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.scheduleTapHint,
                        style: text.bodyMedium!.copyWith(
                          height: 1.4,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: slots.when(
                    loading: () => const SkeletonBox(height: 268),
                    error: (e, _) => ErrorStateView(
                      failure: e is Failure ? e : const UnknownFailure(),
                      onRetry: () => ref.invalidate(ownSlotsProvider),
                    ),
                    data: (list) => _SlotGrid(
                      week: week,
                      slots: list,
                      sessions: sessions.valueOrNull ?? const [],
                      togglingKey: _togglingKey,
                      onToggle: _toggleSlot,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Row(
                    children: [
                      _Legend(color: AppColors.pine, label: l10n.slotBooked),
                      const SizedBox(width: AppSpacing.lg),
                      _Legend(color: AppColors.pinePale, label: l10n.slotOpen),
                      const SizedBox(width: AppSpacing.lg),
                      _Legend(color: AppColors.mist, label: l10n.slotOff),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Text(
                    l10n.scheduleRecurring,
                    style: text.titleMedium!.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _dayLabels.length; i++)
                              _Chip(
                                label: _dayLabel(i, l10n),
                                selected: _recurringDays.contains(i),
                                onTap: () => setState(() {
                                  _recurringDays.contains(i)
                                      ? _recurringDays.remove(i)
                                      : _recurringDays.add(i);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in _periods)
                              _Chip(
                                label: _periodLabel(p, l10n),
                                selected: _recurringPeriods.contains(p),
                                onTap: () => setState(() {
                                  _recurringPeriods.contains(p)
                                      ? _recurringPeriods.remove(p)
                                      : _recurringPeriods.add(p);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.scheduleRecurringNote,
                          style: text.bodySmall!.copyWith(
                            fontSize: 12,
                            height: 1.4,
                            letterSpacing: 0,
                            color: AppColors.inkMid,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: canSave ? _saveRecurring : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.pine,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppColors.pine
                                        .withAlpha(90),
                                    disabledForegroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    // Buttons default to labelLarge (mono,
                                    // spaced), so the style is explicit.
                                    textStyle: text.titleSmall!.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.tile,
                                      ),
                                    ),
                                  ),
                                  child: _savingRecurring
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          l10n.scheduleSaveRecurring,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      context.push('/therapist/day-off'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.pine,
                                    side: const BorderSide(
                                      color: AppColors.pine,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    textStyle: text.titleSmall!.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.tile,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.scheduleBlockDate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSlot(String date, String time, bool currentlyOpen) async {
    final confirmed = await _confirmToggle(date, time, currentlyOpen);
    if (!confirmed || !mounted) return;

    final key = '$date $time';
    setState(() => _togglingKey = key);
    final result = await ref
        .read(therapistActionsProvider)
        .setSlot(date: date, time: time, open: !currentlyOpen);
    if (!mounted) return;
    setState(() => _togglingKey = null);
    // The success path used to be empty. The cell only recolours after the
    // provider refetches, so a tap that worked looked exactly like a tap that
    // did nothing — while a tap that failed toasted. The quieter of the two
    // outcomes was the one with no feedback.
    result.match(
      (f) => _toast(f.message, isError: true),
      (_) => _toast(
        currentlyOpen
            ? context.l10n.scheduleSlotClosed
            : context.l10n.scheduleSlotOpened,
      ),
    );
  }

  /// "Open this slot?" or "Close this slot?", naming the day and time.
  /// Returns true only when the therapist confirms.
  Future<bool> _confirmToggle(
    String date,
    String time,
    bool currentlyOpen,
  ) async {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    // "Wed, 29 Oct · 10:30" in the app's own date style when the key parses.
    final parsed = DateTime.tryParse(date);
    final when = parsed == null
        ? '$date $time'
        : formatDateTime(parsed, time, l10n);

    final title = currentlyOpen
        ? l10n.scheduleCloseSlotTitle
        : l10n.scheduleOpenSlotTitle;
    final body = currentlyOpen
        ? l10n.scheduleCloseSlotBody(when)
        : l10n.scheduleOpenSlotBody(when);
    final confirmLabel = currentlyOpen
        ? l10n.scheduleCloseSlotConfirm
        : l10n.scheduleOpenSlotConfirm;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        title: Text(title),
        titleTextStyle: text.titleLarge,
        content: Text(body),
        contentTextStyle: text.bodyMedium!.copyWith(height: 1.45),
        actions: [
          // Buttons default to labelLarge (mono, spaced), so the style is
          // set explicitly.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMid,
              textStyle: text.titleSmall,
            ),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              // Closing takes availability away, so it reads as the cautious
              // action; opening is the plain, positive one.
              foregroundColor: currentlyOpen
                  ? AppColors.danger
                  : AppColors.pine,
              textStyle: text.titleSmall,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _saveRecurring() async {
    setState(() => _savingRecurring = true);
    final result = await ref
        .read(therapistActionsProvider)
        .applyRecurring(
          days: _recurringDays.toList()..sort(),
          sessions: _recurringPeriods.toList(),
        );
    if (!mounted) return;
    setState(() => _savingRecurring = false);

    result.match(
      (f) => _toast(f.message, isError: true),
      (affected) => _toast(
        affected == 0
            ? context.l10n.scheduleRecurringNoneOpened
            : context.l10n.scheduleRecurringOpened(affected),
      ),
    );
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.week,
    required this.slots,
    required this.sessions,
    required this.togglingKey,
    required this.onToggle,
  });

  final List<DateTime> week;
  final List<TherapistSlot> slots;
  final List<Session> sessions;
  final String? togglingKey;
  final void Function(String date, String time, bool currentlyOpen) onToggle;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: EmptyStateView(
          title: context.l10n.scheduleNoCalendarTitle,
          description: context.l10n.scheduleNoCalendarDesc,
          icon: Icons.calendar_month_outlined,
        ),
      );
    }

    final times = slots.map((s) => s.time).toSet().toList()..sort();
    final byKey = {for (final s in slots) '${s.date} ${s.time}': s};
    // A slot is "booked" when a live session sits on it.
    final booked = {
      for (final s in sessions.where((s) => !s.isCancelled))
        '${formatDateKey(s.date)} ${s.time}',
    };
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              ...week.map((d) {
                final isToday =
                    d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        _dayLabel(d.weekday % 7, context.l10n),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: text.bodySmall!.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: isToday ? AppColors.pine : AppColors.inkMid,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        textAlign: TextAlign.center,
                        style: text.titleSmall!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: isToday ? AppColors.pine : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: AppColors.border),
          ),
          ...times.map(
            (time) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        time,
                        textAlign: TextAlign.right,
                        style: text.bodySmall!.copyWith(
                          fontSize: 11,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ),
                  ),
                  ...week.map((d) {
                    final dateKey = formatDateKey(d);
                    final key = '$dateKey $time';
                    final slot = byKey[key];
                    final isBooked = booked.contains(key);
                    final isOpen = slot?.isOpen ?? false;
                    final isBusy = togglingKey == key;
                    // A time that has gone cannot be opened or closed (the
                    // server ignores it); it used to look like a day off and
                    // take the tap.
                    final parts = time.split(':');
                    final start = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      int.tryParse(parts.first) ?? 0,
                      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
                    );
                    final isPast = start.isBefore(DateTime.now());

                    return Expanded(
                      child: GestureDetector(
                        onTap: (slot == null || isBooked || isBusy || isPast)
                            ? null
                            : () => onToggle(dateKey, time, isOpen),
                        child: Container(
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isBooked
                                ? AppColors.pine
                                : isOpen
                                ? AppColors.pinePale
                                : AppColors.mist,
                            borderRadius: BorderRadius.circular(AppRadii.cell),
                          ),
                          alignment: Alignment.center,
                          child: isBusy
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.pine,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-select pill: selected = ink fill with white text, unselected = mist.
class _Chip extends StatelessWidget {
  const _Chip({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: color == AppColors.mist
                ? Border.all(color: AppColors.border)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.textTheme.bodySmall!.copyWith(
            fontSize: 12,
            letterSpacing: 0,
            color: AppColors.inkMid,
          ),
        ),
      ],
    );
  }
}
