# Manual test plan — Sahayatri Physio mobile

For a tester working through the app by hand on a device or emulator.

**Read this first, or you will file bugs that aren't bugs:** roughly a third of the
app is deliberately unfinished, because the backend endpoint behind it does not
exist yet. Those screens are built to completion and show an honest *"not
available yet"* message. **That message is a PASS.** Every one is listed in
§6 so you can tell them apart from real failures at a glance.

---

## 1. Setup

### 1.1 Point the app at a working API

**Do not test against production.** `https://pvc-api-production.up.railway.app`
currently returns **401 on every signed-in request** — a backend bug (the JWT
`aud` claim is issued but not validated). Until that fix is deployed, production
can only get you as far as the login screen.

Run the API locally instead:

```bash
cd pv-core-api
.venv/Scripts/python.exe main.py
```

Check it answers before going further — `{"status":"healthy", ... "database":"ok"}`:

```bash
curl http://localhost:8000/health
```

`"redis":"error"` in that response is expected and harmless.

### 1.2 Launch the app

**Emulator:**

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**Physical device over USB** — needs the tunnel first, and **again after every
unplug**, or the app cannot reach your machine:

```bash
adb reverse tcp:8000 tcp:8000
```

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### 1.3 Accounts

Password for all three is `password123`.

| Account | Role | Use for |
|---|---|---|
| `patient@test.com` | Patient | §2, §3 |
| `therapist@test.com` | Therapist | §4 |
| `admin@test.com` | Admin | No mobile UI — mobile is patient/therapist only |

### 1.4 Reporting a failure

Include: the test ID, what you saw, what you expected, the device and OS, and
whether the API was local or production. A screenshot helps. If the app showed a
red error banner, quote it — the wording identifies which layer failed.

---

## 2. Authentication (P0)

| ID | Steps | Expected |
|---|---|---|
| **A1** | Cold-start the app | Splash: logo, `Sahayatri Physio`, the three stat chips, then `Get started →`, `I'm a physiotherapist`, `Already have an account? Log in` |
| **A2** | Splash → `Already have an account? Log in` | Login screen |
| **A3** | Log in as `patient@test.com` / `password123` | Lands on **patient Home**. Bottom bar: Home · Sessions · (+) · Notifications · Account, Home active |
| **A4** | Log in as `therapist@test.com` / `password123` | Lands on **therapist Home** — a different screen with a different bottom bar (Home · Schedule · (+) · Availability · Account) |
| **A5** | Log in with a wrong password | Red banner reading **`Invalid email or password`** — the server's own words, not a generic message |
| **A6** | Tap `Log in` with both fields empty | Inline validation under each field. No network call, no spinner |
| **A7** | Enter `notanemail` in Email, submit | `Enter a valid email address` under the field |
| **A8** | Log in, force-close the app, reopen | Goes **straight to Home**, no login. Brief spinner on splash while the session restores |
| **A9** | Log out (Account → `Log out` → confirm), then reopen the app | Back to splash/login. The session must **not** come back |
| **A10** | **Stop the API**, then try to log in | After a pause: `Cannot reach the server right now` or `The server is taking longer than usual to respond`. The button re-enables so you can retry. **No crash, no infinite spinner** |
| **A11** | Login screen → `Forgot password?` | Three-step flow: email → code → new password. Sending a code needs SMTP configured; without it the code is printed in the API console |
| **A12** | Login screen → `Continue with Google` | Snackbar: not available yet. **This is expected** (§6) |
| **A13** | Splash → `Get started →` | Patient sign-up form. Labels sit **above** each pill field, with grey placeholder text inside |
| **A14** | Sign-up: fill everything, tick the consent box, submit | Moves to an email-verification step asking for a code. `123456` will not work against a real API — the code is emailed, or printed to the API console when SMTP is unset |
| **A15** | Sign-up: leave the consent box unticked | `Create patient account` stays disabled |
| **A16** | Splash → `I'm a physiotherapist` | The longer therapist application form, with document-upload areas |

---

## 3. Patient — core flows (P0)

### 3.1 Home

| ID | Steps | Expected |
|---|---|---|
| **P1** | Look at Home | Green gradient hero `Find Physiotherapist`; `NEXT SESSION`; `FEW THERAPISTS` with `View All →`; `WHAT ARE YOU LOOKING FOR?` with two cards |
| **P2** | Check the `NEXT SESSION` card | Either a real upcoming session, or `No upcoming sessions. Book a therapist to get started.` Dates read **`Today` / `Tomorrow` / `Fri, 10 Jul`** — never a raw `2026-08-21` |
| **P3** | Check the therapist shortlist | Up to 3 real therapists with name, specialty, city and a `★` rating. A therapist nobody has rated shows **`New`**, never `★ 0.0` |
| **P4** | Pull down to refresh | Data reloads without error |

### 3.2 Find a therapist

