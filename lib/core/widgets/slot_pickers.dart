import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// A date field and a time field for picking one of a therapist's open slots.
///
/// Replaces the strip of day chips and the grid of every time underneath it.
/// Each field shows the current choice in one line and opens a picker when
/// tapped: a calendar where only days with something free can be chosen, and
/// a sheet of that day's free times grouped by part of the day. Two short
/// fields read faster than a fortnight of chips, and the calendar shows at a
/// glance which days are worth looking at.
///
/// [openTimes] maps `YYYY-MM-DD` to that day's open `HH:MM` times. Only days
/// with at least one time are offered, and only those times.
class SlotPickerFields extends StatelessWidget {
  const SlotPickerFields({
    super.key,
    required this.openTimes,
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
  });

  final Map<String, List<String>> openTimes;
  final String? date;
  final String? time;
  final ValueChanged<String> onDate;
  final ValueChanged<String> onTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final times = date == null
        ? const <String>[]
        : sortedTimes(openTimes[date]);
    // Only what is still on offer is shown as chosen: a day that has gone
    // since (after a refresh) or a time taken since is not a choice.
    final shownDate = date != null && times.isNotEmpty ? date : null;
    final shownTime = time != null && times.contains(time) ? time : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerTile(
          key: const ValueKey('slot-date'),
          icon: Icons.calendar_today_outlined,
          label: l10n.slotDateLabel,
          value: shownDate == null ? null : slotDayText(shownDate, l10n),
          placeholder: l10n.slotPickDate,
          onTap: () async {
            final picked = await pickSlotDate(
              context,
              openTimes: openTimes,
              current: date,
            );
            if (picked != null && picked != date) onDate(picked);
          },
        ),
        const SizedBox(height: 10),
        PickerTile(
          key: const ValueKey('slot-time'),
          icon: Icons.schedule_rounded,
          label: l10n.slotTimeLabel,
          // Shown as 12-hour; the value passed on to `onTime` stays `HH:MM`.
          value: shownTime == null ? null : formatTime12h(shownTime),
          placeholder: l10n.slotPickTime,
          caption: date == null ? null : l10n.slotTimesFree(times.length),
          onTap: date == null || times.isEmpty
              ? null
              : () async {
                  final picked = await pickSlotTime(
                    context,
                    times: times,
                    current: shownTime,
                    day: slotDayText(date!, l10n),
                  );
                  if (picked != null) onTime(picked);
                },
        ),
      ],
    );
  }
}

/// `HH:MM` strings in order; they sort as text because they are zero-padded.
List<String> sortedTimes(List<String>? times) =>
    [...?times]..sort((a, b) => a.compareTo(b));

/// "Today · Wed, 7 Oct", "Tomorrow · Thu, 8 Oct", or "Fri, 9 Oct".
String slotDayText(String dateKey, AppLocalizations l10n) {
  final d = DateTime.tryParse(dateKey);
  if (d == null) return dateKey;
  final short = formatShortDate(d, l10n);
  final relative = formatDayLabel(d, l10n);
  return relative == short ? short : '$relative · $short';
}

/// Opens a calendar where only the days in [openTimes] can be chosen. Returns
/// the chosen `YYYY-MM-DD`, or null if dismissed.
Future<String?> pickSlotDate(
  BuildContext context, {
  required Map<String, List<String>> openTimes,
  String? current,
}) async {
  final days =
      openTimes.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => DateTime.tryParse(e.key))
          .whereType<DateTime>()
          .map((d) => DateTime(d.year, d.month, d.day))
          .toList()
        ..sort();
  if (days.isEmpty) return null;
  final open = days.toSet();

  final currentDay = current == null ? null : DateTime.tryParse(current);
  final initial = currentDay != null && open.contains(currentDay)
      ? currentDay
      : days.first;

  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: days.first,
    lastDate: days.last,
    currentDate: DateTime.now(),
    helpText: context.l10n.slotPickDateTitle,
    selectableDayPredicate: (d) =>
        open.contains(DateTime(d.year, d.month, d.day)),
    builder: _datePickerTheme,
  );
  if (picked == null) return null;
  return '${picked.year.toString().padLeft(4, '0')}-'
      '${picked.month.toString().padLeft(2, '0')}-'
      '${picked.day.toString().padLeft(2, '0')}';
}

/// Opens a sheet of [times], grouped into morning, afternoon and evening.
/// Returns the chosen `HH:MM`, or null if dismissed.
Future<String?> pickSlotTime(
  BuildContext context, {
  required List<String> times,
  required String day,
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    // Above the shell's bottom bar, which would otherwise paint over it.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => _TimeSheet(times: times, day: day, current: current),
  );
}

enum _PartOfDay { morning, afternoon, evening }

_PartOfDay _partOf(String time) {
  final hour = int.tryParse(time.split(':').first) ?? 0;
  if (hour < 12) return _PartOfDay.morning;
  if (hour < 17) return _PartOfDay.afternoon;
  return _PartOfDay.evening;
}

