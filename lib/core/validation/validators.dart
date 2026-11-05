/// Form validators, shared by every form in the app.
///
/// Each returns `null` when the value is acceptable and a sentence when it is
/// not, which is the shape `TextFormField.validator` expects.
///
/// Two rules kept these honest:
///
/// * **Agree with the server.** A rule the API does not enforce invents a
///   restriction; a rule looser than the API's turns a fixable typo into a
///   500. Phone length and the date format below mirror
///   `PatientProfileUpdate` exactly, and the password policy mirrors the
///   web's onboarding, which is the platform's existing rule.
/// * **Say what to do.** "Invalid input" tells someone nothing. Every message
///   below names the field and the fix.
/// * **Say it in the reader's language.** Every factory takes the caller's
///   [AppLocalizations] and every message comes out of the ARB files. The
///   field names folded into them are ARB keys too: "Enter your full name."
///   puts the noun after the verb and Nepali puts it before, so the two halves
///   have to reach the placeholder separately rather than being concatenated
///   at the call site.
///
/// Factories that used to be plain functions — `Validators.email` — are curried
/// now: `Validators.email(context.l10n)` returns the validator. That keeps them
/// usable as `validator:` arguments without a closure at every call site.
library;

import 'package:flutter/services.dart';
import '../l10n/l10n.dart';

class Validators {
  Validators._();

  // --- Presence ------------------------------------------------------------

  /// Rejects empty and whitespace-only input.
  ///
  /// [field] is folded into the message, so pass it as it reads in a sentence
  /// ('your full name', 'a reason') rather than the SHOUTED field label.
  static String? Function(String?) required(
    AppLocalizations l10n,
    String field,
  ) {
    return (value) => (value == null || value.trim().isEmpty)
        ? l10n.validationRequired(field)
        : null;
  }

