# Per-screen design & functionality review

Branch `feat/design-review`, off `feat/feedback-all01`. Every routed screen in
both roles, read against `docs/LOVABLE_DESIGN_SPEC.md`, against the app's own
conventions, and against plain usability.

**Scope note.** A time-slot filter on therapist search, and the next free slot
shown inline on a therapist row, are being built on another branch and are
deliberately absent from this document.

## How to read this

Every finding is marked:

* **Fixed here** — changed on this branch, with a test.
* **Recommended, not done** — clearly right, but larger than this branch's
  remit, or it touches a screen another branch owns.
* **Needs a product decision** — the code is not obviously wrong; somebody has
  to choose.

Each carries a confidence and a size. Confidence is about the *diagnosis*, not
the fix: **high** means I read the code and the claim is checkable from it.
Anything I could not check from the code says so.

Line numbers are as of the base commit. Findings marked *(fixed)* have moved.

---

# Part 1 — Fixed here

## 1.1 The bottom bar had no labels

**high · small · `lib/core/widgets/nav_bars.dart`**

Every supplied design draws `Home · Sessions · Notifications · Account` under
the icons. The bar rendered glyphs only, with the words attached as
`Semantics(label:)` — so a screen reader knew what the tabs were and a sighted
user had to infer four pictograms. `◷` for Sessions and `☰` for Availability
are not words anyone guesses.

The labels are drawn now at the spec's 10px, 4px under the glyph, pine and
semibold when active, `ink-mute` at 400 when not. Three things came with them:

* **Each slot takes an equal share of its half of the bar** instead of a fixed
  48dp. "Notifications" needs the width; so does `सूचनाहरू`.
* **`FittedBox(scaleDown)`,** not ellipsis. `Notific…` is worse than the whole
  word a point smaller, and `scaleDown` only ever shrinks — every label that
  fits is drawn at 10px.
* **`excludeSemantics: true`** on the wrapping `Semantics`. The visible `Text`
  announces itself now; without this every tab is read twice.
* **`HitTestBehavior.opaque`.** The tap target was the 24dp icon — half the
  48dp minimum. It is the whole slot, ~44dp tall, now.

The four inset regressions in `test/core/nav_bar_insets_test.dart` **did not
need changing.** They are written as relative assertions — a gap measured from
the icon's bottom edge, and a height *delta* of exactly the inset — so they
survive a taller bar without being weakened. The constant they pin (`tall -
short == 48`) is unchanged, because the labels grow the bar identically at
both insets. `test/core/nav_bar_labels_test.dart` now asserts the bar's total
height stays between 48 and 80.

One test *was* rewritten, and it is worth naming: `nepali_overflow_test.dart`
carried a comment saying the bar's labels were invisible and that "a future
design that shows the labels would fail here first". That future arrived. The
test now asserts all four Devanagari labels are actually drawn, which is
stronger than what it did before, not weaker.

`notifications_screen_test.dart` needed one finder scoped. It asserted
`find.text('Notifications')` finds nothing — meaning *the page must not draw a
second header* — and the new tab label is a legitimate second match. It is
scoped to `NotificationsScreen` now, **plus** a new positive assertion that
the word does appear in `PatientNav`, so the scoping cannot quietly become a
way to hide a returning header.

## 1.2 "My packages" was unreachable from the catalogue

**high · small · `lib/features/packages/presentation/screens/therapy_packages_screen.dart`**

Spec §24 puts a `My packages` pill top-right of Therapy Packages.
`MyPackagesScreen` is built, routed at `/patient/packages/mine`, and the
router already passed `onViewMyPackages` into the catalogue screen — and
nothing on the page called it.

It was not *completely* unreachable: the active-package card on Home links to
it (`patient_home_screen.dart:178`). But that card only renders while the
patient has a live package, which is exactly when they least need to look it
up — and the catalogue, the one screen where "what did I already buy?" is the
obvious question, had no door at all.

The pill is now in the header's trailing slot, styled to the spec
(`#D1E8DF` on `#2F5D50`, 11px/600, `6px 12px` padding), reusing the existing
`packagesMyTitle` key so no new string was written. Its tap target is the full
36dp row height rather than the 26dp pill.

## 1.3 `PageHeader`'s trailing slot was hard-capped at 36dp — and burst the row

**high · small · `lib/core/widgets/shared_widgets.dart`**

