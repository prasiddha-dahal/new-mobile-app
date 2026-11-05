/// "14:30" -> "2:30 PM", "09:05" -> "9:05 AM".
///
/// A value that already ends in AM/PM, or that isn't HH:mm, is returned
/// unchanged, so it is safe to call on anything the API sends.
String formatTime12h(String raw) {
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