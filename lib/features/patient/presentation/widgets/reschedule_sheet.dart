import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/slot_pickers.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/therapist.dart';
import '../providers/patient_providers.dart';

/// A new date/time chosen in the reschedule sheet.
class RescheduleChoice {
  const RescheduleChoice({required this.date, required this.time});

  /// `YYYY-MM-DD`.
  final String date;

  /// `HH:MM`.
  final String time;
}

/// Bottom sheet for picking a new slot.
///
/// Slots come from the therapist's real calendar, so the sheet cannot offer a
/// time the backend would reject.
Future<RescheduleChoice?> showRescheduleSheet(
  BuildContext context, {
  required Session session,
}) {
  return showModalBottomSheet<RescheduleChoice>(
    context: context,
    isScrollControlled: true,
    // Push onto the root navigator: the shell's bottom nav would
    // otherwise paint over a sheet opened on the shell's own navigator.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _RescheduleSheet(session: session),
  );
}

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.session});
  final Session session;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  String? _date;
  String? _time;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final slotsAsync = ref.watch(
      therapistSlotsProvider(widget.session.therapistId),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              context.l10n.reschedulePickSlot,
              style: text.titleLarge!.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.rescheduleCurrently(
                formatShortDate(widget.session.date, context.l10n),
                formatTime12h(widget.session.time),
              ),
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                letterSpacing: 0,
                color: AppColors.inkMid,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: slotsAsync.when(
                loading: () => const SkeletonList(
                  count: 3,
                  itemHeight: 44,
                  gap: AppSpacing.sm,
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  compact: true,
                  onRetry: () => ref.invalidate(
                    therapistSlotsProvider(widget.session.therapistId),
                  ),
                ),
                data: (slots) => _buildSlots(slots),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_date != null && _time != null)
                    ? () => Navigator.pop(
                        context,
                        RescheduleChoice(date: _date!, time: _time!),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pine,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.pine.withAlpha(90),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  // Buttons default to labelLarge (mono, spaced).
                  textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
                child: Text(context.l10n.rescheduleConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlots(List<TherapistSlot> slots) {
    final open = slots
        .where(
          (s) =>
              s.isOpen &&
              !(s.date == widget.session.dateKey &&
                  s.time == widget.session.time),
        )
        .toList();

    if (open.isEmpty) {
      return EmptyStateView(
        title: context.l10n.rescheduleNoOtherSlots,
        description: context.l10n.rescheduleNoOtherSlotsDesc,
        icon: Icons.event_busy_outlined,
      );
    }

    final openTimes = <String, List<String>>{};
    for (final slot in open) {
      openTimes.putIfAbsent(slot.date, () => []).add(slot.time);
    }
    final date = _date ?? (openTimes.keys.toList()..sort()).first;

    // The same two fields as booking: a calendar of days that have a free time,
    // then that day's times. The old list of every day with every time under
    // it ran to a fortnight of chips.
    return SingleChildScrollView(
      child: SlotPickerFields(
        openTimes: openTimes,
        date: date,
        time: _date == null || _date == date ? _time : null,
        onDate: (d) => setState(() {
          _date = d;
          _time = null;
        }),
        onTime: (t) => setState(() {
          _date = date;
          _time = t;
        }),
      ),
    );
  }
}