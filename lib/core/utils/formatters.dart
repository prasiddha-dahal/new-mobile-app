/// Formatting for anything a reader sees as text rather than as data.
///
/// Every function here takes the caller's [AppLocalizations]. That one
/// argument carries two things at once: the words ("Today", "3 days ago") and,
/// through [AppLocalizations.localeName], the locale `intl` needs for month
/// names, weekday names and digits. Passing it is not optional, because the
/// failure mode of a locale-blind formatter is silent — a fully Nepali screen
/// with `Sat, 7 Mar` and `Rs 1,500` sitting in the middle of it.
///
/// Use [englishL10n] where there is genuinely no context: a pure test, a log
/// line, a value being sent to the API rather than shown.
library;

import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../l10n/l10n.dart';

/// The locale `intl` should format **numbers** in.
///
/// English keeps `AppConstants.locale` (`en-IN`) rather than plain `en`,
/// because that is what these screens were laid out against and what the web
/// uses; this pass is not the place to change how English renders. Nepali
/// formats as itself, so amounts print Devanagari digits — `Rs १,०००`, which
/// is exactly how the existing reviewed Nepali writes them.
///
/// `NumberFormat` carries its symbol data for every locale in the binary, so
/// unlike dates this never needs initialising and never throws.
String _numberLocale(AppLocalizations l10n) =>
    l10n.localeName == 'en' ? AppConstants.locale : l10n.localeName;

/// The locale `intl` should format **dates** in, or null for its default.
///
/// Two things force the null:
///
/// * `DateFormat` throws `LocaleDataException` for *any* explicitly named
///   locale whose symbols have not been loaded — including `en`, and including
///   `en-IN`, which nothing loads at all. `GlobalMaterialLocalizations` loads
///   the symbols for the locale the app is actually running in, so `ne` is
///   available in the app but not in a widget pumped without the delegates.
/// * English must keep rendering exactly as it did before this pass, and what
///   it did before was pass no locale at all.
///
/// So: English asks for nothing, every other locale is used only once `intl`
/// confirms it has the data. A locale it cannot serve falls back to the
/// default rather than throwing — the same way `context.l10n` degrades to
/// English rather than crashing a widget its caller pumped bare.
String? _dateLocale(AppLocalizations l10n) {
  final name = l10n.localeName;
  if (name == 'en') return null;
  try {
    if (DateFormat.localeExists(name)) return name;
  } on Exception {
    // No symbol data loaded at all. Fall through to the default.
  }
  return null;
}

/// Formats an amount in Nepali Rupees.
///
/// The `Rs` symbol stays Latin in both languages. That is not an oversight:
/// the existing reviewed Nepali writes amounts as `Rs १,०००`, and the web app
/// does the same, so changing it here would make the two clients disagree.
/// Grouping is **South Asian**, not thousands: `Rs 4,86,000`, never
/// `Rs 486,000`. Both locales this app runs in already carry that rule —
/// `en_IN` and `ne` both declare `#,##,##0.###` in `intl`'s own symbol data —
/// and `NumberFormat.decimalPattern` is what reads it. Passing an explicit
/// `'#,##0'` was overriding the locale with a Western pattern, so every figure
/// above 99,999 printed wrongly in both languages; below that the two rules
/// agree, which is why it went unnoticed. The lakh figures are the therapist's
/// `Lifetime` earnings and the patient's points balance.
String formatCurrency(double amount, AppLocalizations l10n) {
  final formatter = NumberFormat.decimalPattern(_numberLocale(l10n))
    ..maximumFractionDigits = 0;
  return '${AppConstants.currencySymbol}${formatter.format(amount)}';
}

/// Formats a DateTime to "EEE, d MMM · HH:mm".
///
/// [time] arrives from the API as a 24-hour clock string and is passed
/// through: it is data, and `14:30` reads the same in both languages.
String formatDateTime(DateTime date, String time, AppLocalizations l10n) {
  final dateStr = formatShortDate(date, l10n);
  return '$dateStr · $time';
}

/// Formats a DateTime as "Tue, 7 Jul" — "मङ्गल, ७ जुलाई" in Nepali.
String formatShortDate(DateTime date, AppLocalizations l10n) =>
    DateFormat(AppConstants.dateFormat, _dateLocale(l10n)).format(date);

/// Formats a weekday on its own as "Thu" — "बिहि" in Nepali.
String formatWeekday(DateTime date, AppLocalizations l10n) =>
    DateFormat('EEE', _dateLocale(l10n)).format(date);

/// Formats a DateTime as "7 Jul" — no year, no weekday.
String formatDayAndMonth(DateTime date, AppLocalizations l10n) =>
    DateFormat('d MMM', _dateLocale(l10n)).format(date);

/// Formats a slot's `HH:MM` as a reader says it out loud — `9:00 AM`.
///
/// The API's times are 24-hour wall-clock strings and several screens show
/// them exactly as they arrive, which is right inside a grid of times where
/// the column *is* the context. In a sentence — "Free tomorrow 9:00 AM" — a
/// bare `09:00` reads as machine output, so it is spelled out here instead.
///
/// A string that is not `HH:MM` is passed straight through rather than
/// throwing: it came off the wire, and a card is not the place to discover
/// that the API sent something new.
String formatSlotTime(String time, AppLocalizations l10n) {
  final parts = time.split(':');
  if (parts.length < 2) return time;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return time;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return time;
  return DateFormat(
    'h:mm a',
    _dateLocale(l10n),
  ).format(DateTime(2000, 1, 1, hour, minute));
}