`PageHeader` has always had a `right` parameter. Nothing used it, and it would
not have worked: the slot was `SizedBox(width: 36)`, so any action wider than
an icon was clipped to a sliver. The spec calls it a **min**-width 36 slot.

It is `ConstrainedBox(minWidth: 36, maxWidth: 45% of the row)` now. With
`right` null it still measures exactly 36, so the title stays centred on the
fifty screens that have no trailing action — `page_header_test.dart` passes
untouched.

**The maximum half of that is a golden's doing.** With only a minimum, the
title was `Expanded` and gave way but the pill did not, and at 1.6× text on a
320dp phone the row overflowed by 48px. No assertion in the suite noticed; the
first golden render showed the striped overflow bar immediately.

## 1.4 `PageHeader` sat 4px off the page grid

**high · small · same file**

`EdgeInsets.fromLTRB(16, 8, 16, 12)`. The spec's app-bar padding is
`8 top / 20 sides / 12 bottom`; the shared `AppHeader` mounted directly above
it already uses `AppSpacing.page` (20); every body under it is on a 20 grid.
So on all ~50 sub-pages the back button was the one element outside the
column everything else lines up to. Now `AppSpacing.page`.

## 1.5 Currency ignored Nepali lakh grouping

**high · small · `lib/core/utils/formatters.dart`**

The spec says it twice — once in the Earnings screen's own notes, once in
implementation note 7: `Rs 4,86,000`, not `Rs 486,000`, above 99,999.

```dart
final formatter = NumberFormat('#,##0', _numberLocale(l10n));  // before
```

Both locales the app runs in already carry the rule — `en_IN` and `ne` both
declare `#,##,##0.###` in `intl`'s symbol data — and the explicit `'#,##0'`
pattern was overriding it with a Western one. I confirmed this against the
resolved `intl` rather than reasoning about it: `NumberFormat('#,##0','en-IN')`
returns `486,000`, `NumberFormat.decimalPattern('en-IN')` returns `4,86,000`.

It is `decimalPattern` now. **Below a lakh the two rules agree**, which is why
it survived 31 call sites and a full manual pass unnoticed — every figure
anyone looked at was correct. The wrong ones are the therapist's `Lifetime`
earnings and the patient's points balance, which are the two largest numbers
in the app. There was no test for `formatCurrency` at all; there are five now,
covering both languages, the boundary, and the rounding of API doubles.

## 1.6 A failed session fetch read as "Nothing booked for today"

**high · small · `lib/features/therapist/presentation/screens/therapist_home_screen.dart`**

The dashboard watched three providers and only ever read `.valueOrNull`. On a
sessions error the list fell back to `const <Session>[]`, which is empty,
which rendered `l10n.therapistNothingToday`.

**A network failure was displayed as a factual claim about the therapist's
day.** For someone deciding whether to leave the house that is the most
expensive wrong answer this screen can give, and pull-to-refresh — invisible,
undocumented — was the only recovery. There is an explicit error branch with a
retry now, ahead of the empty branch.

The two other providers on that screen still degrade silently (KPIs show `—`,
the hero says "not accepting bookings"). Those are listed in Part 2: they are
the same bug but they do not state something false about the day's work.

## 1.7 The rewards screen deleted its referral card on error

**high · small · `lib/features/rewards/presentation/screens/my_points_screen.dart`**

```dart
error: (_, _) => const SizedBox.shrink(),
```

Code, copy button, earnings figure and history all vanished, leaving a screen
that looked like a user who had never referred anyone — on the same screen
where two sibling providers get a full `ErrorStateView` with retry. Now an
inline retry.

## 1.8 `InlineRetry` promoted to `state_views.dart`

**high · small**

`patient_home_screen.dart` had written a private one-line-plus-retry widget
because `ErrorStateView` centres an icon and two paragraphs and wants the
whole viewport, which a card holding one list among five cannot give it. Every
*other* section in that position had reached for `SizedBox.shrink()` instead —
1.6 and 1.7 are both instances. It is shared now, and both use it.

## 1.9 The cart's checkout bar floated over the loading, error and empty states

**high · small · `lib/features/shop/presentation/screens/cart_screen.dart`**

`bottomSheet:` was mounted unconditionally, so a disabled "Proceed to
checkout" sat over the spinner, over the error state's retry button, and over
"your cart is empty" — offering an action on a screen with nothing to act on,
and covering the one control that was live. Every other fixed CTA in the app
is already conditional. Now `lines.isEmpty ? null : …`.

