import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/availability.dart';
import '../providers/availability_providers.dart';
import '../providers/patient_providers.dart';

/// What to call a window: the preset's name, or the span itself when the
/// patient picked their own two times.
String slotWindowLabel(SlotWindow window, AppLocalizations l10n) {
  if (window == SlotWindow.anyTime) return l10n.findWindowAnyTime;
  if (window == SlotWindow.morning) return l10n.findWindowMorning;
  if (window == SlotWindow.afternoon) return l10n.findWindowAfternoon;
  if (window == SlotWindow.evening) return l10n.findWindowEvening;
  return slotWindowRange(window, l10n);
}

/// A window as two clock times — `9:00 AM – 12:00 PM`.
String slotWindowRange(SlotWindow window, AppLocalizations l10n) =>
    l10n.findWindowRange(
      formatSlotTime(window.fromLabel, l10n),
      formatSlotTime(window.toLabel, l10n),
    );

String availabilityFilterLabel(
  AvailabilityFilter? filter,
  AppLocalizations l10n,
) {
  // Constant label — selection is only reflected by active style + Clear.
  return l10n.findWhenPillLabel; // or a new key, e.g. l10n.findWhenPillLabel
}

/// The "when are you free?" control on the Find screen.
///
/// Sits beside the specialism dropdown rather than replacing it: this narrows
/// on a different axis, and someone looking for a neuro physio on Thursday
/// afternoon wants both. Styled to match the dropdown pill exactly (16px
/// icons, 13px Inter, w500 idle / w600 active, pinePale when active).
class AvailabilityFilterBar extends ConsumerWidget {
  const AvailabilityFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final filter = ref.watch(availabilityFilterProvider);
    final active = filter != null;
    final fg = active ? AppColors.pine : AppColors.inkMid;

    return GestureDetector(
      onTap: () => _open(context, ref),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.pinePale : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: active ? AppColors.pine : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(Icons.event_available_rounded, size: 16, color: fg),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                availabilityFilterLabel(filter, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium!.copyWith(
                  fontFamily: AppTypography.fontSans,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: fg),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final current = ref.read(availabilityFilterProvider);
    final choice = await showModalBottomSheet<_FilterChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (_) => _AvailabilityFilterSheet(initial: current),
    );
    // A dismissed sheet returns null and must leave the filter alone; only an
    // explicit Show or Clear answers with a choice.
    if (choice == null) return;
    ref.read(availabilityFilterProvider.notifier).state = choice.filter;
  }
}

/// Wraps the sheet's answer so that "cleared" (a null filter) can be told
/// apart from "dismissed" (no answer at all).
class _FilterChoice {
  const _FilterChoice(this.filter);
  final AvailabilityFilter? filter;
}

class _AvailabilityFilterSheet extends StatefulWidget {
  const _AvailabilityFilterSheet({required this.initial});

  final AvailabilityFilter? initial;

  @override
  State<_AvailabilityFilterSheet> createState() =>
      _AvailabilityFilterSheetState();
}

class _AvailabilityFilterSheetState extends State<_AvailabilityFilterSheet> {
  late final List<String> _days;
  late String _date;
  late SlotWindow _window;
  late bool _exact;

  static const _presets = [
    SlotWindow.anyTime,
    SlotWindow.morning,
    SlotWindow.afternoon,
    SlotWindow.evening,
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // Only days the availability cache already covers are offered. Letting
    // someone pick day 20 would mean a second fetch per therapist for a
    // window nothing else uses.
    _days = [
      for (var i = 0; i < availabilityHorizonDays; i++)
        formatDateKey(today.add(Duration(days: i))),
    ];
    _date = widget.initial?.date ?? _days.first;
    if (!_days.contains(_date)) _date = _days.first;
    _window = widget.initial?.window ?? SlotWindow.anyTime;
    _exact = !_presets.contains(_window);
  }

