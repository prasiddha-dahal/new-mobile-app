import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set by a "rate your visit" notification tap so the Sessions tab opens on
/// Past, where the review button is -- not on Upcoming, which is where that
/// tab opens by default and which would be empty or show something unrelated.
/// The Sessions screen reads it once and clears it.
///
/// Lives in core because the notifications feature sets it and the patient
/// feature reads it, and neither should import the other.
final openPastSessionsProvider = StateProvider<bool>((_) => false);