## 1.10 The package card's footer overflowed by 132px

**high · small · `lib/features/packages/presentation/widgets/package_card.dart`**

Also found by a golden, not by an assertion. The price column beside it was
already `Expanded`; the `View packages` button was not, so at 1.6× text the
Nepali label pushed the footer off the right edge of the card. It is
`Flexible` now, and `AppButton.text` caps its label at one line — a button is
a fixed-height box, so a wrapping label does not make it taller, it spills out
of the bottom.

## 1.11 Six user-facing strings were not going through `context.l10n`

**high · small**

| File | Was | Now |
|---|---|---|
| `clinic_profile_screen.dart:149` | `Text('SERVICES', …)` | `l10n.labelServices` |
| `clinic_profile_screen.dart:164` | `Text('ADDRESS', …)` | `l10n.labelAddress` |
| `clinic_booked_screen.dart:103` | `'ADDRESS'` | `l10n.labelAddress` |
| `my_points_screen.dart:542` | `const Text('pending')` | `l10n.referralStatePending.toLowerCase()` |
| `referral_screen.dart:63` | `const Text('Rs 0')` | `formatCurrency(0, l10n)` |
| `therapist_service_areas_screen.dart:79` | `Text(a)` — the raw API value | `_areaLabel(a, l10n)` |

All six reuse keys that already existed. The last is the most interesting: the
helper is defined in that same file and the *suggestion* chips lower down
already call it — only the list of the therapist's own configured areas was
rendering raw English under a Nepali UI.

## 1.12 The coverage map's "Browse all" broke Back

**high · one line · `lib/features/coverage/presentation/screens/coverage_map_screen.dart`**

`context.go('/patient/find')`. Both screens are pages in the Home branch, and
`discovery_section.dart` writes the rule down: `go` replaces the branch's
stack, so Back from Find dropped the user onto the shell's back ladder instead
of returning to the map. Now `push`.

## 1.13 Two new ARB keys

`therapistTodayLoadFailed` and `rewardsCouldNotLoadReferral`, both with `@key`
descriptions on the English side. Their Nepali was written by me and is
**unreviewed** — recorded as such in `docs/localization.md`. Both reuse the
verb phrase of the already-reviewed `homeCouldNotLoadTherapists`, so the only
new vocabulary in either is the noun.

---

# Part 2 — Recommended, not done

Ordered by value.

## 2.1 The three typefaces are not bundled — the single highest-impact visual issue

**high · medium · `pubspec.yaml`**

There is no `fonts:` section, no `assets/fonts/` directory, and `google_fonts`
is not a dependency. Every `fontFamily: 'Fraunces' | 'Inter' | 'IBM Plex Mono'`
in the codebase — 116 of them — resolves to nothing and silently falls back to
the platform default.

The spec's implementation note 2 calls these load-bearing, and it is right:
"Every eyebrow, field label, badge and reference code is mono + uppercase +
letter-spaced — this is the strongest signature of the design." **None of that
is currently visible.** Every serif page title is rendering as Roboto. The app
on a device does not look like the design and cannot, no matter how many
spacing findings get fixed.

Left alone deliberately: it needs font files, licence checks, and a decision
between bundling and `google_fonts` (which fetches at runtime — a real
consideration for this market). That is a product call, not a code change.

Everything else in this document is a detail by comparison.

## 2.2 Nine finished screens are reachable from nowhere

**high · medium · `lib/core/router/app_router.dart`**

Verified by grepping each class name across `lib/` and `test/`:

| Screen | Spec | State |
|---|---|---|
| `ChatScreen` | §26 | no router entry, no reference |
| `RecoveryScreen` | §19 | no router entry — the **API-backed twin** of the routed mock |
| `ReportsScreen` | §18 | same |
| `SavedAddressesScreen` | §20 | same |
| `PaymentMethodsScreen` | §21 | same |
| `PatientRecordsScreen` | §43 | no router entry |
| `UploadReportScreen` | §37 | no router entry |
| `RateIncreaseScreen` | §40 | no router entry |
| `ReportPatientScreen` | §42 | no router entry |

