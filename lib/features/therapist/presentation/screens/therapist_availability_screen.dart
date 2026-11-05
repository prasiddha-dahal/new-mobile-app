import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/working_hours.dart';
import '../../domain/usecases/availability_usecases.dart';
import '../providers/availability_providers.dart';

/// The weekly pattern patients book against.
///
/// ## What this screen is, and what it deliberately is not
///
/// It sets **one thing**: which days the therapist works, between what hours,
/// in what length of appointment. That is the whole of what
/// `POST /availability/generate` stores, and it is the only write that makes
/// a pattern real — `GET /availability/slots` synthesises its grid from the
/// stored hours and applies no day-of-week filter, so a day is only closed
/// once an `off` row has been written for it.
///
/// Its neighbours live elsewhere and are linked rather than duplicated:
///
/// * **One slot, on one day** — the tappable grid on `TherapistScheduleScreen`.
/// * **A day or a week off** — `DayOffScreen`, which goes through
///   `POST /availability/block-request` and an admin's approval. That is a
///   different kind of change with a different authority behind it, and
///   folding it in here would imply the therapist can grant themselves leave.
///
/// The prototype this replaces offered Morning / Afternoon / Evening chips.
/// Those are gone: the API stores a single contiguous span, so "mornings and
/// evenings but not afternoons" is not expressible, and a control that
/// accepted it and quietly published 09:00–20:00 would be the same bug in a
/// new place. Start and end pickers say exactly what gets stored.
class TherapistAvailabilityScreen extends ConsumerStatefulWidget {
  const TherapistAvailabilityScreen({super.key});

  @override
  ConsumerState<TherapistAvailabilityScreen> createState() =>
      _TherapistAvailabilityScreenState();
}

