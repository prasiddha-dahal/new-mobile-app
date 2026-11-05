import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/therapist.dart';
import '../providers/patient_providers.dart';

/// Step one of booking: pick a day and a time from the therapist's open slots.
/// Continue goes to the confirm-booking screen with the choice in the query.
class SelectSlotScreen extends ConsumerStatefulWidget {
  const SelectSlotScreen({super.key, required this.therapistId});

  final String therapistId;

  @override
  ConsumerState<SelectSlotScreen> createState() => _SelectSlotScreenState();
}

class _SelectSlotScreenState extends ConsumerState<SelectSlotScreen> {
  static const double _itemWidth = 56;
  static const double _itemGap = 10;
  static const double _dayBoxHeight = 80;
  static const double _stripHeight = 112;

  /// `YYYY-MM-DD`. Null until the user picks; the earliest open day is used
  /// until then.
  String? _date;
  String? _time;
  final _strip = ScrollController();

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/patient/therapist/${widget.therapistId}');
    }
  }

  void _pickDate(String date, {int? scrollToIndex}) {
    setState(() {
      _date = date;
      _time = null;
    });
    if (scrollToIndex != null && _strip.hasClients) {
      final target = scrollToIndex * (_itemWidth + _itemGap);
      _strip.animateTo(
        target.clamp(0.0, _strip.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openCalendar(List<String> dates, String active) async {
    final parsed = dates.map(DateTime.tryParse).whereType<DateTime>().toList();
    if (parsed.isEmpty) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(active) ?? parsed.first,
      firstDate: parsed.first,
      lastDate: parsed.last,
      selectableDayPredicate: (d) => dates.contains(_key(d)),
      builder: (ctx, child) {
        final base = Theme.of(ctx);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(primary: AppColors.pine),
            // "Select date" title
            datePickerTheme: base.datePickerTheme.copyWith(
              headerHeadlineStyle: const TextStyle(
                fontFamily: AppTypography.fontSans, // Inter
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              headerHelpStyle: const TextStyle(
                fontFamily: AppTypography.fontSans,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.inkMid,
              ),
              weekdayStyle: const TextStyle(
                fontFamily: AppTypography.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              dayStyle: const TextStyle(
                fontFamily: AppTypography.fontSans,
                fontSize: 14,
              ),
            ),
            // Cancel / OK
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pine,
                textStyle: const TextStyle(
                  fontFamily: AppTypography.fontSans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    final key = _key(picked);
    _pickDate(key, scrollToIndex: dates.indexOf(key));
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(therapistSlotsProvider(widget.therapistId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 20, 0),
              child: IconButton(
                onPressed: _back,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: AppColors.ink,
                ),
              ),
            ),
            Expanded(
              child: slots.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: SkeletonList(count: 3, itemHeight: 72),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(
                    therapistSlotsProvider(widget.therapistId),
                  ),
                ),
                data: _buildContent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<TherapistSlot> all) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final locale = Localizations.localeOf(context).toString();

    String fmt(DateTime d, String pattern) {
      try {
        return DateFormat(pattern, locale).format(d);
      } catch (_) {
        return DateFormat(pattern).format(d);
      }
    }

    final openTimes = <String, List<String>>{};
    for (final slot in all.where((s) => s.isOpen)) {
      openTimes.putIfAbsent(slot.date, () => []).add(slot.time);
    }

    if (openTimes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: EmptyStateView(
          title: l10n.profileNoOpenSlots,
          description: l10n.profileNoOpenSlotsDesc,
          icon: Icons.event_busy_outlined,
        ),
      );
    }

    for (final times in openTimes.values) {
      times.sort();
    }

    final dates = openTimes.keys.toList()..sort();
    final weekDates = dates.take(7).toList();
    final active = (_date != null && openTimes.containsKey(_date))
    ? _date!
    : weekDates.first;
    final times = openTimes[active]!;
    final selectedTime = times.contains(_time) ? _time : null;
    final activeDate = DateTime.tryParse(active);

    final morning = <String>[];
    final afternoon = <String>[];
    final evening = <String>[];
    for (final t in times) {
      final h = _hour24(t);
      if (h < 12) {
        morning.add(t);
      } else if (h < 17) {
        afternoon.add(t);
      } else {
        evening.add(t);
      }
    }

    // Prefer l10n when keys exist; fall back to English labels.
    String morningLabel;
    String afternoonLabel;
    String eveningLabel;
    try {
      morningLabel = l10n.timeBlockMorning;
      afternoonLabel = l10n.timeBlockAfternoon;
      eveningLabel = l10n.timeBlockEvening;
    } catch (_) {
      morningLabel = 'Morning';
      afternoonLabel = 'Afternoon';
      eveningLabel = 'Evening';
    }

    final groups = <(String, List<String>)>[
      (morningLabel, morning),
      (afternoonLabel, afternoon),
      (eveningLabel, evening),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.selectDateTime,
                    style: text.titleLarge!.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          activeDate == null
                              ? active
                              : fmt(activeDate, 'MMMM y'),
                          style: text.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openCalendar(dates, active),
                        tooltip: l10n.profileBookSlot,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 26,
                          color: AppColors.pine,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _stripHeight,
                  child: ListView.separated(
                    controller: _strip,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: weekDates.length,
                    separatorBuilder: (_, _) => const SizedBox(width: _itemGap),
                    itemBuilder: (_, i) {
                      final d = DateTime.tryParse(weekDates[i]);
                      return _DayItem(
                        width: _itemWidth,
                        height: _dayBoxHeight,
                        weekday: d == null ? '' : fmt(d, 'EEE'),
                        day: d == null ? weekDates[i] : '${d.day}',
                        selected: weekDates[i] == active,
                        onTap: () => _pickDate(weekDates[i]),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.availableTimeSlots,
                        style: text.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final group in groups) ...[
                        const SizedBox(height: 16),
                        Text(
                          group.$1,
                          style: text.bodyMedium!.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 10.0;
                            final width = (constraints.maxWidth - gap * 2) / 3;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final t in group.$2)
                                  _TimeChip(
                                    width: width,
                                    label: _time12(t),
                                    selected: t == selectedTime,
                                    onTap: () => setState(() => _time = t),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: selectedTime == null
                  ? null
                  : () => context.push(
                      '/patient/booking/${widget.therapistId}'
                      '?date=$active&time=$selectedTime',
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pine,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.pine.withAlpha(90),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                textStyle: text.titleMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: Text(l10n.profileContinueCta),
            ),
          ),
        ),
      ],
    );
  }
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

int _hour24(String raw) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([ap])?',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) return 0;
  var h = int.parse(m.group(1)!);
  final ap = m.group(3)?.toLowerCase();
  if (ap == 'p' && h < 12) h += 12;
  if (ap == 'a' && h == 12) h = 0;
  return h;
}

String _time12(String raw) {
  final value = raw.trim();
  if (RegExp(r'[ap]\.?m\.?$', caseSensitive: false).hasMatch(value)) {
    return value;
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value;
  final hour = int.parse(match.group(1)!);
  if (hour > 23) return value;
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${match.group(2)} $period';
}

class _DayItem extends StatelessWidget {
  const _DayItem({
    required this.width,
    required this.height,
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final double height;
  final String weekday;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Text(
              weekday,
              maxLines: 1,
              style: text.bodySmall!.copyWith(
                fontSize: 13,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: width,
              height: height, // taller box
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.pine : Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(
                  color: selected ? AppColors.pine : AppColors.border,
                ),
              ),
              child: Text(
                day,
                style: text.titleLarge!.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.width,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.pine : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? AppColors.pine : AppColors.inkMute,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: text.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