Four of these are worse than dead code: **the routed screens are the mock
ones.** `/patient/recovery` renders `PatientRecoveryScreen`, which hardcodes
`value: 0.6` and a plan title of "ACL Reconstruction — Right Knee" — every
patient sees the same fabricated diagnosis. `RecoveryScreen`, sitting beside
it unrouted, has a real provider, an `ErrorStateView` with retry, an
`EmptyStateView` and an honest `ApiTodoState`. The same pair exists for
reports, addresses and payment methods.

`ReportPatientScreen` is the sharpest loss: it is not a stub, it submits for
real to `POST /admin/complaints` with validation and a confirmation. The
patient half of that feature ships (`Report a therapist` is on the patient
Account menu). **A working safety-reporting path exists for patients and not
for therapists, because of a missing route and a missing menu row.**

Two more routes exist with no UI entry point at all: `/patient/referral`,
`/therapist/referral` and `/therapist/performance`.

Not done here because *which* menu rows to add, in which group, under which
labels, is the Account screen's information architecture — see 3.1.

## 2.3 The whole Shop feature is unreachable

**high · medium**

`/shop`, `/cart`, `/order-success` are routed. Grepping `lib/` for `'/shop'`
finds only `cart_screen.dart:38` and `order_success_screen.dart:70` — both
*return* paths from inside the feature. Shop is not a tab, not in the
quick-action sheet, not in `discoveryEntries`, not on the Account menu.

~800 lines of working commerce UI with no entrance. Spec §§14–16 describe it
as a live patient surface, and it is the app's only non-session revenue.

Same reason as 2.2 for not doing it: where Shop belongs in the navigation is a
product question, and it is a bigger one than a menu row.

## 2.4 Fabricated data presented as the user's own

**high · medium each**

Four screens show invented content as if it were real. This is the only group
in this document with a *trust* cost rather than a polish cost, and the app
contradicts itself on three of them:

* **`therapist_reviews_screen.dart:11–33`** — three invented English patient
  testimonials, a hardcoded `4.9` and `182 reviews`, five filled stars
  unconditionally. Two screens away, `therapist_home_screen.dart:329` says
  *"Individual reviews are not available in the app yet — only your average
  rating."* A therapist taps `★ Ratings & reviews` and lands on three reviews
  that do not exist.
* **`therapist_certifications_screen.dart:14–36`** — `NMC-PT-04821`, "Nepal
  Medical Council", "Issued Mar 2020 · Valid till 2026", each under a pine
  `✓ Verified` pill. Showing a real logged-in therapist somebody else's
  licence number under a Verified badge is the worst instance here.
* **`therapist_payout_methods_screen.dart:51,60`** — a configured eSewa
  account `98XXXXXXXX21` with "auto-payout every Friday". The Earnings screen
  says *"No payout method saved"* on the same data, and its `Change` button
  pushes to this screen. The user can produce the contradiction in two taps.
* **`verify_pending_screen.dart:94`** — `'SAH-APP-48201'`, the spec's *sample*
  reference, hardcoded. Every therapist who applies sees the same one. If they
  quote it to support it means nothing. (It slips `no_hardcoded_copy_test`
  only because `Text(` and the literal are on different lines and that guard
  matches within a line.)

The house pattern for all four already exists and is good — `ApiTodoState`,
used correctly in `patient_records_screen.dart` and
`therapist_referral_screen.dart`. Swapping them over is mechanical.

Not done here because removing a screen's entire visible content changes what
that screen *is*, and the Account menu rows that lead to them would want
revisiting at the same time.

## 2.5 `TherapistAvailabilityScreen` is a mock with a no-op Save

**high · medium**

`_selectedDays` and `_selectedSlots` are `static const`. The chips are bare
`Container`s with no gesture handler at all — they look selectable (pine fill,
stadium, 600 weight) and cannot be tapped. `onPressed: () {}` on the
full-width `Save availability` CTA.

It is reached from the most prominent control on the therapist dashboard, and
the code there says what it *meant* to do:

```dart
// Availability summary. Tapping opens the calendar,
// which is where availability is actually changed.
onTap: () => context.push('/therapist/availability'),
```

It does not open the calendar. The calendar — the *working* version of this
screen — is the Recurring-availability card inside `TherapistScheduleScreen`,
which has real chips and a real `_saveRecurring`.

Recommendation: point the hero row at `/therapist/schedule` and delete this
file. Not done here because deleting a routed screen is the cleanup branch's
territory, and because "availability" and "schedule" being the same screen is
worth someone confirming.

