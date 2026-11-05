import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Small uppercase mono field label used throughout the auth forms.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontSize: 10,
        letterSpacing: 1.8,
        color: AppColors.inkMute,
      ),
    );
  }
}

/// A mono uppercase label sitting above a pill input.
///
/// The prototype never uses a floating Material label — the label is always
/// outside the field and the inside text is the placeholder.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.inputFormatters,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          validator: validator,
          textCapitalization: textCapitalization,
          onFieldSubmitted: onSubmitted,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }
}

/// Pill chips, single- or multi-select.
///
/// [options] are *values*, not labels. Several of these lists are sent to the
/// API verbatim — a therapist's specialism and service city among them — so
/// translating the option itself would put Devanagari in a column that holds
/// English. Pass [display] to localise what the chip shows while the value
/// it carries stays as the server defines it.
class ChipSelector extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.options,
    this.selected,
    this.selectedValues,
    this.onSelected,
    this.multiSelect = false,
    this.display,
  });

  final List<String> options;
  final String? selected;
  final List<String>? selectedValues;
  final void Function(String)? onSelected;
  final bool multiSelect;

  /// Maps a value to the label shown on its chip. Identity when omitted.
  final String Function(String)? display;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isActive = multiSelect
            ? (selectedValues?.contains(opt) ?? false)
            : selected == opt;
        return GestureDetector(
          onTap: () => onSelected?.call(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.pine : AppColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive ? AppColors.pine : AppColors.border,
              ),
            ),
            child: Text(
              display?.call(opt) ?? opt,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.card : AppColors.inkMid,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Inline error message used by the auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
