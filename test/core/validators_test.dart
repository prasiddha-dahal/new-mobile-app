import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/validation/validators.dart';
import 'package:sahayatri_care_connect/l10n/generated/app_localizations_ne.dart';

/// The rules that decide whether a form submits.
///
/// Two things are worth guarding against and are tested explicitly: rules
/// that are stricter than the server (which reject data the API would have
/// accepted) and rules that are looser (which turn a typo into a 500).
///
/// Every factory takes an [AppLocalizations] now, because the messages come
/// out of the ARB files. The rules themselves do not depend on it — the
/// Nepali group at the bottom pins that: the same input passes or fails
/// identically, only the sentence changes.
void main() {
  final en = englishL10n;

  group('visitAddress', () {
    // QA UX-01: a saved address of just "Chitwan" was carried to the last
    // step and refused with "at least 10 characters".
    final address = Validators.visitAddress(
      en,
      cities: const ['Kathmandu', 'Chitwan'],
    );

    test('a city alone says it is only the city, and what to add', () {
      final error = address('Chitwan');
      expect(error, contains('only the city'));
      expect(error, contains('Chitwan'));
    });

    test('the city check ignores case and spaces', () {
      expect(address('  chitwan '), contains('only the city'));
    });

    test('too short to find says what is missing, not a character count', () {
      final error = address('Tole 4');
      expect(error, contains('street, tole or house number'));
      expect(error, isNot(contains('characters')));
    });

    test('empty asks for the address', () {
      expect(address(''), isNotNull);
    });

    test('a real address passes', () {
      expect(address('House 12, Bharatpur-10, Chitwan'), isNull);
    });

    test('over 300 characters is refused', () {
      expect(address('a' * 301), isNotNull);
    });
  });

  group('email', () {
    final email = Validators.email(en);

    test('accepts ordinary addresses', () {
      for (final ok in [
        'you@example.com',
        'aakar.sharma@sahayatri.np',
        'a+tag@sub.domain.co.uk',
      ]) {
        expect(email(ok), isNull, reason: ok);
      }
    });

    test('rejects the shapes people actually mistype', () {
      for (final bad in ['you@', '@example.com', 'you example.com', 'you@com']) {
        expect(email(bad), isNotNull, reason: bad);
      }
    });

    test('names the fix rather than saying invalid', () {
      expect(email('nope'), contains('you@example.com'));
    });

    test('treats whitespace-only as missing', () {
      expect(email('   '), isNotNull);
    });
  });

  group('phone', () {
    final phone = Validators.phone(en);

    test('accepts exactly ten digits', () {
      for (final ok in ['9801234567', '9841234567', '98-01234567', '98 0123 4567']) {
        expect(phone(ok), isNull, reason: ok);
      }
    });

    test('fewer than ten digits says it is too short', () {
      for (final short in ['1', '98012345', '980123456']) {
        expect(phone(short), en.validationPhoneTooShort, reason: short);
      }
    });

    test('more than ten digits says it is too long', () {
      for (final long in ['98012345678', '9779801234567', '123456789012345']) {
        expect(phone(long), en.validationPhoneTooLong, reason: long);
      }
    });

    test('a country code is not a ten-digit number', () {
      // `+` is not a digit, a space or a dash, so this is reported as a bad
      // character rather than miscounted -- and with the prefix stripped it
      // would still be thirteen digits.
      expect(phone('+977 9801234567'), isNotNull);
    });

    test('letters are named, not counted as missing digits', () {
      expect(phone('98a1234567'), en.validationPhoneInvalid);
      expect(phone('98012x'), en.validationPhoneInvalid);
    });

    test('blank asks for the number', () {
      expect(phone(''), en.validationPhoneRequired);
      expect(phone('   '), en.validationPhoneRequired);
      expect(phone(null), en.validationPhoneRequired);
    });

    test('three different mistakes read as three different sentences', () {
      final messages = {
        phone('123'),
        phone('12345678901'),
        phone('abc'),
        phone(''),
      };
      expect(messages, hasLength(4));
    });
  });

  group('normalizePhone', () {
    test('reduces what older accounts hold to the ten digits', () {
      expect(Validators.normalizePhone('+977 9801234567'), '9801234567');
      expect(Validators.normalizePhone('977-9801234567'), '9801234567');
      expect(Validators.normalizePhone('9801234567'), '9801234567');
      expect(Validators.normalizePhone('98-01234567'), '9801234567');
    });

    test('leaves a value that is not a ten-digit number alone', () {
      // Better visible and wrong than silently rewritten into something else.
      expect(Validators.normalizePhone('01-4261234'), '01-4261234');
      expect(Validators.normalizePhone('12345'), '12345');
    });

    test('null and blank become empty', () {
      expect(Validators.normalizePhone(null), '');
      expect(Validators.normalizePhone('  '), '');
    });
  });

  group('phoneInputFormatters', () {
    String typed(String text) {
      var value = const TextEditingValue();
      for (final f in Validators.phoneInputFormatters) {
        value = f.formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(text: text),
        );
      }
      return value.text;
    }

    test('keep digits and drop everything else', () {
      expect(typed('98a-01 23+45'), '98012345');
    });

    test('do not cap the length, so "too long" can be shown', () {
      expect(typed('98012345678'), hasLength(11));
    });
  });

  group('password', () {
    final password = Validators.password(en);

    test('accepts one meeting every rule', () {
      expect(password('Sahayatri1!'), isNull);
    });

    test('reports one unmet rule at a time', () {
      expect(password('short1!A'.substring(0, 5)), contains('8'));
      expect(password('sahayatri1!'), contains('uppercase'));
      expect(password('SAHAYATRI1!'), contains('lowercase'));
      expect(password('Sahayatri!'), contains('number'));
      expect(password('Sahayatri1'), contains('special'));
    });

    test('the message quotes the rule it is enforcing', () {
      // The constant and the sentence must not drift apart.
      expect(
        password('a' * (Validators.passwordMinLength - 1)),
        contains('${Validators.passwordMinLength}'),
      );
    });

    test('sign-in does not apply the strength rules', () {
      // An account created before this policy must still be able to log in.
      final login = Validators.loginPassword(en);
      expect(login('password123'), isNull);
      expect(login(''), isNotNull);
    });
  });

  group('confirm password', () {
    test('passes when the two match', () {
      final check = Validators.confirmPassword(en, () => 'Sahayatri1!');
      expect(check('Sahayatri1!'), isNull);
    });

    test('fails when they differ', () {
      final check = Validators.confirmPassword(en, () => 'Sahayatri1!');
      expect(check('Sahayatri1'), 'Passwords do not match.');
    });

    test('follows the original as it is typed', () {
      var original = 'abc';
      final check = Validators.confirmPassword(en, () => original);
      expect(check('abc'), isNull);
      original = 'abcd';
      expect(check('abc'), isNotNull, reason: 'reads the value at call time');
    });
  });

  group('date of birth', () {
    final today = DateTime.now();
    final dob = Validators.dateOfBirth(en);

    test('rejects today and the future', () {
      expect(dob(today), isNotNull);
      expect(dob(today.add(const Duration(days: 1))), isNotNull);
    });

    test('accepts an ordinary adult', () {
      expect(dob(DateTime(today.year - 30, 6, 15)), isNull);
    });

    test('allows from 13, because the platform treats children', () {
      expect(dob(DateTime(today.year - 13, 1, 1)), isNull);
      expect(dob(DateTime(today.year - 12, 1, 1)), isNotNull);
    });

    test('and the message quotes that same floor', () {
      expect(
        dob(DateTime(today.year - 12, 1, 1)),
        contains('${Validators.minimumAge}'),
      );
    });

    test('catches a mistyped year rather than policing age', () {
      expect(dob(DateTime(today.year - 200, 1, 1)), contains('year'));
    });

    test('counts the birthday, not just the year', () {
      // Someone who turns 13 tomorrow is still 12 today.
      final turns13Tomorrow = DateTime(
        today.year - 13,
        today.month,
        today.day + 1,
      );
      expect(dob(turns13Tomorrow), isNotNull);
    });
  });

  group('scheduling dates', () {
    final now = DateTime.now();

    test('today is allowed for a day off', () {
      expect(Validators.notInThePast(en, 'a date')(now), isNull);
    });

    test('yesterday is not', () {
      expect(
        Validators.notInThePast(
          en,
          'a date',
        )(now.subtract(const Duration(days: 1))),
        isNotNull,
      );
    });

    test('a range may start and end on the same day', () {
      expect(Validators.dateRange(en, now, now), isNull);
    });

    test('a range may not end before it starts', () {
      expect(
        Validators.dateRange(en, now, now.subtract(const Duration(days: 2))),
        contains('before'),
      );
    });
  });

  group('numbers', () {
    test('a session rate must be a number within bounds', () {
      final rate = Validators.amount(en, 'a rate', min: 100, max: 50000);
      expect(rate('1500'), isNull);
      expect(rate('1,500'), isNull, reason: 'thousands separator is fine');
      expect(rate('abc'), isNotNull);
      expect(rate('50'), isNotNull);
      expect(rate('90000'), isNotNull);
    });

    test('years of experience must be a whole number', () {
      final years = Validators.wholeNumber(en, 'years of experience', max: 70);
      expect(years('11'), isNull);
      expect(years('11.5'), isNotNull);
      expect(years('-1'), isNotNull);
      expect(years('99'), isNotNull);
    });
  });

  group('free text', () {
    test('a reason needs enough detail to act on', () {
      final reason = Validators.longText(en, 'a reason', min: 10);
      expect(reason('too short'), isNotNull);
      expect(reason('The patient did not answer the door.'), isNull);
    });

    test('required trims whitespace', () {
      expect(Validators.required(en, 'your name')('   '), isNotNull);
      expect(Validators.required(en, 'your name')('Aakar'), isNull);
    });

    test('the field name reaches the message', () {
      expect(Validators.required(en, 'your name')(''), contains('your name'));
    });

    test('optional accepts blank but still checks a value', () {
      final maybePhone = Validators.optional(Validators.phone(en));
      expect(maybePhone(''), isNull);
      expect(maybePhone('   '), isNull);
      expect(maybePhone('123'), isNotNull);
      expect(maybePhone('9801234567'), isNull);
    });
  });

  group('gender', () {
    test('is offered as full words, never a letter code', () {
      expect(Gender.labels, ['Female', 'Male', 'Other', 'Prefer not to say']);
    });

    test('the wire value stays English whatever the reader sees', () {
      // The picker shows labelIn(); the form's value, and what the API
      // stores, is `label`. Translating the value would send Devanagari to a
      // column that holds English.
      final ne = AppLocalizationsNe();
      expect(Gender.female.label, 'Female');
      expect(Gender.female.labelIn(ne), isNot('Female'));
      expect(Gender.female.labelIn(en), 'Female');
    });

    test('still reads rows written before the list existed', () {
      expect(Gender.fromLabel('M'), Gender.male);
      expect(Gender.fromLabel('f'), Gender.female);
      expect(Gender.fromLabel('male'), Gender.male);
    });

    test('returns nothing for blank or unknown values', () {
      expect(Gender.fromLabel(null), isNull);
      expect(Gender.fromLabel(''), isNull);
      expect(Gender.fromLabel('unspecified'), isNull);
    });
  });

  group('otp', () {
    final otp = Validators.otp(en);

    test('must be exactly six digits', () {
      expect(otp('123456'), isNull);
      expect(otp('12345'), isNotNull);
      expect(otp('1234567'), isNotNull);
      expect(otp('12345a'), isNotNull);
    });
  });

  group('full name', () {
    final fullName = Validators.fullName(en);

    test('rejects digits, which are always a mistake in a name', () {
      expect(fullName('Aakar 2'), contains('numbers'));
    });

    test('accepts a single-word name', () {
      // Mononyms are common; requiring two words would lock people out.
      expect(fullName('Aakar'), isNull);
    });
  });

  group('referral code', () {
    final code = Validators.referralCode(en);

    test('accepts the shape the server issues', () {
      // generate_referral_code: 'SAHA-' + 8 uppercase letters or digits.
      expect(code('SAHA-RJIBHUNV'), isNull);
      expect(code('SAHA-AB12CD34'), isNull);
    });

    test('tolerates pasted whitespace and lower case', () {
      expect(code('  saha-rjibhunv '), isNull);
    });

    test('rejects codes of the wrong shape', () {
      for (final bad in [
        'RJIBHUNV',
        'SAHA-123',
        'SAHA-TOOMANYCHARS',
        'SAHA-',
      ]) {
        expect(code(bad), isNotNull, reason: bad);
      }
    });

    test('is only applied when a code was actually entered', () {
      // The field is optional; blank must not block signup.
      expect(Validators.optional(Validators.referralCode(en))(''), isNull);
    });
  });

  group('points redemption', () {
    test('is capped at half the fee, matching the server', () {
      // maxRedemptionFractionOfFee defaults to 0.5 server-side.
      expect(Validators.maxRedeemablePoints(available: 10000, fee: 1500), 750);
    });

    test('is capped by the balance when that is lower', () {
      expect(Validators.maxRedeemablePoints(available: 40, fee: 1700), 40);
    });

    test('offers nothing when there is nothing to spend', () {
      expect(Validators.maxRedeemablePoints(available: 0, fee: 1500), 0);
      expect(Validators.maxRedeemablePoints(available: 100, fee: 0), 0);
    });

    test('respects a rate other than one rupee a point', () {
      // 50% of 1500 is Rs 750, which at Rs 2 a point is 375 points.
      expect(
        Validators.maxRedeemablePoints(
          available: 10000,
          fee: 1500,
          pointToNpr: 2,
        ),
        375,
      );
    });

    test('rejects an amount the server would refuse', () {
      final check = Validators.pointsToRedeem(en, available: 1000, fee: 1500);
      expect(check(750), isNull);
      expect(check(751), contains('750'));
      expect(check(-1), isNotNull);
    });

    test('names the balance when that is the binding limit', () {
      final check = Validators.pointsToRedeem(en, available: 40, fee: 1700);
      expect(check(41), contains('40'));
    });
  });

  group('in Nepali', () {
    final ne = AppLocalizationsNe();
    final devanagari = RegExp(r'[ऀ-ॿ]');

    test('the rules are identical — only the sentence changes', () {
      // Every rule below is the same assertion as its English counterpart
      // above. A validator that behaved differently per locale would let a
      // form submit in one language and not the other.
      expect(Validators.email(ne)('you@example.com'), isNull);
      expect(Validators.email(ne)('you@'), isNotNull);
      expect(Validators.phone(ne)('9801234567'), isNull);
      expect(Validators.phone(ne)('980123456'), isNotNull);
      expect(Validators.phone(ne)('98012345678'), isNotNull);
      expect(Validators.password(ne)('Sahayatri1!'), isNull);
      expect(Validators.otp(ne)('123456'), isNull);
      expect(Validators.referralCode(ne)('SAHA-AB12CD34'), isNull);
    });

    test('and the sentence really is Nepali', () {
      for (final message in <String?>[
        Validators.email(ne)(''),
        Validators.email(ne)('nope'),
        Validators.phone(ne)('1'),
        Validators.fullName(ne)('Aakar 2'),
        Validators.password(ne)('a'),
        Validators.password(ne)('sahayatri1!'),
        Validators.otp(ne)('12'),
        Validators.referralCode(ne)('nope'),
        Validators.dateOfBirth(ne)(null),
        Validators.dateRange(ne, null, null),
        Validators.amount(ne, ne.fieldRatePerSession, min: 100)('1'),
        Validators.longText(ne, ne.fieldWhatHappened, min: 10)('short'),
        Validators.required(ne, ne.fieldHomeAddress)(''),
      ]) {
        expect(message, isNotNull);
        expect(
          devanagari.hasMatch(message!),
          isTrue,
          reason: 'still English: $message',
        );
      }
    });

    test('the field name inside the sentence is Nepali too', () {
      // The half that is easiest to miss: a translated frame around an
      // English noun reads worse than plain English would.
      final message = Validators.required(ne, ne.fieldHomeAddress)('');
      expect(message, contains(ne.fieldHomeAddress));
      expect(message, isNot(contains('home address')));
    });

    test('counted values are written in Devanagari digits', () {
      // A Devanagari sentence with Latin numerals in the middle of it is the
      // same half-finished look this pass exists to remove.
      expect(Validators.pointsToRedeem(ne, available: 40, fee: 1700)(41),
          contains('४०'));
      expect(Validators.longText(ne, ne.fieldComment, min: 10)('a'),
          contains('१०'));
    });
  });
}