## 2.6 Twelve dead controls

**high · small each**

Every `onPressed: () {}` / `onTap: () {}` in `lib/`:

```
login_screen.dart:206                      "Continue with Google"
patient_addresses_screen.dart:117          edit pencil, every address
patient_addresses_screen.dart:144          "+ Add new address"
patient_contact_screen.dart:90             "Send message"
patient_payment_methods_screen.dart:121    "+ Link wallet"
patient_reports_screen.dart:109            download icon, every report
therapist_availability_screen.dart:122     "Save availability"
therapist_certifications_screen.dart:172   "+ Add certification"
therapist_payout_methods_screen.dart:132   "Add" (bank transfer)
therapist_payout_methods_screen.dart:148   "+ Add new payout method"
therapist_service_areas_screen.dart:137    "Add" (service area)
therapist_service_areas_screen.dart:163    suggestion chips (×5)
```

`patient_contact_screen.dart:90` is the worst: the user composes a support
message into a five-line textarea and taps Send, and nothing happens — no
snackbar, no error, no state change. They will believe it was sent.

The house pattern is already established and good: the `_…Unavailable`
explanation dialog used in `therapist_requests_screen.dart:268`,
`therapist_earnings_screen.dart:267`, `rate_increase_screen.dart:219` and
elsewhere. These twelve never got it. Also note the payment-method radios on
`patient_payment_methods_screen.dart:101` are a bare `Icon` with no `onTap`,
under a subtitle reading "Select your preferred payment method."

Not done here: twelve dialogs need twelve pieces of copy in two languages, and
several of the buttons should probably be *removed* rather than explained —
which is a decision per button.

## 2.7 No shared skeleton; 40 files spin

**medium · medium**

`state_views.dart` provides `ApiTodoState`, `ErrorStateView` and
`EmptyStateView` — good coverage, 31 and 14 files respectively. **It provides
no loading state.** `CircularProgressIndicator` appears in 40 files, almost
always as a hand-rolled `SizedBox(width: 22, child: …strokeWidth: 2)`.

Exactly two skeletons exist, both private to their screen:
`_BalanceSkeleton` (`my_points_screen.dart:215`) and `_SelectSkeleton`
(`upload_report_screen.dart:227`). `my_points_screen.dart` uses a skeleton and
a spinner on the same page.

Two of the spinners are a usability bug rather than polish:
`rate_increase_screen.dart:95` and `therapist_edit_profile_screen.dart:120`
put the spinner *outside* the `ListView`, so the `PageHeader` and its back
button disappear while loading — during a slow fetch there is no way back.

A `SkeletonBox` in `state_views.dart` is small. Rolling it out to 40 files is
not, and picking which lists deserve a skeleton over a spinner is a design
call.

## 2.8 Two empty-state components, split by screen traffic

**high · small**

`EmptyState` (`shared_widgets.dart:248`) is one line of grey text.
`EmptyStateView` (`state_views.dart:170`) is icon + bold title + description +
optional action. The bare one is used on the four highest-traffic patient
lists — Home, Find, **Sessions**, Cart — and the designed one on the other
fifteen. So a patient with nothing booked gets a grey sentence, and a shop
category with nothing in stock gets the full treatment.

## 2.9 Card radius is 16 everywhere; the spec says 18

**high · small token change, medium to reconcile**

`AppRadii` is `4 / 8 / 12 / 16 / 24 / 32 / 999`. The spec's scale is
`999 / 22 / **18 (the card default)** / 14 / 10 / 8`. There is no 18, no 22,
no 10 — and `AppCard` uses `AppRadii.lg` = 16.

The visible consequence is mixed radii on one screen: there are 16 literal
`BorderRadius.circular(18)` calls in screens that also contain `AppCard`s at
16, because people reached for the spec value the token file does not offer.
Repo-wide it is 127 raw `circular(N)` against 32 `AppRadii.` references.

Changing `AppRadii.lg` to 18 is one line but moves every card in the app by
2px, which wants a designer's eye rather than mine.

## 2.10 `PageHeader`'s title collapses at 1.6× on a narrow phone

**high · medium**

Visible in `test/core/goldens/packages_header_320_ne_1_6x.png`: with a back
button, a Fraunces title and an action pill in one row at 320dp/1.6×, the
title truncates to about three glyphs. Nothing overflows — that is 1.3 — but
"थेरा…" is not a page title.

