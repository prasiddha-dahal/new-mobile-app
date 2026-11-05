import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import '../validation/validators.dart';

/// Form controls that participate in validation.
///
/// The app already has [LabeledField] for plain text. What was missing is
/// everything that is *not* a text box: a date the user picks rather than
/// types, and a choice from a fixed list. Both were previously bare
/// `TextField`s whose contents nothing checked and, in the case of the signup
/// screen, nothing even read.
///
/// Both widgets below are [FormField]s, so a single `_formKey.currentState!
/// .validate()` covers them alongside every text field on the same form.

/// A mono uppercase label, matching the one the auth forms use.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      color: AppColors.ink,
    ),
  );
}

/// Shared shell so a picker sits at the same height and radius as a text
/// input, and shows its error in the same place.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.child,
    required this.hasError,
    this.errorText,
    this.onTap,
  });

  final String label;
  final Widget child;
  final bool hasError;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            isEmpty: false,
            decoration: InputDecoration(
              // Null rather than empty: an empty string still reserves the
              // error row, leaving a gap under every valid field.
              errorText: hasError ? errorText : null,
              errorMaxLines: 4,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// A date the user picks from a calendar.
///
/// Replaces the free-text `DD / MM / YYYY` boxes: typed dates arrive in every
/// format a person can imagine, and none of them parse reliably.
class AppDateField extends FormField<DateTime> {
  AppDateField({
    super.key,
    required String label,
    required String hint,
    super.initialValue,
    ValueChanged<DateTime?>? onChanged,
    DateTime? firstDate,
    DateTime? lastDate,
    super.validator,
    AutovalidateMode super.autovalidateMode =
        AutovalidateMode.onUserInteraction,
  }) : super(
         builder: (state) {
           final value = state.value;
           return _FieldShell(
             label: label,
             hasError: state.hasError,
             errorText: state.errorText,
             onTap: () async {
               final now = DateTime.now();
               final picked = await showDatePicker(
                 context: state.context,
                 initialDate: value ?? _sensibleStart(firstDate, lastDate, now),
                 firstDate: firstDate ?? DateTime(now.year - 120),
                 lastDate: lastDate ?? DateTime(now.year + 5),
                 builder: (context, child) {
                   final theme = Theme.of(context);
                   final pickerTextTheme = theme.textTheme
                       .apply(fontFamily: AppTypography.fontSans)
                       .copyWith(
                         labelLarge: theme.textTheme.labelLarge?.copyWith(
                           fontFamily: AppTypography.fontSans,
                            fontSize: 14,
                           letterSpacing: 0,
                         ),
                       );
                   return Theme(
                     data: theme.copyWith(
                       textTheme: pickerTextTheme,
                       datePickerTheme: theme.datePickerTheme.copyWith(
                         headerHelpStyle:
                             (theme.datePickerTheme.headerHelpStyle ??
                                     pickerTextTheme.labelMedium)
                                 ?.copyWith(letterSpacing: 0, fontSize: 14),
                         cancelButtonStyle: TextButton.styleFrom(
                           textStyle: pickerTextTheme.labelLarge?.copyWith(
                             letterSpacing: 0,
                           ),
                         ),
                         confirmButtonStyle: TextButton.styleFrom(
                           textStyle: pickerTextTheme.labelLarge?.copyWith(
                             letterSpacing: 0,
                           ),
                         ),
                       ),
                     ),
                     child: child!,
                   );
                 },
               );
               if (picked != null) {
                 state.didChange(picked);
                 onChanged?.call(picked);
               }
             },
             child: Row(
               children: [
                 Expanded(
                   child: Text(
                     value == null
                         ? hint
                         : formatFullDate(value, state.context.l10n),
                     style: TextStyle(
                       fontSize: 14,
                       color: value == null ? AppColors.inkMute : AppColors.ink,
                     ),
                   ),
                 ),
                 const Icon(
                   Icons.calendar_today_outlined,
                   size: 16,
                   color: AppColors.inkMute,
                 ),
               ],
             ),
           );
         },
       );

  /// Opening the calendar on a date outside the allowed range throws, so the
  /// starting point is clamped into it.
  static DateTime _sensibleStart(
    DateTime? first,
    DateTime? last,
    DateTime now,
  ) {
    if (last != null && now.isAfter(last)) return last;
    if (first != null && now.isBefore(first)) return first;
    return now;
  }

}

/// A choice from a fixed list, shown in a bottom sheet.
///
/// Used for gender, which was a free-text box hinted "Female / Male / Other" —
/// so the value reaching the API was whatever the person typed, in whatever
/// case, including nothing at all.
///
/// [options] are *values*, not labels: the form's value, the initial value and
/// what reaches the API are all the same string. Pass [display] to show
/// something else — which is how a localised label sits on top of a value the
/// server defines. Translating the values themselves would send Nepali to an
/// API that stores English.
class AppChoiceField extends FormField<String> {
  AppChoiceField({
    super.key,
    required String label,
    required String hint,
    required List<String> options,
    super.initialValue,
    ValueChanged<String?>? onChanged,
    String Function(String)? display,
    super.validator,
    AutovalidateMode super.autovalidateMode =
        AutovalidateMode.onUserInteraction,
  }) : super(
         builder: (state) {
           final value = state.value;
           return _FieldShell(
             label: label,
             hasError: state.hasError,
             errorText: state.errorText,
             onTap: () async {
               final picked = await showModalBottomSheet<String>(
                 context: state.context,
                 backgroundColor: AppColors.card,
                 shape: const RoundedRectangleBorder(
                   borderRadius: BorderRadius.vertical(
                     top: Radius.circular(20),
                   ),
                 ),
                 // The list has to scroll. Every caller until now passed a
                 // handful of fixed options and the sheet fitted; the
                 // complaint form picks from the live therapist directory,
                 // which is as long as the directory is, and an unscrollable
                 // Column drew a yellow overflow bar over the last entries --
                 // the therapist a patient wanted to report could be one of
                 // the ones behind it.
                 //
                 // Capped at 70% of the screen so the sheet still reads as a
                 // sheet, and shrink-wrapped below that so a three-option
                 // picker does not suddenly become full height.
                 isScrollControlled: true,
                 builder: (sheetContext) => SafeArea(
                   child: ConstrainedBox(
                     constraints: BoxConstraints(
                       maxHeight:
                           MediaQuery.sizeOf(sheetContext).height * 0.7,
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const SizedBox(height: 8),
                         Container(
                           width: 40,
                           height: 4,
                           decoration: BoxDecoration(
                             color: AppColors.mist,
                             borderRadius: BorderRadius.circular(999),
                           ),
                         ),
                         const SizedBox(height: 12),
                         Flexible(
                           child: ListView.builder(
                             shrinkWrap: true,
                             padding: EdgeInsets.zero,
                             itemCount: options.length,
                             itemBuilder: (_, i) {
                               final option = options[i];
                               return ListTile(
                                 title: Text(display?.call(option) ?? option),
                                 trailing: option == value
                                     ? const Icon(
                                         Icons.check_rounded,
                                         size: 18,
                                         color: AppColors.pine,
                                       )
                                     : null,
                                 onTap: () =>
                                     Navigator.of(sheetContext).pop(option),
                               );
                             },
                           ),
                         ),
                         const SizedBox(height: 8),
                       ],
                     ),
                   ),
                 ),
               );
               if (picked != null) {
                 state.didChange(picked);
                 onChanged?.call(picked);
               }
             },
             child: Row(
               children: [
                 Expanded(
                   child: Text(
                     value == null ? hint : (display?.call(value) ?? value),
                     style: TextStyle(
                       fontSize: 14,
                       color: value == null ? AppColors.inkMute : AppColors.ink,
                     ),
                   ),
                 ),
                 const Icon(
                   Icons.expand_more_rounded,
                   size: 18,
                   color: AppColors.inkMute,
                 ),
               ],
             ),
           );
         },
       );
}

/// The gender picker, so the same options and wording appear everywhere it is
/// asked for rather than being re-listed per screen.
class GenderField extends StatelessWidget {
  const GenderField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.isRequired = true,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Overrides the default all-caps "GENDER". Already localised by the caller.
  final String? label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppChoiceField(
      label: label ?? l10n.fieldGenderLabel,
      hint: l10n.fieldSelectHint,
      options: Gender.labels,
      initialValue: Gender.fromLabel(value)?.label,
      onChanged: onChanged,
      display: (option) => Gender.fromLabel(option)?.labelIn(l10n) ?? option,
      validator: isRequired
          ? Validators.selection(l10n, l10n.fieldGender)
          : null,
    );
  }
}