/// Formats a DateTime as "7 Jul 2026" — "७ जुलाई २०२६" in Nepali.
///
/// For a date the reader picked rather than one we are reminding them of, so
/// the year is always shown: a date of birth or a day off a year out must not
/// read as though it were this year.
String formatFullDate(DateTime date, AppLocalizations l10n) =>
    DateFormat('d MMM y', _dateLocale(l10n)).format(date);

/// Same as [formatFullDate] for an ISO date or timestamp received from an API.
///
/// Invalid or absent values are returned unchanged so callers can keep their
/// existing empty-value handling without risking a parse exception.
String? formatFullDateFromString(String? isoDate, AppLocalizations l10n) {
  if (isoDate == null || isoDate.trim().isEmpty) return isoDate;
  final parsed = DateTime.tryParse(isoDate);
  return parsed == null ? isoDate : formatFullDate(parsed, l10n);
}

/// "Today", "Tomorrow", "Yesterday", or "Tue, 7 Jul".
///
/// Used wherever a date is shown to the patient — a bare `2026-08-21` reads as
/// machine output next to the rest of the copy.
String formatDayLabel(DateTime date, AppLocalizations l10n) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;

  return switch (diff) {
    0 => l10n.dateToday,
    1 => l10n.dateTomorrow,
    -1 => l10n.dateYesterday,
    _ => formatShortDate(date, l10n),
  };
}

/// Same as [formatDayLabel] but tolerant of a `YYYY-MM-DD` string, which is how
/// some endpoints return dates.
String formatDayLabelFromString(String isoDate, AppLocalizations l10n) {
  final parsed = DateTime.tryParse(isoDate);
  return parsed == null ? isoDate : formatDayLabel(parsed, l10n);
}

/// A past timestamp as a reader would say it out loud.
///
/// Rules, in order — the first that matches wins:
///
/// | elapsed = now − [date]                  | reads          |
/// |-----------------------------------------|----------------|
/// | under a minute, **including negative**  | `Just now`     |
/// | under an hour                           | `12m ago`      |
/// | under 24 hours                          | `3h ago`       |
/// | the calendar day before today           | `Yesterday`    |
/// | 2–6 calendar days ago                   | `4 days ago`   |
/// | older                                   | `7 Mar`, or `7 Mar 2025` in another year |
///
/// Three things the obvious version gets wrong:
///
/// * **A future [date] is clock skew, not a scheduled event.** The device's
///   clock trailing the server's by a few seconds used to print `-1m ago`,
///   and a phone whose clock is a day out printed `in -3 hours`-shaped
///   nonsense. Anything not yet in the past reads `Just now`.
/// * **"Yesterday" is a calendar word, not a 24-hour window.** It is decided
///   on local calendar days, so 25 hours ago reads `Yesterday` rather than
///   `25h ago`.
/// * **…but the hours rule is checked first**, so something posted at 23:50
///   and read at 00:10 says `20m ago`. It happened twenty minutes ago; the
///   date rolling over in between does not make it yesterday's news.
///
/// Past a week, counting days stops helping and an exact date starts: the
/// year is printed only when it is not the current one, so `7 Mar` cannot
/// silently mean three different years.
///
/// The counted forms go through ARB placeholders rather than string
/// concatenation. `'$days days ago'` is only correct because English happens
/// to put the number first and the unit second; Nepali puts the unit before
/// the postposition, and a splice would have produced word salad.
///
/// [now] exists so the boundaries can be tested without waiting for them.
String formatRelativeTime(
  DateTime date,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  // Calendar arithmetic below has to happen in the reader's timezone, and the
  // API hands back UTC instants.
  final local = date.toLocal();
  final elapsed = current.difference(local);

  if (elapsed.inMinutes < 1) return l10n.timeJustNow;
  if (elapsed.inMinutes < 60) return l10n.timeMinutesAgo(elapsed.inMinutes);
  if (elapsed.inHours < 24) return l10n.timeHoursAgo(elapsed.inHours);

  final today = DateTime(current.year, current.month, current.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  final days = today.difference(thatDay).inDays;

  if (days <= 1) return l10n.dateYesterday;
  if (days < 7) return l10n.timeDaysAgo(days);

  final locale = _dateLocale(l10n);
  return local.year == current.year
      ? DateFormat('d MMM', locale).format(local)
      : DateFormat('d MMM yyyy', locale).format(local);
}

/// Extracts initials from a name.
///
/// No [AppLocalizations]: initials come from the name the user gave us, which
/// is not translated, and `Dr.` is stripped because it is a title rather than
/// part of the name.
String getInitials(String name) {
  return name
      .replaceAll(RegExp(r'^(Dr\.?)\s*', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0])
      .take(2)
      .join()
      .toUpperCase();
}

/// "5", "7.5", "12.25": a percentage without a trailing ".0".
String formatPercent(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// "14:30" -> "2:30 PM", "09:05" -> "9:05 AM".
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

String key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

int hour24(String raw) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([ap])?',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) return 0;
  var h = int.parse(m.group(1)!);
  final ap = m.group(3)?.toLowerCase();
  if (ap == 'p' && h < 12) h += 12;
  if (ap == 'a' && h == 12) h = 0;
  return h;
}

String time12(String raw) {
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