Something has to give at that size. The options are a design decision: drop
the action to an icon at large text scales, move it below the title, or accept
the truncation. Recorded rather than chosen.

## 2.11 Smaller things, verified, each self-contained

* **`clinic_profile_screen.dart:55`** — `Continue to booking` is enabled with
  no slot picked, sending the user to a confirm screen that reads "not
  scheduled" and whose confirm always fails. Its sibling
  `therapist_profile_screen.dart:129` disables the CTA until a slot is chosen
  and argues the case in a comment. One of the two is wrong.
* **`clinic_booking_screen.dart:63`** — navigates to
  `/clinics/booked?ref=$reference`; the route reads `clinic`, `address`,
  `hours`, `date`, `time` and never `ref`. Latent only because confirm always
  fails today. It is the code that runs the moment the endpoint lands.
* **`clinic_list_screen.dart:81`** — the only list screen with no `Scaffold`,
  so no cream background; and it pads by `AppBottomNav.reservedHeight` (96px)
  for a bar that is not mounted on root routes. There is no test file for the
  clinics feature at all.
* **`order_success_screen.dart:49`** — `orderRef('SAH-EQ-90213')` hardcoded,
  the spec's sample. Its sibling `booking_success_screen.dart` does the
  opposite and says so: *"The real session id, not an invented booking
  reference."*
* **`therapist_patients_screen.dart:153`** — every row draws a trailing `›`
  and the card has no `onTap`. The detail sheet it should open exists one file
  away (`patient_records_screen.dart:177`).
* **`therapist_schedule_screen.dart:263`** — a successful slot toggle is
  silent; the cell recolours only after the provider refetches, so a tap can
  look like it did nothing. The failure path toasts.
* **`session_notes_sheet.dart`** — 189 lines, zero call sites, and it is the
  *good* implementation: `Validators.longText(min: 15, max: 2000)` with a
  written rationale about clinical records. What runs instead is a bare
  `AlertDialog` in `therapist_requests_screen.dart:288` with no validation at
  all. The min-length rule the team wrote down is enforced nowhere.
* **`signup_screen.dart`** — collected-then-discarded input: the patient's
  primary concern, and the therapist's available days, time blocks and payout
  method, are never passed to `onComplete`; `_specs` and `_areas` are
  multi-select but only `.first` is sent, so a therapist who picks three
  cities registers one. Only `dob` carries a `TODO(api)`.
* **`signup_screen.dart:823`** — the upload dropzone is a bare `Container`
  labelled "Tap to upload" with no gesture handler, while
  `auth_form_widgets.dart:140` defines a proper `UploadDropzone` (0 refs)
  carrying the honest `TODO(api)`.
* **Dead in `shared_widgets.dart`:** `LoadingState` (285) and `ErrorState`
  (300), both 0 call sites. `AppBottomNav` is dead too — only its
  `reservedHeight` constant is used. Left to the cleanup branch to avoid a
  collision.
* **`therapist_home_screen.dart:414`** — the visit-row status tone collapses
  everything non-completed to green, so a `PENDING` visit reads as
  `CONFIRMED`. Spec §31 shows it as a warning badge.
* **The therapist bar draws `calendar_month_rounded` twice** — once for the
  Schedule tab, once as the centre action's glyph — so it says "calendar"
  twice and means different things. Already flagged in a code comment as
  "worth revisiting"; my colour test had to use the patient bar because
  `find.byIcon` is ambiguous on the therapist one.

---

# Part 3 — Needs a product decision

## 3.1 The Account menus are the app's real navigation, and they are short