| ID | Steps | Expected |
|---|---|---|
| **P5** | Tap the hero button, `View All →`, or the centre (+) | Find-therapist screen |
| **P6** | Type `anil` in search | List narrows as you type, after a brief pause. Not on every keystroke |
| **P7** | Search for `zzzzz` | Empty state: `No therapists found` / `Nothing matched "zzzzz"` |
| **P8** | Tap the `Neuro` filter chip | Chip fills green; list filters. `All` clears it |
| **P9** | Check a result card | Avatar, name, `✓`, `specialty · city`, rating, review count, `Rs 1,500 / session`, `Book now` |

### 3.3 Therapist profile and booking

| ID | Steps | Expected |
|---|---|---|
| **P10** | Tap a therapist row | Profile: green cover, avatar with a `✓` badge, price, stats, `ABOUT` |
| **P11** | Check the back button on the profile | Top-left over the cover — **not overlapping the avatar** |
| **P12** | Scroll to `AVAILABLE SLOTS` | Date chips, then a **4-column** time grid, no large empty gap above it |
| **P13** | Look at the slot colours | Open = white; unavailable = grey and **not tappable**; selected = solid green |
| **P14** | Before picking a slot | `Continue to booking →` is disabled |
| **P15** | Pick a slot, then continue | Booking screen carrying that date and time |
| **P16** | Check the booking summary | Therapist name, the date/time you chose, `60 min` |
| **P17** | Select `eSewa` or `Khalti` | An amber notice appears: online payment isn't live, you pay the therapist directly. **Expected** — no money moves |
| **P18** | Clear the address, tap confirm | `Please enter the visit address`. No booking created |
| **P19** | Complete a booking | Success screen with a reference, address and payment method |
| **P20** | Success → `View my sessions` | The new booking appears under **Upcoming** |
| **P21** | Re-open the therapist's slots | The slot you booked is no longer offered |

### 3.4 My sessions

| ID | Steps | Expected |
|---|---|---|
| **P22** | Open Sessions | Tabs in order: `Upcoming` · `Past` · `Cancelled` |
| **P23** | **Check every date under `Upcoming`** | All are **today or later**. A past-dated session here is a **BUG** — regression check |
| **P24** | Check the buttons under `Upcoming` | `Reschedule` (outline) and `Cancel` (red). Never shown on a past session |
| **P25** | Tap `Reschedule` | Sheet of real free slots. The session's current slot is **absent**. The bottom bar must **not** cover the sheet |
| **P26** | Pick a new slot, confirm | Card moves to the new date; a confirmation appears |
| **P27** | Tap `Cancel`, confirm | Session moves to the `Cancelled` tab |
| **P28** | `Cancel` → `Keep it` | Nothing changes |
| **P29** | Open `Past`, tap `Rate this session` | Star sheet, 1–5, optional comment |
| **P30** | Submit a rating | Confirmation. Rating the **same therapist** twice is refused by the server — that message is correct behaviour |
| **P31** | Open a tab with nothing in it | An empty state, not a blank screen |

### 3.5 Shop and cart

| ID | Steps | Expected |
|---|---|---|
| **P32** | Account → `Shop` | `Equipment & care`, chips `Equipment · Medicines · Nutrition`, 2-column grid |
| **P33** | Find an out-of-stock item | Red `OUT` badge; button reads `Out of stock` and is disabled |
| **P34** | Add an item | Confirmation with a `View cart` action; the cart badge count increases |
| **P35** | Open the cart | Line items, quantity steppers, and a duration dropdown **on equipment only** |
| **P36** | Change quantity and rental duration | The line total and the summary both update |
| **P37** | Check the arithmetic | Equipment = daily rate × quantity × days. Delivery is free above Rs 2,000, otherwise Rs 150 |
| **P38** | With 1 item in the cart | Header reads `1 item`, not `1 items` |
| **P39** | Tap `Proceed to checkout →` | Dialog: checkout not available yet, cart is saved. **Expected** (§6) |
| **P40** | Remove everything | Empty state with `Browse the shop` |

### 3.6 Account

| ID | Steps | Expected |
|---|---|---|
| **P41** | Open Account | Green header with **your real name and email**, then HEALTH / ACCOUNT / SUPPORT groups and `Log out` |
| **P42** | Tap every row | Each opens a screen. **No row should do nothing** |
| **P43** | `Edit profile` → change your name → `Save changes` | Saves, returns, and the new name shows in the header |
| **P44** | Look at DOB / Gender / Primary concern on Edit profile | Greyed with `· coming soon`. **Expected** (§6) |
| **P45** | `Reports & files` | Files shared by a therapist, or an empty state |
| **P46** | `Refer & earn` | Your real referral code, and `Copy` puts it on the clipboard |
| **P47** | `Report a therapist` | Form with categories and stars; the submit button is **green, not amber** |
| **P48** | Submit a report | Confirmation that the trust team will review it |

---

## 4. Therapist (P0)

Log in as `therapist@test.com`.

