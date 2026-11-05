# Localization

The app ships in **English (`en`)** and **Nepali (`ne`)**.

Every user-facing string in `lib/` goes through the ARB files. There is one
localisation system, and this document describes it, what is deliberately
outside it, and what still needs a human before release.

---

## The pieces

| Path | What it is |
|---|---|
| `lib/l10n/app_en.arb` | The template. Every key and its `@key` description. |
| `lib/l10n/app_ne.arb` | Nepali. Same keys, no descriptions. |
| `l10n.yaml` | `gen-l10n` configuration. |
| `lib/l10n/generated/` | Generated `AppLocalizations`. **Gitignored — never edit, never commit.** |
| `lib/core/l10n/l10n.dart` | Re-exports `AppLocalizations`, adds `context.l10n` and `englishL10n`. |
| `lib/core/l10n/locale_provider.dart` | `localeProvider` — the selected `Locale`. |
| `lib/core/storage/preferences_storage.dart` | Where the choice is persisted. |
| `test/core/localization_test.dart` | Stops the two ARB files drifting apart. |
| `test/core/no_hardcoded_copy_test.dart` | Stops new English literals appearing in swept files. |
| `test/l10n_harness.dart` | Pumps a screen in a chosen language, for the per-area tests. |

`pubspec.yaml` sets `flutter: generate: true`, so **`flutter pub get`
regenerates `lib/l10n/generated/`**. CI runs `flutter pub get` before
`flutter analyze`, so nothing has to be committed for the build to work. If
the generated classes look stale, run `flutter pub get` again.

---

## How to add a new string

1. Add it to `lib/l10n/app_en.arb`, **with a description**:

   ```json
   "sessionCancelled": "Session cancelled",
   "@sessionCancelled": {
     "description": "Status chip on a session the patient or the therapist called off. Past tense — it has already happened."
   }
   ```

   The description is not paperwork. It is the only context the next
   translator gets, and `localization_test.dart` fails without it. Say what
   the string *is* and where it appears, not what it says.