The therapist Account screen is missing five of spec §36's rows — `Request
rate increase`, `Upload patient reports`, `Patient records`, `Apply for
emergency day off`, `Report a patient`. Four of those are the orphaned screens
in 2.2; the fifth is routed but reachable only via `Block date` on the
Schedule tab, which is not where anyone looks for emergency leave.

Fixing 2.2 and 2.3 is mostly *this* — deciding what the Account menu is for.
It is the only place in either role where a long tail of screens can hang, and
it is currently carrying about half of what was built.

## 3.2 Referral and Rewards are two screens doing one job

`ReferralScreen` and `MyPointsScreen` both show a referral code, a copy
button, a share row and a "total earned" figure. The Account menu links to
Rewards; Referral is reachable only from a notification deep link. Spec §17
lists `Refer & earn` in the ACCOUNT group and knows nothing about points.
Either the spec is stale or one screen should absorb the other.

## 3.3 API-sourced text stays English under a Nepali UI

A therapist's specialty and city — "Sports & post-surgery · Kathmandu" —
arrive from the API as display strings and do not translate, so the Nepali UI
reads half-translated wherever a therapist row appears: Home, Find, the
profile, every booking summary. The same is true of package `cadence`
(`therapy_packages_screen`), of clinic service names, and of `failure.message`
in `ErrorStateView`, which is whatever the server said.

This is not a client bug and cannot be fixed in Flutter. It needs a server-side
decision: either the API returns a key the client maps, or it returns both
languages, or these fields are accepted as English. `state_views.dart:112`
already documents the `failure.message` half of it.

## 3.4 Amber versus pine on admin requests

Implementation note 3 says amber is the commercial path and pine is the
administrative/trust path, and that the split should be kept. But §40 (rate
increase) and §39 (emergency day off) both draw an **amber** CTA for a request
sent to admin, and the code follows the screens rather than the note. The spec
contradicts itself; somebody should say which wins.

## 3.5 Spec items with no implementation and no TODO

Each of these may have been cut deliberately — nothing in the code says so:

* §11.3, the `Booking for a loved one from abroad` toggle. The diaspora flow is
  the app's differentiator and §25 depends on it.
* §15, the per-line rental duration `<select>` in the cart. The provider
  method (`setRentalDays`) exists and is wired; the control is a read-only
  pill.
* §31.3, the `ADD REMARKS ON LAST SESSION` card on the therapist dashboard —
  which is the natural caller for the orphaned `session_notes_sheet.dart`.
* §10, the *disabled* slot state on a therapist profile. Closed slots are
  filtered out of the grid instead, so the patient cannot see that 14:00
  exists and is taken.

---

# Appendix — what I checked and how

**Verified by reading the code**, and reported above only when the claim is
checkable from it. Two claims that came out of the sweep were **wrong and are
not in this document**: that Terms and Privacy have no entry point (they are
linked from both Account screens, at `patient_account_screen.dart:209,214`
and `therapist_account_screen.dart:240,245`), and that `TherapistReferralScreen`
is unrouted (it is routed at `/therapist/referral`; what it lacks is a link).

**Verified by assertion** — `test/core/nav_bar_labels_test.dart`, 10 tests:
labels present in both bars and in tab order; 10px; below the icon and centred
on it; pine/semibold when active and ink-mute/400 when not; label colour
matches its icon; a tap outside the glyph still selects the tab; each tab
announced once rather than twice; no overflow at 320dp/1.6× in English and in
Nepali; bar height between 48 and 80 under the real `PatientShell`.
`test/core/formatters_test.dart`, 5 new tests: lakh grouping above 99,999,
unchanged below it, Devanagari digits, the Latin `Rs` prefix, and rounding.

**Verified by golden** — `test/core/chrome_golden_test.dart`, 4 images, each
piece of chrome at 390dp/1.0 in English and at 320dp/1.6× in Nepali, under the
app's real theme:

* That the nav labels **are drawn, are legible against the bar, and shrink
  rather than clip** at 320dp/1.6× — and that the active tab's icon and label
  read as one selected thing rather than two.
* That the `My packages` pill **reads against cream** at its tonal fill.
  A colour assertion can only tell you the hex is what you asked for.
* **Two overflows no assertion in the suite caught**, both found by looking at
  the first render: `PageHeader`'s row bursting by 48px (1.3) and the package
  card's footer by 132px (1.10). Both are fixed and both goldens are clean.
* That the pill's Nepali label at 1.6× is **whole and smaller**, not
  ellipsised — the change that made it use `FittedBox` like the nav labels
  came from looking at the first golden, where it read `मेरा प्या…`.

The test font renders glyphs as filled boxes, so these pin geometry, colour
and containment rather than letterforms — which is exactly what both of those
bugs were. Regenerate with `flutter test --update-goldens`, and look at the
diff before accepting it.

**Not verified.** Nothing in this document was checked on a device by me; the
app was not installed or driven. Everything marked high confidence is
checkable from the source, and the four goldens are the only rendering
evidence here.

---

## Result

`flutter analyze` — 0 errors, 0 warnings, 20 infos (unchanged).
`flutter test` — 370 passing, from a baseline of 351.