  /// City must be one of the places the platform actually serves.
  ///
  /// Free text is allowed in the field for typing, but only [supportedCities]
  /// match therapists. Rejecting early avoids a bare 422 from the API.
  static String? Function(String?) serviceCity(
    AppLocalizations l10n, {
    List<String> cities = const [],
  }) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationRequired(l10n.fieldCityOrArea);
      final ok = cities.any((c) => c.toLowerCase() == v.toLowerCase());
      if (!ok) {
        return l10n.validationUnsupportedCity(cities.join(', '));
      }
      return null;
    };
  }

  /// Optional by design: blank passes, anything present must satisfy [inner].
  ///
  /// Lets an optional field carry a real format rule without demanding a value
  /// — a blank second phone number is fine, a malformed one is not.
  static String? Function(String?) optional(String? Function(String?) inner) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? null : inner(value);
  }

  // --- Identity ------------------------------------------------------------

  /// Deliberately permissive: one `@`, something either side, a dot in the
  /// domain. Stricter patterns reject addresses that are perfectly valid, and
  /// the confirmation email is the real proof anyway.
  static String? Function(String?) email(AppLocalizations l10n) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationEmailRequired;
      final pattern = RegExp(r'^[a-zA-Z][^@\s]*@[^@\s]+\.[^@\s]{2,}$');
      if (!pattern.hasMatch(v)) return l10n.validationEmailInvalid;
      return null;
    };
  }

  /// Digits only while typing. Deliberately no length cap: a cap would make
  /// the "too long" message unreachable, and an eleventh digit is exactly the
  /// slip that message exists to explain.
  static final List<TextInputFormatter> phoneInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  /// A Nepali mobile number is ten digits, and the field says so.
  ///
  /// This used to accept 7-15 digits, "matching the server's own rule" -- which
  /// let `98412` and a pasted `+977 9841234567` through as equally fine, and
  /// left the person to find out from a failed save. The server is still the
  /// looser of the two, so a ten-digit number always satisfies both.
  ///
  /// Separators are tolerated (`98-41234567`) because a number pasted from a
  /// contact card carries them; the count is of digits. Anything that is not a
  /// digit, a space or a dash is rejected by name rather than silently
  /// dropped, so a letter in the middle of a number is not read as a short one.
  static const int phoneLength = 10;

  static String? Function(String?) phone(AppLocalizations l10n) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationPhoneRequired;

      if (RegExp(r'[^\d\s\-]').hasMatch(v)) {
        return l10n.validationPhoneInvalid;
      }

      final digits = v.replaceAll(RegExp(r'\D'), '');

      if (!digits.startsWith('9')) {
        return l10n.validationPhoneInvalid;
      }

      if (digits.length < phoneLength) {
        return l10n.validationPhoneTooShort;
      }

      if (digits.length > phoneLength) {
        return l10n.validationPhoneTooLong;
      }

      return null;
    };
  }

  /// The ten digits of a stored number, for pre-filling a field that now
  /// requires exactly that.
  ///
  /// Accounts created before the rule hold `+977 98XXXXXXXX` or
  /// `9779841234567`; loading those into the field as they are would make a
  /// valid number fail validation the first time someone opens Edit profile.
  /// Anything that does not reduce to ten digits is returned untouched, so a
  /// genuinely malformed value stays visible for the person to correct.
  static String normalizePhone(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == phoneLength + 3 && digits.startsWith('977')) {
      digits = digits.substring(3);
    }
    return digits.length == phoneLength ? digits : value;
  }

  static String? Function(String?) fullName(AppLocalizations l10n) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationNameRequired;
      if (v.length < 2) return l10n.validationNameRequired;
      if (RegExp(r'\d').hasMatch(v)) return l10n.validationNameNoDigits;
      return null;
    };
  }

  // --- Credentials ---------------------------------------------------------

  /// The five rules the web's onboarding already applies, so a password
  /// accepted on one client is accepted on the other.
  ///
  /// Reports one unmet rule at a time: listing five failures at once reads as
  /// a telling-off, and people fix them one at a time regardless.
  /// The floor the message quotes, so the rule and the sentence cannot drift.
  static const int passwordMinLength = 8;

  static String? Function(String?) password(AppLocalizations l10n) {
    return (value) {
      final v = value ?? '';
      if (v.isEmpty) return l10n.validationPasswordRequired;
      if (v.length < passwordMinLength) {
        return l10n.validationPasswordTooShort(passwordMinLength);
      }
      if (!RegExp(r'[A-Z]').hasMatch(v)) {
        return l10n.validationPasswordNeedsUppercase;
      }
      if (!RegExp(r'[a-z]').hasMatch(v)) {
        return l10n.validationPasswordNeedsLowercase;
      }
      if (!RegExp(r'[0-9]').hasMatch(v)) {
        return l10n.validationPasswordNeedsDigit;
      }
      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
        return l10n.validationPasswordNeedsSymbol;
      }
      return null;
    };
  }

  /// Only checks that the two match. The strength rules belong to the first
  /// field, and repeating them here would show the same complaint twice.
  static String? Function(String?) confirmPassword(
    AppLocalizations l10n,
    String Function() original,
  ) {
    return (value) {
      if (value == null || value.isEmpty) {
        return l10n.validationConfirmPasswordRequired;
      }
      if (value != original()) return l10n.validationPasswordsDoNotMatch;
      return null;
    };
  }

  /// Sign-in only. Deliberately not [password]: an existing account may predate
  /// the current policy, and telling someone their real password is invalid
  /// while they are trying to use it is worse than letting the server answer.
  static String? Function(String?) loginPassword(AppLocalizations l10n) =>
      (value) => (value == null || value.isEmpty)
      ? l10n.validationLoginPasswordRequired
      : null;

  static String? Function(String?) otp(AppLocalizations l10n) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationOtpRequired;
      if (!RegExp(r'^\d{6}$').hasMatch(v)) return l10n.validationOtpLength;
      return null;
    };
  }

  /// A referral code as the server issues them: `SAHA-` followed by eight
  /// uppercase letters or digits (`generate_referral_code`).
  ///
  /// Compared after trimming and upper-casing, because people paste these out
  /// of messages. Attribution is captured once, at signup, and cannot be
  /// applied afterwards — so a typo caught here is the only chance to catch it.
  static String? Function(String?) referralCode(AppLocalizations l10n) {
    return (value) {
      final v = value?.trim().toUpperCase() ?? '';
      if (v.isEmpty) return l10n.validationReferralRequired;
      if (!RegExp(r'^SAHA-[A-Z0-9]{8}$').hasMatch(v)) {
        return l10n.validationReferralShape;
      }
      return null;
    };
  }

  // --- Dates ---------------------------------------------------------------

  /// A date of birth that is in the past and plausible.
  ///
  /// The lower bound is 13, not 18: a parent books for a child, and a
  /// physiotherapy platform has paediatric patients. The upper bound catches
  /// a mistyped year rather than policing anyone's age.
  /// Quoted in the message, so the rule and the sentence cannot drift.
  static const int minimumAge = 16;
  static const int maximumAge = 70;

  static String? Function(DateTime?) dateOfBirth(AppLocalizations l10n) {
    return (value) {
      if (value == null) return l10n.validationDobRequired;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!value.isBefore(today)) return l10n.validationDobNotPast;

      final age = _yearsBetween(value, today);
      if (age < minimumAge) return l10n.validationDobTooYoung(minimumAge);
      if (age > 70) return l10n.validationDobTooOld;
      return null;
    };
  }

  /// For anything that must be scheduled rather than recorded: leave, a day
  /// off, a booking. Today counts as valid; yesterday does not.
  static String? Function(DateTime?) notInThePast(
    AppLocalizations l10n,
    String field,
  ) {
    return (value) {
      if (value == null) return l10n.validationChoose(field);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final picked = DateTime(value.year, value.month, value.day);
      if (picked.isBefore(today)) return l10n.validationDateNotPast;
      return null;
    };
  }

  /// Guards a start/end pair. Same-day ranges are allowed — a single day off
  /// is the common case.
  static String? dateRange(
    AppLocalizations l10n,
    DateTime? from,
    DateTime? to,
  ) {
    if (from == null) return l10n.validationDateRangeStart;
    if (to == null) return l10n.validationDateRangeEnd;
    if (to.isBefore(from)) return l10n.validationDateRangeOrder;
    return null;
  }

  static int _yearsBetween(DateTime from, DateTime to) {
    var years = to.year - from.year;
    final hadBirthday =
        to.month > from.month || (to.month == from.month && to.day >= from.day);
    if (!hadBirthday) years--;
    return years;
  }

  // --- Numbers -------------------------------------------------------------

  /// Money, in whole rupees. [min] and [max] bracket what the platform will
  /// accept so a slipped digit is caught before it reaches a patient.
  static String? Function(String?) amount(
    AppLocalizations l10n,
    String field, {
    double min = 1,
    double max = 1000000,
  }) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationRequired(field);
      final parsed = double.tryParse(v.replaceAll(',', ''));
      if (parsed == null) return l10n.validationNotANumber(field);
      if (parsed < min) return l10n.validationAmountTooLow(min.round());
      if (parsed > max) return l10n.validationAmountTooHigh;
      return null;
    };
  }

  static String? Function(String?) wholeNumber(
    AppLocalizations l10n,
    String field, {
    int min = 0,
    int max = 100,
  }) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationRequired(field);
      final parsed = int.tryParse(v);
      if (parsed == null) return l10n.validationNotAWholeNumber(field);
      if (parsed < min || parsed > max) {
        return l10n.validationNumberRange(min, max);
      }
      return null;
    };
  }

  /// The most points that may be spent on a session of [fee].
  ///
  /// Two ceilings apply: the balance actually available, and the server's
  /// `maxRedemptionFractionOfFee` — half the fee by default, so a discount can
  /// never zero a session and create refund and payout edges. Named here
  /// rather than written inline at the checkout so the two clients and the
  /// server cannot drift apart silently.
  static int maxRedeemablePoints({
    required int available,
    required double fee,
    double capFraction = 0.5,
    double pointToNpr = 1.0,
  }) {
    if (available <= 0 || fee <= 0) return 0;
    final byFee = ((fee * capFraction) / (pointToNpr <= 0 ? 1 : pointToNpr))
        .floor();
    final ceiling = available < byFee ? available : byFee;
    return ceiling < 0 ? 0 : ceiling;
  }

  /// Whether a chosen redemption is one the server would accept.
  static String? Function(int) pointsToRedeem(
    AppLocalizations l10n, {
    required int available,
    required double fee,
    double capFraction = 0.5,
  }) {
    final max = maxRedeemablePoints(
      available: available,
      fee: fee,
      capFraction: capFraction,
    );
    return (value) {
      if (value < 0) return l10n.validationPointsNegative;
      if (value > available) return l10n.validationPointsBalance(available);
      if (value > max) return l10n.validationPointsCap(max);
      return null;
    };
  }

  // --- Free text -----------------------------------------------------------

  /// For anything a human will read and act on — a complaint, a reason for a
  /// rate change, session notes. A two-word reason helps nobody triaging it.
  static String? Function(String?) longText(
    AppLocalizations l10n,
    String field, {
    int min = 10,
    int max = 1000,
  }) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.validationRequired(field);
      if (v.length < min) return l10n.validationTextTooShort(min);
      if (v.length > max) return l10n.validationTextTooLong(max);
      return null;
    };
  }

  /// The address a therapist is sent to.
  ///
  /// Says what is missing rather than counting characters: the prefill is the
  /// patient's city, and "Chitwan" refused with "at least 10 characters" --
  /// after the screen had happily carried it to the last step -- told nobody
  /// what to add.
  static String? Function(String?) visitAddress(
    AppLocalizations l10n, {
    List<String> cities = const [],
  }) {
    return (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return l10n.addressRequired;
      // "Kathmandu", "Kathmandu, Nepal", "kathmandu." -- all still only a city.
      final bare = v
          .toLowerCase()
          .replaceAll(RegExp(r'[,.\s]*(nepal)?[,.\s]*$'), '')
          .trim();
      final isCity = cities.any((c) => c.toLowerCase() == bare);
      if (isCity)
        return l10n.addressOnlyCity(v.replaceAll(RegExp(r'[,.\s]+$'), ''));
      if (v.length < 10) return l10n.addressTooVague;
      if (v.length > 300) return l10n.validationTextTooLong(300);
      return null;
    };
  }

  static String? Function(String?) maxLength(
    AppLocalizations l10n,
    String field,
    int max,
  ) {
    return (value) => (value != null && value.trim().length > max)
        ? l10n.validationFieldTooLong(field, max)
        : null;
  }

  // --- Choice --------------------------------------------------------------

  /// For a picker whose value is held outside a TextFormField.
  static String? Function(String?) selection(
    AppLocalizations l10n,
    String field,
  ) {
    return (value) =>
        (value == null || value.isEmpty) ? l10n.validationChoose(field) : null;
  }
}

