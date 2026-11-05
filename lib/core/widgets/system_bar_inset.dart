import 'package:flutter/widgets.dart';

/// Lifts a pinned bottom bar clear of the system navigation.
///
/// On a phone with on-screen back/home/recents buttons the window runs
/// underneath them, so a button pinned to the bottom of a screen is drawn under
/// the system bar -- the "Confirm & pay" button was half hidden by it.
///
/// Neither `SafeArea` nor `viewPadding` can fix it from inside the bar.
/// `Scaffold` strips the bottom padding from its `bottomSheet` slot -- both
/// `padding` and `viewPadding`, since `removePadding` takes the same amount
/// off each -- so by the time the bar builds, the system bar has already been
/// subtracted and both read zero.
///
/// So the inset is read where it still exists: from the screen's own context,
/// above the Scaffold, with [SystemBarInset.of], and handed down.
///
/// Only for a screen outside the tab shell. Inside it the shell's own bottom
/// bar already clears the system navigation, and the screen's context reads
/// zero, so this adds nothing there.
///
/// A `bottomNavigationBar` does not need it: that slot keeps the bottom
/// padding, and a `SafeArea` in it works.
class SystemBarInset extends StatelessWidget {
  const SystemBarInset({super.key, required this.inset, required this.child});

  /// The system navigation's height. Read it with [of], from the screen's
  /// `build` context -- not from inside the bar.
  final double inset;
  final Widget child;

  /// What the system navigation occupies, read from [screenContext].
  ///
  /// [screenContext] must be above the `Scaffold`. Called from inside its
  /// `bottomSheet` this returns zero, which is the bug this class exists for.
  static double of(BuildContext screenContext) =>
      MediaQuery.paddingOf(screenContext).bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(bottom: inset), child: child);
  }
}