2. Add the same key to `lib/l10n/app_ne.arb` — no `@` entry there:

   ```json
   "sessionCancelled": "सत्र रद्द गरियो"
   ```

   Both files must carry exactly the same keys, and the Nepali must actually
   be Nepali. Three tests enforce that; see [The guardrails](#the-guardrails).

3. `flutter pub get`

4. Use it:

   ```dart
   import '../l10n/l10n.dart';   // adjust the relative path

   Text(context.l10n.sessionCancelled)
   ```

`context.l10n` never returns null. Where the delegates are not installed
above the widget — a bare `MaterialApp` in a widget test, a widget pumped on
its own — it falls back to the English table rather than throwing, so a
shared widget cannot be broken by its caller's test harness.

`englishL10n` is the same table for code that has **no** `BuildContext`: a
test asserting on a validator's wording, a log line. UI code must not reach
for it — a screen that does renders English to a Nepali reader.

### Naming

Keys are `camelCase` and prefixed by area, so an alphabetical ARB file groups
sensibly: `navHome`, `actionCancel`, `searchTooltip`. Prefer a key that names
the *role* (`actionCancel`) over one that names the *text* (`cancel`) — the
English wording changes more often than the role does.

### Placeholders and plurals

Both are used, and both matter here. Nepali does not put words in the same
order English does, so a string assembled by concatenation is correct in one
language and word salad in the other:

```json
"validationRequired": "Enter {field}.",
"@validationRequired": {
  "description": "…",
  "placeholders": { "field": { "type": "String" } }
}
```

```json
"timeDaysAgo": "{days,plural, =1{1 day ago} other{{days} days ago}}",
"@timeDaysAgo": {
  "description": "…",
  "placeholders": { "days": { "type": "int" } }
}
```

**Numbers go through a placeholder, never interpolation.** Give a numeric
placeholder `"format": "decimalPattern"` and it renders `1,500` in English
and `१,५०० ` in Nepali. A Devanagari sentence with Latin numerals in the
middle of it is the half-finished look the whole exercise exists to remove.

---

## Value or label?

The single most repeated decision in the codebase. Several lists are **sent
to the API**: a therapist's specialism and service city, a complaint
category, a gender, a payment method, the weekday and period keys the
recurring-availability endpoint accepts. Translating those would put
Devanagari into a column that holds English.

So the value and the label are separated, always the same way:

```dart
enum Gender {
  female('Female'), …;

  /// What is sent to the API.
  final String label;

  /// What the picker shows.
  String labelIn(AppLocalizations l10n) => …;
}
```

and, for widgets that take a list of options, a `display` hook:

```dart
ChipSelector(
  options: _categories,                        // values, sent as they are
  display: (v) => _categoryLabel(v, l10n),     // labels, translated
)
```

`SessionStatus` and `ProductCategory` follow the same split, but their
lookups live in the **presentation layer**
(`lib/features/patient/presentation/session_labels.dart`,
`lib/features/shop/presentation/shop_labels.dart`) rather than on the enum:
the domain layer is pure Dart and `AppLocalizations` is not. The enum keeps
its English `label` for logs and tests; a test asserts the two still agree in
English.

---

## Dates, money and relative time

`lib/core/utils/formatters.dart`. Every function takes the caller's
`AppLocalizations` — not optionally, because the failure mode of a
locale-blind formatter is silent.

* **Money** renders `Rs 1,500` in English and `Rs १,५००` in Nepali. The `Rs`
  symbol stays Latin in both. That is not an oversight: the reviewed Nepali
  the app inherited writes amounts exactly that way, and so does the web app.
* **Dates** render `Sat, 7 Mar` and `शनि, ७ मार्च`.
* **Relative times** (`Just now`, `12m ago`, `4 days ago`) are ARB plurals.

One trap is worth knowing about. `DateFormat` throws `LocaleDataException`
for **any** explicitly named locale whose symbol data has not been loaded —
including `en`, and including `en-IN`, which nothing loads at all.
`GlobalMaterialLocalizations` loads the symbols for the locale the app is
running in, which is why `ne` works in the app but not in a widget pumped
without the Material delegates. So `_dateLocale` passes null for English
(exactly what the code did before this was locale-aware) and names another
locale only once `intl` confirms it has the data. A locale it cannot serve
degrades to the default rather than throwing.

---

## How to add a new locale

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb`, set
   `"@@locale": "<code>"`, drop the `@key` entries, translate the values.
2. `flutter pub get`.
3. `supportedLocales` in `lib/core/l10n/locale_provider.dart` reads
   `AppLocalizations.supportedLocales`, which `gen-l10n` derives from the
   files on disk, so nothing is hand-listed.

Three things to check for a non-Latin script: that the Devanagari assertion
in `localization_test.dart` is generalised or skipped for the new locale;
that `_segmentLabel` / `_segmentA11yLabel` in
`lib/core/widgets/app_header.dart` have a case for it; and that the language
toggle still fits — it is a two-segment pill and would need to become a menu
at three or more languages.

---

## The selected locale

`localeProvider` (`lib/core/l10n/locale_provider.dart`) is the **single
source of truth** for the app's language.

- It starts at the device locale when we ship that language, else English, so
  the first frame is already right.
- An explicit choice, restored from storage, overrides the device: someone on
  an English phone who picked Nepali meant it.
- Writes go through `PreferencesStorage`, *not* `StorageService`.
  `StorageService.clearAll()` runs on logout, and a language choice must
  survive signing out.
- It reads and writes the key `app_language`, which is what the pre-l10n
  toggle used, so upgrading does not reset anyone.
- A stored code we no longer ship resolves to English but is **not** rewritten
  on disk, so the original choice is honoured if support returns.

To change it:

```dart
ref.read(localeProvider.notifier).set(const Locale('ne'));
```

There used to be a second store — an `AppLang` enum with its own
SharedPreferences key, feeding two large ported string tables
(`lib/core/i18n/strings_en.dart`, `strings_ne.dart`), a key-based
`Translator`, and an English-keyed `'Book now'.tr(context)` extension. All of
it is gone. Its Nepali was not thrown away: it was mined into the ARB files
first (see below). **Do not reintroduce language state anywhere else.**

---

## The guardrails

Four tests, each for a different way this can rot:

* **`localization_test.dart` — the two files carry the same keys.** Reported
  in both directions, because the failures need different fixes: a key only
  in English ships as silently-untranslated Nepali; a key only in Nepali is
  dead weight nothing renders.
* **`localization_test.dart` — every English key has a description.**
* **`localization_test.dart` — every Nepali value contains Devanagari**, with
  one named exemption list (`untranslatedByDesign`) for strings that have
  nothing in them to translate: a code, an input format, a place name, a
  brand, a composition whose every word arrives through a placeholder. A
  second test asserts every entry on that list really is byte-identical in
  the two files, so it cannot become a place to park unfinished work.
* **`no_hardcoded_copy_test.dart` — no new English literal appears** in
  `lib/core` or `lib/features` in the places a literal is almost always copy.
  It found ten real misses the day it was written. A literal that genuinely
  is data gets `// l10n:value` at the end of its line; that marker is
  deliberately greppable.

Per-area rendering tests (`test/features/*/[area]_l10n_test.dart`) pump a
representative screen, switch the language, and assert the English is gone.
`test/core/nepali_overflow_test.dart` pumps the places most at risk at
320×640 in Nepali, because Nepali is longer than English and the places that
breaks are the places with no room to give.

---

## Where the Nepali came from

Of **1,030 keys**:

- **44** are English in both files, by design, and named in
  `untranslatedByDesign` in `localization_test.dart`.
- **241** carry Nepali inherited from the corpus the app already shipped —
  the ported web translations that used to live in `lib/core/i18n/`. That
  text was already reviewed, so it was mined into the ARB files rather than
  re-translated. Those keys are listed below.
- **The remaining 745 have not been read by a native speaker**: the
  704 written during the localisation sweep, plus everything added on the
  branches since, all listed below. Everything not in the inherited list
  falls into this group.

### Added since the sweep, and also unreviewed

**The 25 `find*` availability keys** added with the booking-discovery
feature — the "when are you free?" filter on the Find screen and the
next-free-slot line on each therapist card:

`findWindowAnyTime`, `findWhenSheetTitle`, `findWhenSheetSubtitle`,
`findWhenDayLabel`, `findWhenTimeLabel`, `findWindowMorning`,
`findWindowAfternoon`, `findWindowEvening`, `findWindowExact`,
`findWindowRange`, `findWindowFrom`, `findWindowTo`, `findWhenApply`,
`findWhenClear`, `findFilterSummary`, `findNoneFreeTitle`,
`findNoneFreeDesc`, `findCheckingMore`, `findCouldNotCheck`,
`findFreeToday`, `findFreeTomorrow`, `findFreeOnDay`, `findNoFreeSlots`,
`findCheckingAvailability`, `findAvailabilityUnknown`.

Two of them — `findWindowRange` and `findFilterSummary` — are on the
`untranslatedByDesign` list: both are pure composition, `{from} – {to}` and
`{day} · {window}`, whose every word arrives already translated through a
placeholder.

Three need a closer read than the rest, because the distinction they draw is
the point of the feature and a mistranslation would invert it:

* `findCheckingAvailability` and `findAvailabilityUnknown` must not read as
  *unavailable*. They mean "we have not been told yet", and a therapist whose
  calendar failed to load would otherwise be presented as busy.
* `findNoFreeSlots` **does** mean "we asked, and there is nothing", and has to
  be clearly different from those two.

**The 19 `availability*` keys** added with the therapist working-hours
editor on `feat/therapist-availability` — the screen that replaced the mock
whose Save did nothing. All written for this branch and **unreviewed**:

`availabilityIntro`, `availabilityHoursHeading`, `availabilityStartLabel`,
`availabilityEndLabel`, `availabilitySessionHeading`,
`availabilitySessionMinutes`, `availabilitySlotsPerDay`,
`availabilityHorizonNote`, `availabilityBookedKept`,
`availabilityStatusSaved`, `availabilityStatusUnsaved`,
`availabilitySaving`, `availabilitySavingNote`, `availabilitySaveSuccess`,
`availabilitySaveFailed`, `availabilityProblemNoDays`,
`availabilityProblemEndBeforeStart`, `availabilityProblemSessionTooLong`,
`availabilityDayOffLink`.

Four of them carry the weight of the feature and want a careful read, because
the distinction each draws is the thing the screen exists to make:

* `availabilityStatusSaved` / `availabilityStatusUnsaved` are the answer to
  the only question the screen is ever asked — whether what is on it is what
  patients will see. "अझै सुरक्षित गरिएको छैन" has to read as a plain
  statement of fact, not as an error or a warning: nothing is wrong, it just
  has not been sent yet.
* `availabilitySaveFailed` must carry the second clause — that the edits are
  still on screen. A therapist who reads only "could not save" and closes the
  screen has lost work they did not need to lose.
* `availabilityProblemNoDays` is a refusal that has to point somewhere. It
  means "not like this, do it over there", and the sentence names the leave
  flow for exactly that reason.

`availabilityTimeSlots` ("समय स्लटहरू") was **removed** from both files with
this change. It headed the prototype's Morning / Afternoon / Evening chips,
which are gone: the API stores a single contiguous span of hours, so those
three buckets could not be saved as drawn. `timeBlockMorning` and its two
siblings stay — the therapist schedule screen still uses them for the
recurring-pattern chips, which the API *does* take in that shape.

**Two more were written on `feat/design-review`**, added for states that
previously showed nothing at all:

| Key | Nepali | Where |
|---|---|---|
| `therapistTodayLoadFailed` | आजका भेटहरू लोड गर्न सकिएन। | Therapist dashboard, where a failed session fetch used to render as "Nothing booked for today." |
| `rewardsCouldNotLoadReferral` | तपाईंको सिफारिस कोड लोड गर्न सकिएन। | Rewards screen, where a failed referral fetch used to remove the whole card silently. |

Both follow the shape of the reviewed `homeCouldNotLoadTherapists`
("थेरापिस्टहरू लोड गर्न सकिएन।") and reuse its verb phrase, so the only new
vocabulary in either is the noun.

**Four more were written on `feat/reach-orphan-screens`**, for the entry points
that made three finished-but-unreachable surfaces reachable. Every one of them
is assembled out of words already in the reviewed 241, so a reviewer is being
asked about the joins rather than about new vocabulary:

| Key | Nepali | Built from | Where |
|---|---|---|---|
| `accountReportPatient` | बिरामीको उजुरी गर्नुहोस् | `accountReportTherapist` ("थेरापिस्टको उजुरी गर्नुहोस्") with the noun from `reportPatientTitle` ("बिरामीको उजुरी") | Therapist Account menu, Support group — the mirror of the patient's `Report a therapist` |
| `therapistRequestRateIncrease` | दर वृद्धिको अनुरोध गर्नुहोस् | `rateIncreaseTitle` ("दर वृद्धि") + the अनुरोध of `earningsRequestPayout` ("भुक्तानी अनुरोध") | Therapist Account menu, directly under `Rate per session` |
| `quickActionShop` | पसल | the same word as `shopEyebrow` | The patient centre-action sheet — the shop's only entrance |
| `quickActionShopMeta` | उपकरण, भाडा र सामग्री | `shopCategoryEquipment` ("उपकरण") and the भाडा of `shopRent` ("+ भाडामा") | Second line under that row |

The two Account rows are the ones worth a careful read. Both are **requests put
to somebody else** — a complaint filed with admin, a fee admin has to approve —
not settings the user changes themselves, and the imperative
`…गर्नुहोस्` is carrying that. A reviewer should check it does, because a row
that reads as "change your rate" promises something the screen cannot do.
**Sixteen more were written on `feat/ui-consistency`**, and are likewise
**unreviewed**. Twelve of them are the copy for controls that used to do
nothing at all and now explain themselves, so the shape they share matters:
each is *(what cannot be done yet)* followed by *(the route that does work)*
— never a flat refusal.

| Key | Nepali | Where |
|---|---|---|
| `loadingSemantics` | लोड हुँदै | Screen-reader name for a skeleton. Never shown on screen; one word, present participle. |
| `loginGoogleUnavailableTitle` | गुगल साइन-इन अझै सुरु भएको छैन | The `Continue with Google` button on Login. |
| `loginGoogleUnavailableBody` | अहिलेलाई आफ्नो इमेल र पासवर्डले साइन इन गर्नुहोस्। गुगल साइन-इन तयार हुँदै छ र तयार भएपछि यहीँ देखिनेछ। | Same dialog. Points at email-and-password, which works. |
| `contactMessageUnavailable` | अहिले एपबाट सन्देश पठाउन मिल्दैन — माथिको इमेल ठेगाना वा फोन नम्बर प्रयोग गर्नुहोस्। | The disabled composer on patient Contact. Mirrors `chatNotAvailable`, which is in the same position on the chat screen. |
| `certificationsAddUnavailableTitle` | प्रमाणपत्र थप्ने सुविधा अझै उपलब्ध छैन | `+ Add certification`. |
| `certificationsAddUnavailableBody` | नयाँ प्रमाणपत्रहरू सहयात्री टोलीले प्रमाणित गर्छ। आफ्ना कागजातहरू टोलीलाई पठाउनुहोस्, जाँच भएपछि ती यहाँ देखिनेछन्। | Same dialog. |
| `payoutAddUnavailableTitle` | भुक्तानी विधि अहिले एपबाट परिवर्तन गर्न मिल्दैन | Both `Add` controls on Payout methods. |
| `payoutAddUnavailableBody` | भुक्तानीका विवरणहरू सहयात्री टोलीसँग मिलाइन्छ। तपाईंको कमाइ कहाँ पठाउने भन्ने थप्न वा बदल्न उनीहरूलाई सम्पर्क गर्नुहोस्। | Same dialog. Consistent with the already-written `earningsPayoutUnavailableBody`. |
| `serviceAreasAddUnavailableTitle` | सेवा क्षेत्रहरू अहिले एपबाट सम्पादन गर्न मिल्दैन | `Add` and the suggested-area chips on Service areas. |
| `serviceAreasAddUnavailableBody` | तपाईंको प्रोफाइलमा अहिले एउटै सहर छ। तपाईं कहाँ भेट लिनुहुन्छ भन्ने बदल्न सहयात्री टोलीलाई सम्पर्क गर्नुहोस्; क्षेत्र-अनुसारको कभरेज पछि आउनेछ। | Same dialog. |
| `signupUploadUnavailableTitle` | फाइल संलग्न गर्ने सुविधा अझै उपलब्ध छैन | The `Tap to upload` dropzone on therapist signup. |
| `signupUploadUnavailableBody` | साइन अप गरेपछि आफ्नो लाइसेन्स र प्रमाणपत्रहरू सहयात्री टोलीलाई पठाउनुहोस्, ती तपाईंको आवेदनमा थपिनेछन्। | Same dialog. |
| `scheduleSlotOpened` | समय खुल्यो। | Toast after a successful slot toggle on the weekly grid. |
| `scheduleSlotClosed` | समय बन्द भयो। | The counterpart. These two must stay clearly distinct — they are the only confirmation that the tap landed. |
| `scheduleRecurringNoneOpened` | खोल्नुपर्ने नयाँ समय छैन — ती पहिले नै तय भएका वा बितिसकेका हुन सक्छन्। | Replaces a hardcoded English literal. |
| `scheduleRecurringOpened` | `{count, plural, …}` | Replaces a hardcoded English literal that pluralised by appending an `s`. ICU plural now, so the Nepali is not forced to follow English's two-form rule. |
| `editProfileSectionProfessional` | पेशागत | Section eyebrow on the therapist edit-profile form. Sibling of the reviewed-corpus `editProfileSectionPersonal` / `…Care`. |

Two of these want a second look beyond the language:

* The twelve `…Unavailable…` strings name **the Sahayatri team** as the way
  round. That is a claim about how the business actually operates, not a
  translation choice — somebody who knows the support process should confirm
  it is true before release, in English first.
* `scheduleRecurringOpened` is the app's second ICU plural. Nepali's plural
  rules are not English's, and the `other` branch is what almost every count
  will hit, so the rendered sentence is what wants reading, not the pattern.

Two subsets of the sweep's 681 need more than a linguistic read:

* **The terms and the privacy policy** (`terms*`, `privacy*`) are legal
  copy. Their Nepali has **not** been through legal review. Whoever owns the
  English text should read the Nepali before release — the refund windows and
  the liability disclaimer in particular say something specific. Both screens
  carry the same warning in a doc comment, and so do the `@key` descriptions.
* **The validation messages** (`validation*`, `field*`) are assembled from
  two halves at an ICU placeholder. A reviewer should read the *rendered*
  sentence, not the two fragments.

<details>
<summary>The 241 keys whose Nepali was inherited</summary>

`aboutStatVerified`, `aboutTitle`, `accountAboutUs`, `accountContact`,
`accountEditProfile`, `accountGroupAbout`, `accountGroupAccount`,
`accountGroupHealth`, `accountGroupSupport`, `accountHelp`,
`accountMySessions`, `accountNotifications`, `accountPaymentMethods`,
`accountRecovery`, `accountReportsFiles`, `accountSavedAddresses`,
`actionAdd`, `actionBack`, `actionBackShort`, `actionBackToHome`,
`actionBookNow`, `actionCancel`, `actionClose`, `actionCopy`,
`actionDone`, `actionLogIn`, `actionLogOut`, `actionReschedule`,
`actionRetry`, `actionSave`, `actionSaveChanges`, `actionSeeAll`,
`actionTryAgain`, `actionView`, `actionViewMySessions`, `addressWork`,
`addressesTitle`, `availabilityTitle`, `bookingAddressLabel`,
`bookingDate`, `bookingNoHiddenCharges`, `bookingPaymentLabel`,
`bookingSessionFee`, `bookingSuccessTitle`, `bookingSummaryLabel`,
`bookingTime`, `bookingTitle`, `cartDelivery`, `cartSubtotal`,
`cartTitle`, `cartTotal`, `certificationVerified`, `choosePatient`,
`clinicLabelDateTime`, `clinicWhenToday`, `clinicWhenTomorrow`,
`clinicsTitle`, `complaintSafety`, `complaintUnsafeEnvironment`,
`contactEmailLabel`, `contactHoursLabel`, `contactPhoneLabel`,
`contactSendMessage`, `contactSendMessageLabel`, `contactTitle`,
`coverageTabClinics`, `dateToday`, `dateTomorrow`, `dateYesterday`,
`dayOffReasonFamily`, `dayOffTitle`, `discoveryFindClinicTitle`,
`earningsLifetime`, `earningsPayoutMethod`, `earningsPending`,
`earningsRequestPayout`, `earningsThisMonth`, `earningsTransactions`,
`editProfileSectionPersonal`, `editProfileTitle`,
`fieldConfirmPasswordLabel`, `fieldDateOfBirthLabel`, `fieldDetails`,
`fieldEmailLabel`, `fieldFullNameLabel`, `fieldGender`,
`fieldGenderLabel`, `fieldHomeAddressLabel`, `fieldNmcLicenceLabel`,
`fieldPasswordLabel`, `fieldReasonLabel`, `filterSports`, `findEyebrow`,
`findSearchHint`, `genderFemale`, `genderMale`, `genderOther`,
`helpTitle`, `homeFindATherapist`, `homeNextSessionLabel`,
`homeNothingBooked`, `homeTopTherapists`, `kpiEarningsLabel`,
`kpiRatingLabel`, `kpiSessionsLabel`, `labelAddress`, `labelCondition`,
`labelContact`, `labelFee`, `labelHours`, `labelPatient`, `labelPhone`,
`labelServices`, `labelSessions`, `labelStatus`, `legalTerms`,
`loginContinueWithGoogle`, `loginEyebrow`, `loginForgotPassword`,
`loginSignUpFree`, `navAccount`, `navHome`, `navNotifications`,
`navRequests`, `navSchedule`, `navSessions`, `notificationPillDone`,
`notificationsMarkAllRead`, `notificationsTitle`, `optionGeriatric`,
`optionMusculoskeletal`, `optionOther`, `optionPediatric`,
`optionPostOp`, `optionPostSurgery`, `optionSportsPostSurgery`,
`orderContinueShopping`, `orderPlaced`, `packageStatusActive`,
`packagesClosed`, `packagesLabelSessions`, `packagesLabelTotal`,
`paymentCashOnVisit`, `paymentMethodsTitle`, `payoutMethodsTitle`,
`pendingBadge`, `pendingPreviewDashboard`, `pendingStatusLabel`,
`pendingTitle`, `performanceTitle`, `privacySharingTitle`,
`profileAbout`, `profileTitle`, `quickActionAddTimeBlock`,
`quickActionEyebrow`, `quickActionNotifications`, `quickActionPackages`,
`quickActionPrompt`, `quickActionViewRequests`, `rateJustificationLabel`,
`recordsLastVisitLabel`, `recoveryKpiSessions`, `recoveryMilestones`,
`recoveryStatSessions`, `recoveryStatUpcoming`, `recoveryTitle`,
`referralStateJoined`, `referralStatePending`, `referralTitle`,
`reportPatientChoose`, `reportsTitle`, `requestAccept`, `requestApprove`,
`requestDecline`, `requestMarkComplete`, `requestsEyebrow`,
`requestsTabCompleted`, `requestsTabUpcoming`, `requestsTitle`,
`reviewSubmit`, `rewardsCopyInviteLink`, `scheduleEyebrow`,
`scheduleRecurring`, `searchTooltip`, `sessionCancelConfirm`,
`sessionNotesTitle`, `sessionStatusCancelled`, `sessionStatusConfirmed`,
`sessionStatusDone`, `sessionTabCancelled`, `sessionTabPast`,
`sessionTabUpcoming`, `sessionTypeHomeVisit`, `sessionsEyebrow`,
`sessionsTitle`, `shareGeneric`, `shopCategoryEquipment`,
`shopCategoryMedicines`, `shopCategoryNutrition`, `shopEyebrow`,
`shopInStock`, `shopOut`, `shopTitle`, `signupCreateAccountEyebrow`,
`signupCreatePatientAccount`, `signupPatientTitle`,
`signupPayoutMethodLabel`, `signupSubmitApplication`,
`signupTellUsAboutYou`, `signupTherapistTitle`, `slotBooked`, `slotOff`,
`slotOpen`, `splashImATherapist`, `statExperience`, `statRating`,
`statReviews`, `statusPending`, `statusToday`, `statusTomorrow`,
`termsPaymentsTitle`, `therapistFieldSpecializationHint`,
`therapistGroupPerformance`, `therapistGroupProfessional`,
`therapistKpiBooked`, `therapistKpiEarnings`, `therapistKpiPatients`,
`therapistKpiRating`, `therapistKpiThisMonth`, `therapistNothingToday`,
`therapistOffline`, `therapistOnline`, `therapistPatientsEyebrow`,
`therapistPayoutMethods`, `therapistPerSessionShort`,
`therapistReviewsHeading`, `therapistTodaySchedule`,
`therapistWaitingOnYou`, `timeJustNow`, `uploadReportSubmit`,
`uploadReportTitle`

</details>

---

## What is deliberately not localised

Everything here is a decision, not an omission.

**Server-supplied text.** `failure.message` is whatever the API said, and the
API says it in English. It is rendered under a translated heading on every
error state — `ErrorStateView` picks the heading from the failure *type*,
which is ours, and shows the message underneath, which is not. The same
applies to notification titles and bodies, therapist bios, product and
package names, `package.cadence`, and `PointTransactionDto.reason`.
Localising any of it is a backend change.

**Route paths, wire values and `type` keys.** `/patient/home`, `SCHEDULED`,
`HOME_VISIT`, `ESEWA`. See [Value or label?](#value-or-label).

**The brand.** `Sahayatri` is spelled the same in both languages, including
where it is embedded in a translated sentence.

**Reference numbers, phone numbers, email addresses, file formats and
dates-as-data** — `SAH-APP-48201`, `+977 1 590 1234`, `JPG / PDF · max 5MB`,
`23 Jun 2026` on the demo report rows.

**Place names.** All six city names and the nine Kathmandu-valley areas stay
in Latin in both languages. That is not laziness: the reviewed Nepali corpus
did exactly the same, and so does local signage. They still go through the
ARB, so the decision is recorded rather than accidental.

**Semantics identifiers used only by tests**, and the `endpoint:` strings on
`ApiTodoState`, which are shown in debug builds only.

**`lib/core/widgets/app_bottom_nav.dart`.** Deleted on
`feat/dead-code-cleanup`. Nothing mounted the prototype bar, so its four
English nav labels were unreachable and it was exempted from the sweep rather
than translated; the exemption list is empty again. Its one live constant,
`reservedHeight`, moved to `nav_bars.dart` as `navBarReservedHeight` with the
same value.

---

## Found and left alone

Things the sweep surfaced that are not translation problems:

* **Five screens are unroutable.** `ReportsScreen`, `RecoveryScreen`,
  `SavedAddressesScreen`, `PaymentMethodsScreen` and `ChatScreen` (patient),
  plus `PatientRecordsScreen`, `RateIncreaseScreen`, `ReportPatientScreen`
  and `UploadReportScreen` (therapist), are not reachable from
  `app_router.dart`. The first four are the **API-backed twins** of
  demo-data screens that *are* routed — `PatientReportsScreen`,
  `PatientRecoveryScreen`, `PatientAddressesScreen`,
  `PatientPaymentMethodsScreen`. Both halves of each pair were swept, so
  whichever one gets wired up is translated.
* **`VerifyPendingScreen` overflows vertically on a 640pt viewport in
  English**, before any translation — it centres a Column in a fixed height
  with no scroll view. Nepali overflows it by *less*. The overflow test
  asserts that comparison rather than an absolute, so the pre-existing bug is
  on the record and cannot get worse.
* **The therapist performance grid** overflows on a 320pt viewport in English
  too: its `childAspectRatio` is fixed. Excluded from the narrow-viewport test
  by name, with the reason.
* **`ErrorState` and `AppBottomNav`** in `lib/core/widgets/` were both dead.
  Both are deleted on `feat/dead-code-cleanup`; `ErrorStateView` in
  `state_views.dart` is the live error surface and keeps `actionTryAgain`.

## What Nepali broke, and what was changed for it

Nepali is longer than English, and four layouts could not take it. All four
are fixed, and none changes anything in English:

1. The sign-in footer (`Don't have an account? Sign up free`) overflowed a
   `Row` by 87px. It is a centred `Wrap` now.
2. `Application ref` beside its fixed-width code overflowed by 27px. The
   label is `Flexible`.
3. The `OR CONTINUE WITH` divider label overflowed on a 320pt phone once its
   two `Expanded` rules had shrunk to nothing. `Flexible`, one line,
   ellipsised.
4. `KpiCard` overflowed by up to 39px. Those cards sit in grids with a fixed
   `childAspectRatio`, so a subtitle that wraps to a second line overflows the
   card rather than making it taller. Every line in the card is capped at one.
