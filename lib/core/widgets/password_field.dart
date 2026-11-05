import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// A password input with an eye button that shows and hides what was typed.
///
/// Typing a password blind on a phone keyboard is where most failed logins
/// and mismatched "confirm password" fields come from; letting the person
/// look before they send it is cheaper than a refusal and a retype. Starts
/// hidden every time it is built, and stays one line with no autocorrect or
/// suggestions while shown.
///
/// Takes the screen's own [decoration] and only adds the button to it, so it
/// keeps whatever label or hint style the form uses.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      maxLines: 1,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          tooltip: _hidden ? l10n.passwordShow : l10n.passwordHide,
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.inkMid,
          ),
        ),
      ),
    );
  }
}