class _TimeSheet extends StatelessWidget {
  const _TimeSheet({required this.times, required this.day, this.current});

  final List<String> times;
  final String day;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final groups = <_PartOfDay, List<String>>{};
    for (final t in sortedTimes(times)) {
      groups.putIfAbsent(_partOf(t), () => []).add(t);
    }

    String heading(_PartOfDay p) => switch (p) {
      _PartOfDay.morning => l10n.slotMorning,
      _PartOfDay.afternoon => l10n.slotAfternoon,
      _PartOfDay.evening => l10n.slotEvening,
    };

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.slotPickTime,
                style: text.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                day,
                style: text.bodyMedium!.copyWith(
                  fontSize: 14,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              for (final part in _PartOfDay.values)
                if (groups[part] != null) ...[
                  const SizedBox(height: 20),
                  // Part-of-day heading: Inter, in place of the mono caps.
                  Text(
                    heading(part),
                    style: text.titleSmall!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in groups[part]!)
                        _TimeChip(
                          time: t,
                          selected: t == current,
                          onTap: () => Navigator.of(context).pop(t),
                        ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selected = ink fill with white text; unselected = mist.
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final String time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.ink : AppColors.mist,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              // Shown as 12-hour; the value handed back stays `HH:MM`.
              formatTime12h(time),
              style: text.titleSmall!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: selected ? Colors.white : AppColors.inkMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A field that shows a choice in one line and opens a picker on tap.
class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.caption,
  });

  final IconData icon;
  final String label;

  /// The current choice, or null to show [placeholder].
  final String? value;
  final String placeholder;

  /// A short note on the right, e.g. "4 times free".
  final String? caption;

  /// Null disables the field.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final enabled = onTap != null;
    final hasValue = value != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label, ${value ?? placeholder}',
      // excludeSemantics hides the InkWell's own tap, so the action is
      // declared here or a screen reader cannot open the picker.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        // White, with the field radius; a pine border once something is chosen.
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: BorderSide(
            color: hasValue ? AppColors.pine : AppColors.border,
            width: hasValue ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: enabled ? AppColors.pine : AppColors.inkMute,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label: Inter, in place of the mono caps.
                      Text(
                        label,
                        style: text.bodySmall!.copyWith(
                          fontSize: 12,
                          letterSpacing: 0,
                          color: AppColors.inkMid,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value ?? placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall!.copyWith(
                          fontSize: 15,
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.w400,
                          letterSpacing: 0,
                          color: hasValue
                              ? AppColors.ink
                              : (enabled
                                    ? AppColors.inkMid
                                    : AppColors.inkMute),
                        ),
                      ),
                    ],
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(width: 8),
                  // Gives way to the value on a narrow screen at a large
                  // text size rather than pushing the row off the edge.
                  Flexible(
                    child: Text(
                      caption!,
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
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  color: enabled ? AppColors.inkMid : AppColors.inkMute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gives the calendar dialog the app's look: Inter text with no letter
/// spacing, pine accents and a cream surface. Without it the Cancel / OK
/// buttons and the small labels fall back to the mono theme style.
Widget _datePickerTheme(BuildContext context, Widget? child) {
  final text = AppTypography.textTheme;
  final base = Theme.of(context);

  TextStyle inter(double size, FontWeight weight, [Color? color]) =>
      text.bodyMedium!.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0,
        color: color,
      );

  final buttonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.pine,
    textStyle: inter(14, FontWeight.w600),
  );

  return Theme(
    data: base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.pine,
        onPrimary: Colors.white,
        surface: AppColors.cream,
        onSurface: AppColors.ink,
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        // "Select date" line and the big date under it.
        headerHelpStyle: inter(13, FontWeight.w600, AppColors.inkMid),
        headerHeadlineStyle: inter(24, FontWeight.w700, AppColors.ink),
        // Mon Tue Wed row, the day numbers and the year list.
        weekdayStyle: inter(12, FontWeight.w600, AppColors.inkMid),
        dayStyle: inter(14, FontWeight.w500),
        yearStyle: inter(14, FontWeight.w500),
        // Days with no free time are dimmed; the chosen day is a pine disc.
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return AppColors.inkMute;
          return AppColors.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.pine
              : Colors.transparent;
        }),

        // Today uses these instead of the day* ones, so they have to handle the
        // selected case too: white on the pine disc when today is chosen, pine
        // text with an outline when it is not.
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.pine;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.pine
              : Colors.transparent;
        }),
        todayBorder: const BorderSide(color: AppColors.pine),
        cancelButtonStyle: buttonStyle.copyWith(
          foregroundColor: WidgetStateProperty.all(AppColors.inkMid),
        ),
        confirmButtonStyle: buttonStyle,
      ),
    ),
    child: child!,
  );
}
