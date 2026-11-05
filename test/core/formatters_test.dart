import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/utils/formatters.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_ne.dart';

/// `formatRelativeTime` is what every notification row, every report card and
/// the therapist's patient list use to say when something happened, and its
/// rules are all boundaries: one second either side of each of them changes
/// the sentence. These pin every boundary at both ends, with an explicit
/// `now` so the test does not have to wait for midnight to check "Yesterday".
void main() {
  /// Reference "now": mid-afternoon, mid-month, so no rule can pass by
  /// accidentally landing on a month or year edge.
  final now = DateTime(2026, 9, 11, 15, 30);

  String at(Duration ago) =>
      formatRelativeTime(now.subtract(ago), englishL10n, now: now);

  group('under a minute', () {
    test('reads "Just now" right up to the minute mark', () {
      expect(at(Duration.zero), 'Just now');
      expect(at(const Duration(seconds: 1)), 'Just now');
      expect(at(const Duration(seconds: 59)), 'Just now');
    });

    test('and tips into minutes at exactly one', () {
      expect(at(const Duration(seconds: 60)), '1m ago');
    });
  });

  group('a future timestamp is clock skew, not a scheduled event', () {
    // The device's clock trailing the server's by a few seconds is ordinary,
    // and the old rule printed "-1m ago" for it. A phone whose clock is a day
    // out printed something worse.
    test('a few seconds ahead reads "Just now"', () {
      expect(at(const Duration(seconds: -5)), 'Just now');
    });

    test('and so does a wildly wrong clock', () {
      expect(at(const Duration(hours: -3)), 'Just now');
      expect(at(const Duration(days: -400)), 'Just now');
    });

    test('no output ever contains a minus sign', () {
      for (final skew in [
        const Duration(seconds: -1),
        const Duration(minutes: -59),
        const Duration(hours: -25),
        const Duration(days: -9),
      ]) {
        expect(at(skew), isNot(contains('-')), reason: 'skew of $skew');
      }
    });
  });

  group('minutes and hours', () {
    test('minutes up to the hour', () {
      expect(at(const Duration(minutes: 1)), '1m ago');
      expect(at(const Duration(minutes: 59)), '59m ago');
    });

    test('hours from exactly one hour', () {
      expect(at(const Duration(minutes: 60)), '1h ago');
      expect(at(const Duration(hours: 23, minutes: 59)), '23h ago');
    });
  });

  group('Yesterday', () {
    test('25 hours ago is Yesterday, not "25h ago"', () {
      expect(at(const Duration(hours: 25)), 'Yesterday');
    });

    test('so is any hour of yesterday more than a day back', () {
      expect(
        formatRelativeTime(DateTime(2026, 9, 10, 0, 5), englishL10n, now: now),
        'Yesterday',
      );
      expect(
        formatRelativeTime(DateTime(2026, 9, 10, 14, 0), englishL10n, now: now),
        'Yesterday',
      );
    });

    test('late yesterday evening still counts in hours', () {
      // 23:59 yesterday is 15½ hours before 15:30 today, and the hours rule
      // is checked first on purpose. "15h ago" is more use than "Yesterday",
      // and it is what keeps the 20-minutes-ago case below honest.
      expect(
        formatRelativeTime(
          DateTime(2026, 9, 10, 23, 59),
          englishL10n,
          now: now,
        ),
        '15h ago',
      );
    });

    test(
      'but twenty minutes ago is not, however recently the date rolled over',
      () {
        // Posted 23:50, read at 00:10. A different calendar day, and still
        // twenty minutes ago — the hours rule has to win here or the freshest
        // rows in the feed all claim to be yesterday's news.
        final justAfterMidnight = DateTime(2026, 9, 11, 0, 10);
        expect(
          formatRelativeTime(
            DateTime(2026, 9, 10, 23, 50),
            englishL10n,
            now: justAfterMidnight,
          ),
          '20m ago',
        );
      },
    );
  });

  group('days, then a date', () {
    test('two to six calendar days count days', () {
      expect(at(const Duration(days: 2)), '2 days ago');
      expect(at(const Duration(days: 6)), '6 days ago');
    });

    test('"1 days ago" is unreachable — day one is Yesterday', () {
      for (var h = 24; h <= 47; h++) {
        expect(at(Duration(hours: h)), isNot(contains('1 days')));
      }
    });

    test('a week old switches to a plain date', () {
      expect(at(const Duration(days: 7)), '4 Sep');
      expect(at(const Duration(days: 30)), '12 Aug');
    });

    test('and carries the year once it is not this one', () {
      // "12 Mar" that could mean any of three years is worse than no date.
      expect(
        formatRelativeTime(DateTime(2025, 3, 12), englishL10n, now: now),
        '12 Mar 2025',
      );
      expect(
        formatRelativeTime(DateTime(2026, 3, 12), englishL10n, now: now),
        '12 Mar',
      );
    });
  });

  test('a UTC instant is read in the local calendar', () {
    // The API hands back UTC; "Yesterday" is a word about the reader's
    // calendar, so the comparison has to happen after toLocal().
    final utc = now.toUtc().subtract(const Duration(hours: 30));
    expect(formatRelativeTime(utc, englishL10n, now: now), 'Yesterday');
  });

  /// Money groups South Asian, not Western. The spec says so twice — once in
  /// the Earnings screen's own notes and once in the implementation notes —
  /// and nothing tested it, so `formatCurrency` passed an explicit `'#,##0'`
  /// to `NumberFormat` and printed `Rs 486,000` in both languages.
  ///
  /// The two rules agree below a lakh, which is why every figure anyone
  /// looked at was right.
  group('currency', () {
    final nepaliL10n = AppLocalizationsNe();

    test('groups by two above a lakh, not by three', () {
      expect(formatCurrency(486000, englishL10n), 'Rs 4,86,000');
      expect(formatCurrency(100000, englishL10n), 'Rs 1,00,000');
      expect(formatCurrency(12300000, englishL10n), 'Rs 1,23,00,000');
    });

    test('and is unchanged below one', () {
      expect(formatCurrency(1500, englishL10n), 'Rs 1,500');
      expect(formatCurrency(99999, englishL10n), 'Rs 99,999');
      expect(formatCurrency(72000, englishL10n), 'Rs 72,000');
      expect(formatCurrency(0, englishL10n), 'Rs 0');
    });

    test('Nepali groups the same way, in Devanagari digits', () {
      expect(formatCurrency(486000, nepaliL10n), 'Rs ४,८६,०००');
      expect(formatCurrency(1500, nepaliL10n), 'Rs १,५००');
    });

    test('the Rs symbol stays Latin in both, with its space', () {
      // Deliberate, and documented on the function: the reviewed Nepali
      // corpus and the web app both write `Rs १,०००`.
      expect(formatCurrency(1000, englishL10n), startsWith('Rs '));
      expect(formatCurrency(1000, nepaliL10n), startsWith('Rs '));
    });

    test('fractions are rounded away rather than printed', () {
      // These come off the API as doubles; `Rs 1,500.5` is not a price.
      expect(formatCurrency(1500.4, englishL10n), 'Rs 1,500');
      expect(formatCurrency(1500.6, englishL10n), 'Rs 1,501');
    });
  });
}