class _TherapistAvailabilityScreenState
    extends ConsumerState<TherapistAvailabilityScreen> {
  /// The session lengths offered. Values in minutes, sent verbatim.
  static const _sessionOptions = [30, 45, 60, 90];

  /// What the therapist has edited to, or null until the stored pattern has
  /// arrived. Never seeded with a default — an invented pattern shown as
  /// though it were saved is precisely the bug this screen replaces.
  WorkingHours? _draft;

  /// The pattern the server last confirmed, for the saved/unsaved pill.
  WorkingHours? _stored;

  bool _saving = false;

  /// Why the last save failed, kept on screen until the next attempt. The
  /// edits stay in [_draft] alongside it, so retrying costs nothing.
  Failure? _saveError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hours = ref.watch(workingHoursProvider);

    // Adopt what the server holds — on first arrival, and again whenever it
    // changes while there is nothing unsaved on screen. The dirty guard is
    // the important half: a refresh landing mid-edit must not silently
    // replace what the therapist has just tapped.
    ref.listen<AsyncValue<WorkingHours>>(workingHoursProvider, (_, next) {
      final loaded = next.valueOrNull;
      if (loaded == null || loaded == _stored) return;
      if (_draft != null && _draft != _stored) return;
      setState(() {
        _stored = loaded;
        _draft = loaded;
      });
    });
    // `ref.listen` only fires on a *change*, so a provider that already held
    // a value when this screen mounted would never seed the draft.
    final loadedNow = hours.valueOrNull;
    if (loadedNow != null && _draft == null) {
      _stored = loadedNow;
      _draft = loadedNow;
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            PageHeader(
              title: l10n.availabilityTitle,
              onBack: () => context.pop(),
            ),
            Expanded(
              // Once there is a draft the editor stays put. Invalidating the
              // provider after a save puts it back into `AsyncLoading` for a
              // moment, and a spinner over the whole screen at exactly the
              // instant the therapist is reading their confirmation would be
              // the worst possible time for one.
              child: _draft != null
                  ? _editor(context, l10n)
                  : switch (hours) {
                      AsyncError(:final error) => ErrorStateView(
                        failure: error is Failure
                            ? error
                            : const UnknownFailure(),
                        onRetry: () => ref.invalidate(workingHoursProvider),
                      ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor(BuildContext context, AppLocalizations l10n) {
    final draft = _draft;
    if (draft == null) return const SizedBox.shrink();

    final booked = ref.watch(bookedSlotsInHorizonProvider);
    final problem = draft.problem;
    final dirty = draft != _stored;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            // A Column, not a Row with the pill in the trailing slot. A Row
            // gives a non-flex child unbounded width on the main axis, so the
            // pill never wrapped and simply ran off the page — measured at
            // 159px over on a 320dp phone at 1.6x in Nepali, where "अझै
            // सुरक्षित गरिएको छैन" is far wider than the space beside a
            // sentence. Stacked, the pill inherits the column's width and its
            // label wraps like any other text.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SaveStatePill(dirty: dirty),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.availabilityIntro,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.inkMid,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(title: l10n.availabilityWorkingDays),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final day in Weekday.values)
                  _ChoiceChip(
                    label: _dayLabel(day, l10n),
                    selected: draft.days.contains(day),
                    // Reads `_draft` when tapped rather than closing over the
                    // `draft` this frame was built from. Two taps landing
                    // inside one frame would otherwise both start from the
                    // stale value and the first would be lost.
                    onTap: _saving
                        ? null
                        : () => _editFrom(
                            (current) => current.withDay(
                              day,
                              !current.days.contains(day),
                            ),
                          ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(title: l10n.availabilityHoursHeading),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A Wrap, not a Row: at 1.6x text in Nepali the two
                  // labelled buttons do not fit side by side on a 320dp
                  // phone, and a Row would overflow rather than stack.
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      _TimeField(
                        label: l10n.availabilityStartLabel,
                        value: formatSlotTime(draft.startLabel, l10n),
                        onTap: _saving
                            ? null
                            : () => _pickTime(isStart: true, hours: draft),
                      ),
                      _TimeField(
                        label: l10n.availabilityEndLabel,
                        value: formatSlotTime(draft.endLabel, l10n),
                        onTap: _saving
                            ? null
                            : () => _pickTime(isStart: false, hours: draft),
                      ),
                    ],
                  ),
                  if (problem == null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.availabilitySlotsPerDay(draft.slotsPerDay),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(title: l10n.availabilitySessionHeading),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final minutes in _sessionOptions)
                  _ChoiceChip(
                    label: l10n.availabilitySessionMinutes(minutes),
                    selected: draft.sessionMinutes == minutes,
                    onTap: _saving
                        ? null
                        : () => _editFrom(
                            (current) =>
                                current.copyWith(sessionMinutes: minutes),
                          ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (problem != null) ...[
                  _Notice(
                    tone: _NoticeTone.warning,
                    text: _problemText(problem, l10n),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_saveError != null) ...[
                  _Notice(
                    tone: _NoticeTone.error,
                    text: l10n.availabilitySaveFailed,
                    detail: _failureDetail(_saveError!, l10n),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  l10n.availabilityHorizonNote(availabilityWriteHorizonDays),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.inkMute,
                  ),
                ),
                if (booked != null && booked > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.availabilityBookedKept(booked),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.inkMute,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _saving || problem != null || !dirty
                      ? null
                      : _save,
                  child: Text(
                    _saving ? l10n.availabilitySaving : l10n.availabilitySave,
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          l10n.availabilitySavingNote,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => context.push('/therapist/day-off'),
                  child: Text(l10n.availabilityDayOffLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  /// Applies [change] to the pattern as it stands *now* and clears the
  /// previous failure — the banner describes the attempt that failed, not the
  /// pattern now on screen.
  ///
  /// Takes a function rather than a finished value so the caller cannot hand
  /// it one derived from a frame that has since been rebuilt.
  void _editFrom(WorkingHours Function(WorkingHours current) change) {
    final current = _draft;
    if (current == null) return;
    setState(() {
      _draft = change(current);
      _saveError = null;
    });
  }

  Future<void> _pickTime({
    required bool isStart,
    required WorkingHours hours,
  }) async {
    final current = isStart ? hours.startMinutes : hours.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    final minutes = picked.hour * 60 + picked.minute;
    _editFrom(
      (current) => isStart
          ? current.copyWith(startMinutes: minutes)
          : current.copyWith(endMinutes: minutes),
    );
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final result = await ref
        .read(availabilityActionsProvider)
        .saveWorkingHours(draft);

    if (!mounted) return;
    final l10n = context.l10n;

    result.match(
      (failure) {
        // The draft is untouched: the therapist's edits survive the failure
        // and the button becomes live again the moment the banner is read.
        setState(() {
          _saving = false;
          _saveError = failure;
        });
        _toast(l10n.availabilitySaveFailed, isError: true);
      },
      (saved) {
        // `_stored` is set from the pattern that was sent rather than from a
        // re-read, and the provider is invalidated behind this, so the pill
        // flips to "Saved" only after the server said so.
        setState(() {
          _saving = false;
          _stored = draft;
        });
        _toast(l10n.availabilitySaveSuccess(saved.openedSlots));
      },
    );
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
          duration: Duration(seconds: isError ? 6 : 4),
        ),
      );
  }

  /// The second line of the error banner.
  ///
  /// A refusal the use case made locally has a translated sentence already,
  /// so it is used. Anything from the server arrives in English — see
  /// docs/localization.md — and is shown as it came rather than replaced by a
  /// vaguer sentence this app made up.
  String _failureDetail(Failure failure, AppLocalizations l10n) {
    if (failure is InvalidWorkingHoursFailure) {
      final problem = failure.problem;
      if (problem != null) return _problemText(problem, l10n);
    }
    return failure.message;
  }

  String _problemText(WorkingHoursProblem problem, AppLocalizations l10n) =>
      switch (problem) {
        WorkingHoursProblem.noDays => l10n.availabilityProblemNoDays,
        WorkingHoursProblem.endNotAfterStart =>
          l10n.availabilityProblemEndBeforeStart,
        WorkingHoursProblem.sessionLongerThanDay =>
          l10n.availabilityProblemSessionTooLong,
      };

  String _dayLabel(Weekday day, AppLocalizations l10n) => switch (day) {
    Weekday.sunday => l10n.dayShortSun,
    Weekday.monday => l10n.dayShortMon,
    Weekday.tuesday => l10n.dayShortTue,
    Weekday.wednesday => l10n.dayShortWed,
    Weekday.thursday => l10n.dayShortThu,
    Weekday.friday => l10n.dayShortFri,
    Weekday.saturday => l10n.dayShortSat,
  };
}

/// A tappable chip. The prototype's were bare [Container]s with no gesture
/// handler at all — they looked selectable and were not.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.pine : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: selected ? AppColors.pine : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.card : AppColors.inkMid,
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled button that opens a clock picker.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMute),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved / not-saved, beside the intro line.
///
/// Both states are stated plainly. "Not saved yet" is not an error — it is
/// the answer to the only question this screen has ever been asked, which is
/// whether what is on it is what patients will see.
class _SaveStatePill extends StatelessWidget {
  const _SaveStatePill({required this.dirty});

  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // Amber, not grey: on cream a grey pill reads as disabled chrome
        // rather than as a state worth acting on.
        color: dirty ? AppColors.amberPale : AppColors.pinePale,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        dirty ? l10n.availabilityStatusUnsaved : l10n.availabilityStatusSaved,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dirty ? AppColors.amberBrand : AppColors.pine,
        ),
      ),
    );
  }
}

enum _NoticeTone { warning, error }

class _Notice extends StatelessWidget {
  const _Notice({required this.tone, required this.text, this.detail});

  final _NoticeTone tone;
  final String text;

  /// The server's own words, when there are any. Arrives in English — see
  /// docs/localization.md.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (tone) {
      _NoticeTone.warning => (AppColors.amberPale, AppColors.ink),
      _NoticeTone.error => (AppColors.dangerPale, AppColors.danger),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.inkMid,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