/// The gender options offered anywhere gender is collected.
///
/// Written out in full rather than stored as `M` / `F`: the API keeps this as
/// free text, the therapist directory displays it verbatim, and a one-letter
/// code would surface to patients as "M". `preferNotToSay` exists so the field
/// can be answered without disclosing.
enum Gender {
  female('Female'),
  male('Male'),
  other('Other'),
  preferNotToSay('Prefer not to say');

  const Gender(this.label);

  /// Exactly what is sent to the API and stored against the account.
  ///
  /// **Not** what the picker shows — that is [labelIn]. The two were the same
  /// string until the app spoke Nepali; keeping them the same would have meant
  /// either sending Devanagari to an API that stores English, or showing a
  /// Nepali reader an English word. The value is the contract, the label is
  /// the copy, and they are allowed to differ.
  final String label;

  /// What the picker shows for this option, in the reader's language.
  String labelIn(AppLocalizations l10n) => switch (this) {
    Gender.female => l10n.genderFemale,
    Gender.male => l10n.genderMale,
    Gender.other => l10n.genderOther,
    Gender.preferNotToSay => l10n.genderPreferNotToSay,
  };

  static Gender? fromLabel(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final needle = value.trim().toLowerCase();
    for (final g in Gender.values) {
      if (g.label.toLowerCase() == needle) return g;
    }
    // Tolerates rows written before this list existed.
    if (needle == 'm') return Gender.male;
    if (needle == 'f') return Gender.female;
    return null;
  }

  static List<String> get labels => Gender.values.map((g) => g.label).toList();
}