  /// A calendar for the day, alongside the quick pills.
  ///
  /// Bounded to the days the availability cache covers -- the same fortnight
  /// the pills offer. A calendar that let someone choose day 20 would be
  /// asking for slots nothing has fetched, and would answer "nobody is free"
  /// for every therapist: a wrong answer that looks like a real one. The
  /// helper line under the field says why the dates stop where they do.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last = first.add(const Duration(days: availabilityHorizonDays - 1));
    var initial = DateTime.tryParse(_date) ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = formatDateKey(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final minutes = isStart ? _window.fromMinutes : _window.toMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    final value = picked.hour * 60 + picked.minute;
    setState(() {
      // Dragging one end past the other is a slip, not a request for an empty
      // window, so the other end follows rather than the range inverting.
      _window = isStart
          ? SlotWindow(
              fromMinutes: value,
              toMinutes: value > _window.toMinutes ? value : _window.toMinutes,
            )
          : SlotWindow(
              fromMinutes: value < _window.fromMinutes
                  ? value
                  : _window.fromMinutes,
              toMinutes: value,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;

    // Section label: Inter, in place of the mono `labelLarge`.
    TextStyle sectionLabel() => text.titleSmall!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.ink,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Title, with Clear on the same row so the Apply button below
            // keeps its full width whether or not a filter is set.
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.findWhenSheetTitle,
                    style: text.titleLarge!.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (widget.initial != null)
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const _FilterChoice(null)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pine,
                      foregroundColor: AppColors.mist,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      // Buttons default to labelLarge (mono, spaced).
                      textStyle: text.titleSmall!.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    child: Text(l10n.findWhenClear),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.findWhenSheetSubtitle,
              style: text.bodyMedium!.copyWith(
                fontSize: 13,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.findWhenDayLabel, style: sectionLabel()),
            const SizedBox(height: 8),
            _DateField(
              label: l10n.findWhenCalendarLabel,
              value: formatFullDate(
                DateTime.tryParse(_date) ?? DateTime.now(),
                l10n,
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.findWhenCalendarRange(availabilityHorizonDays),
              style: text.bodySmall!.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final day = _days[i];
                  return _Pill(
                    label: formatDayLabelFromString(day, l10n),
                    selected: day == _date,
                    onTap: () => setState(() => _date = day),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.findWhenTimeLabel, style: sectionLabel()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  _Pill(
                    label: slotWindowLabel(preset, l10n),
                    selected: !_exact && _window == preset,
                    width: 112,
                    onTap: () => setState(() {
                      _exact = false;
                      _window = preset;
                    }),
                  ),
                _Pill(
                  label: l10n.findWindowExact,
                  selected: _exact,
                  width: 112,
                  onTap: () => setState(() {
                    if (_exact) return;
                    _exact = true;
                    // Start from a plausible hour rather than the whole day,
                    // which would make "exact" mean nothing until both ends
                    // are moved.
                    if (_window == SlotWindow.anyTime) {
                      _window = SlotWindow.morning;
                    }
                  }),
                ),
              ],
            ),
            if (_exact) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: l10n.findWindowFrom,
                      value: formatSlotTime(_window.fromLabel, l10n),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TimeField(
                      label: l10n.findWindowTo,
                      value: formatSlotTime(_window.toLabel, l10n),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Apply, always full width.
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  _FilterChoice(
                    AvailabilityFilter(date: _date, window: _window),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pine,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
                child: Text(l10n.findWhenApply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selected = ink fill with white text; unselected = mist.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.width,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        // No `alignment` here on purpose: a Container that aligns its child
        // expands to whatever it is offered, which inside the Wrap below
        // means every time-of-day option became a full-width bar.
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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

/// The chosen day as a field that opens a calendar -- the same shape as
/// [_TimeField], so the two read as one form.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.pine,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      value,
                      style: text.titleSmall!.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: AppColors.inkMid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              value,
              style: text.titleSmall!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