| ID | Steps | Expected |
|---|---|---|
| **T1** | Open Home | `TODAY'S SCHEDULE`, `MANAGE SCHEDULE`, and a stats row |
| **T2** | Check today's list | Real sessions with time, patient name and status — or an empty state |
| **T3** | Open Schedule | Weekly grid, 7 day columns, with a `Booked / Open / Off` legend |
| **T4** | Tap an empty slot | It toggles open, and the change survives leaving and returning |
| **T5** | Tap a booked slot | It does **not** toggle — a patient's booking cannot be destroyed by a tap |
| **T6** | Set recurring days and time blocks, save | Confirmation; the grid reflects it |
| **T7** | Open Requests | Four tabs: `Requests · Upcoming · Completed · Cancelled` |
| **T8** | Accept a pending request | Moves to `Upcoming` |
| **T9** | Decline a pending request | Moves to `Cancelled` |
| **T10** | Under `Upcoming`, tap `Mark complete` | Moves to `Completed` |
| **T11** | Open My patients | Real patients with condition, session count and last visit |
| **T12** | Open Earnings | Gradient balance card and a transaction list |
| **T13** | Earnings → `Request payout` | Not-available dialog. **Expected** (§6) |
| **T14** | Account → `Upload patient reports` | Patient picker, title, notes, and a file area |
| **T15** | Account → `Apply for emergency day off` | Date range, reason, and a list of past requests |
| **T16** | Submit a day-off request | Appears in the list as pending |
| **T17** | Account → `Request rate increase` | Prefilled with your **real current rate** |
| **T18** | Try to open any `/patient/...` screen as a therapist | Bounced back to the therapist side. Roles must not cross |

---

## 5. Cross-cutting (P1)

| ID | Steps | Expected |
|---|---|---|
| **X1** | Kill the API mid-session, then pull to refresh | A clear error with a retry, per section. The whole screen must not go blank |
| **X2** | Restart the API, tap retry | Data returns |
| **X3** | Turn on airplane mode, act | `No connection` / `Cannot reach the server` — not a crash |
| **X4** | Rotate the device on several screens | No overflow stripes, no clipped text |
| **X5** | Watch any bottom `Confirm` / `Checkout` bar | Fully visible, not cut off by the gesture bar or nav buttons |
| **X6** | Check the bottom bar labels | `Notifications` is fully readable, not `Notificatio…` |
| **X7** | Open every screen with an image | Real content or a neutral grey placeholder. **Never a broken-image icon** |
| **X8** | Tap fast / double-tap submit buttons | No duplicate bookings or orders |
| **X9** | Use the system Back button throughout | Never exits the app from a mid-flow screen unexpectedly |
| **X10** | Set the system font to its largest size | Text stays readable, nothing important is clipped |

---

## 6. Expected "not available yet" — these are PASSES

Each of these is a finished screen whose backend endpoint does not exist. The
honest message is the correct behaviour. **Do not raise these as bugs.**

| Where | What you'll see |
|---|---|
| Login → `Continue with Google` | Not available yet |
| Notifications tab | Empty "coming soon" state |
| Cart → `Proceed to checkout` | Checkout unavailable; cart is kept |
| Edit profile → DOB / Gender / Primary concern | Disabled, `· coming soon` |
| Edit profile → `Change photo` | Not available yet |
| Reports & files → `Upload my own report` | Patients cannot upload yet |
| Recovery progress → milestones | Coming soon; the session count above it is real |
| Saved addresses | Single address only, edited from Edit profile |
| Payment methods | Saved wallets coming soon |
| Care packages → `View packages →` | Package booking not available |
| Chat with us | Composer disabled; the phone number works |
| Clinic profile → slots | Coming soon |
| Clinic booking → confirm | Clinic booking not available |
| Therapist → Earnings → `Request payout` | Not available |
| Therapist → `Request rate increase` → submit | Not available |
| Therapist → `Refer & earn` → invites | Coming soon; the code is real |
| Therapist → `Patient records` → detail | Coming soon |
| Any file upload | Needs a file picker, not yet added |

---

## 7. Known issues — already logged, no need to report

| Issue | Detail |
|---|---|
| **Production API returns 401 on everything** | Backend JWT `aud` bug. Test locally until it's deployed |
| `/sessions` returns 500 on some databases | Missing migration (`Therapist.applicationStatus`). Fix with `prisma db push` |
| `"redis":"error"` in `/health` | Expected — rate limiting uses the in-memory backend |
| Seeded sessions are July-dated | Fixed-date seed data, so most sit under `Past` |
| No app icon | Still the default Flutter icon; branding not yet applied |

---

## 8. Priorities

- **P0 — must pass before any release:** §2, §3.1–3.4, §4
- **P1 — should pass:** §3.5, §3.6, §5
- **P2 — nice to have:** anything in §6 once its endpoint lands

A P0 failure blocks release. Note the test ID against each one.
