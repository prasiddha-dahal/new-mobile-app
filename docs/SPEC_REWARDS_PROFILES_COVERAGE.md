# Feature Spec — Rewards, Therapist Types, Clinics & Coverage

**Date:** 2026-09-01
**Status:** Draft for review. Recommended defaults are marked **[R]**; every one can be overruled.
**Spans:** `pv-core-api`, `pv-core-mobile`, `pv-core-web`

## Scope

| Part | Feature |
|---|---|
| A | Referral & loyalty points |
| B | Therapist profile types — bookable vs information-only |
| C | Clinic / workplace model |
| D | Map · coverage screen |
| E | Localisation (EN / नेपाली) and the global app bar |

**Explicitly out of scope: therapy packages.** The Lovable prototype has grown five new package
screens (tier picker, package details, book package, my packages, package tracker). Another
developer is working on that area, so nothing here touches `Package`, `packages_screen.dart`, or
the package funnel. Part A intentionally avoids assuming packages exist — points redeem against
sessions only.

## How to read this

Every "today" claim below was verified against the code on 2026-09-01, with file references so
it can be re-checked. Recommendations carry a one-line rationale. Anything genuinely undecided is
listed in [§F Open decisions](#f-open-decisions) rather than quietly assumed.

---

# Current state

What already exists, so the spec builds on it rather than duplicating it.

| Area | Today | Reference |
|---|---|---|
| Referral **codes** | Every user gets one at signup. Real indexed column. | `auth.py:201`, `schema.prisma` `User.referralCode` |
| Referral **read APIs** | `GET /patients/me/referral`; therapist code+link ride on `GET /therapists/me/dashboard` | `patients.py:107`, `models/therapist.py:128` |
| Referral **attribution** | **None.** No `referredBy`, and `SignupRequest` has no code field. | `models/auth.py:11` |
| Points | **Nothing.** No model, no endpoint, no UI. | — |
| Referral screens (mobile) | Built and API-wired, **not routed** — unreachable | `referral_screen.dart`, `therapist_referral_screen.dart` |
| Therapist types | **Nothing.** One profile; booking CTA is unconditional. | `therapist_profile_screen.dart:138` |
| Workplace / hospital | **No field anywhere** in schema, mobile or web | — |
| Clinic | Full model + CRUD + 5 seeded rows | `schema.prisma:552`, `routers/clinics.py` |
| Therapist ↔ Clinic | **No relation at all** | — |
| `Session.clinicId` | **Absent** — a `CLINIC` session doesn't record where | `schema.prisma:215` |
| Coordinates | **None** on `Therapist` or `Clinic` | — |
| Notifications (patient/therapist) | **None.** Only `/notifications` is admin-scoped. | `admin_extras.py:187` |
| Localisation | **No scaffolding** — no `l10n/`, no `flutter_localizations`, strings hardcoded | `pubspec.yaml` |

Two live inconsistencies to fix in passing:

- Link formats differ — patient `https://sahayatri.np/r/{code}`, therapist `https://sahayatri.np/join/{code}`.
- Code formats differ — live codes are `SAHA-RJIBHUNV`, the design shows `SAHA-PT-2841`.

---

# A. Referral & loyalty points

A single points system shared by patients and therapists, with different earning triggers and
different redemption sinks per role.

## A1. Ledger, not a balance **[R]**

Points are append-only transactions; balance is derived.

```
PointTransaction
  id              String    @id
  userId          String    → User
  delta           Int                  -- +earn / −spend, never zero
  type            PointTxType          -- see below
  status          PointTxStatus        -- PENDING | AVAILABLE | REVERSED | EXPIRED
  reason          String?              -- admin/audit text
  refType         String?              -- 'SESSION' | 'REFERRAL' | 'PAYMENT' | 'ADMIN'
  refId           String?
  idempotencyKey  String?   @unique    -- prevents double-credit on retry
  expiresAt       DateTime?
  createdAt       DateTime
  @@index([userId, status])

enum PointTxType   { REFERRAL_EARN, PROMO_GRANT, REDEMPTION, ADJUSTMENT, EXPIRY }
enum PointTxStatus { PENDING, AVAILABLE, REVERSED, EXPIRED }
```

`balance = SUM(delta) WHERE status = AVAILABLE AND (expiresAt IS NULL OR expiresAt > now())`

**Why a ledger.** The "Recent activity" panel in the design is a direct render of this table, and
EARNED / USED / REFERRED are all derivable from it. A mutable integer gives no audit trail, no
dispute resolution, and races on concurrent redemption. Retrofitting a ledger later is painful.

A denormalised `User.pointsBalance` may be cached as an optimisation, but must always be
recomputable from the ledger.

**`idempotencyKey` is not optional.** Double-crediting on a retried request is the most common
real-world bug in these systems.

## A2. Referral attribution

```
User
  referralCode    String?   -- exists today
  referredByCode  String?   -- raw string as entered, kept for audit
  referredById    String?   → User
  @@index([referredById])
```

**Rules [R]**

1. Attribution is captured **only at signup** and is **immutable once set**. Retro-attribution is a
   farming vector.
2. Store both the raw code and the resolved user — the raw string survives even if the code is
   later reissued.
3. **Same-role only.** Patient→patient, therapist→therapist. The reward currencies and milestones
   differ, and cross-role invites create a bad incentive (a therapist farming patients they treat).
4. Self-referral blocked; dedupe on **phone number**, the strongest signal in this market.

**Capture paths — ship 1 and 2, defer 3 [R]**

1. A "Have a referral code?" field on signup. Costs nothing, works forever, is the fallback.
2. Deep link `…/r/{code}` prefills the field when the app is installed.
3. Deferred deep linking (install attribution) — **deferred.** Needs a paid attribution SDK and adds
   a privacy surface, for perhaps a 10–20% attribution lift. Most sharing here happens over
   WhatsApp/Viber where a link plus manual entry converts acceptably. Revisit on volume.
   *Note: do not reach for Firebase Dynamic Links — it has been shut down.*

**Code format [R]** — keep existing `SAHA-XXXXXXXX` codes valid forever; they are already shared.
Generate new codes in the role-prefixed style. Treat codes as **opaque identifiers resolved by
lookup** — never parse the `PT` for meaning, since it breaks the moment a role changes. Exclude
ambiguous characters (`O`/`0`, `I`/`1`); these get read aloud and hand-typed.

Unify the link format to `https://sahayatri.np/r/{code}` for both roles.

## A3. Earning

| Role | Trigger **[R]** | Award |
|---|---|---|
| Patient | Referred patient's **first completed session** | Both parties earn (default Rs 200 each) |
| Therapist | Referred therapist's **first completed session** | Referrer earns; referee optional |

**Award on completed, not booked [R].** The design says "when your friend books their first
session"; book-then-cancel is the obvious farm. Completion is the value-creating milestone and is
the standard marketplace trigger.

**Therapist trigger is not registration [R].** Registration is free to fake and yields no platform
value, and approval is admin-controlled, which introduces collusion risk. If you want to
acknowledge verification effort, a small award on `APPROVED` plus a larger one on first completed
session is a reasonable two-stage variant.

**Pending hold [R]** — points land as `PENDING` and become `AVAILABLE` after **7 days**. This is the
standard cashback mechanic: reversal becomes trivial because nothing was spendable yet. The design
already shows the state (*"Kamala A. — JOINED · PENDING"*).

**Referral lifecycle** (drives the history list in the design):

```
INVITED → JOINED (signed up, milestone unmet) → PENDING (milestone met, in hold) → REWARDED
                                                                   ↘ REVERSED
```

## A4. Redemption

**Patients — apply at checkout, not voucher minting [R].**

Points are chosen during booking and debited at payment. This avoids a voucher entity, orphaned
unused vouchers and partial-use rules, and it drops into the booking/payment flow that already
works. It is the dominant pattern for cash-equivalent points.

This gently reinterprets the mockup: the **Redeem** buttons become *"how you'd like to use your
points"* rather than immediate minting. Keep true minting only for non-monetary catalogue items.

**Therapists — cash on the next payout [R].**

Every reward in the mockup is patient-shaped; a session discount is meaningless to someone who
*earns* from sessions. Marketplaces pay the supply side in cash or fee relief. A bonus line on the
existing payout rail needs no new concept. (Commission relief is the alternative, but there is no
commission model to reduce yet.)

This makes therapist points a genuine cash liability, so caps and clawback matter more there.

**Drop "Free 15-min consult" from v1 [R].** It presumes an online consultation type;
`SessionType` is only `HOME_VISIT | CLINIC`. Launch with monetary discounts only.

**Cap redemption per booking at ≤50% of session fee [R]** — stops a discount zeroing a session,
which otherwise creates awkward refund and payout edges.

## A5. Who funds a redemption — **the platform, 100% [R]**

The single highest-impact decision here, because it touches code that already works.

When a patient redeems Rs 150 off a session, **the therapist still receives their full fee.** The
discount is customer-acquisition cost borne by the platform. Discounting a therapist's earnings
without consent invites them to refuse discounted bookings and turns a marketing decision into an
earnings dispute.

**Implementation that leaves existing code intact:**

- `Session.fee` stays the **gross** amount → therapist earnings and payouts compute exactly as today
  (`therapist/earnings/*` is unchanged).
- The discount lives on the **payment** record: `discountAmount`, `pointsApplied`.
- Payout = sum of session fees (unchanged). Platform revenue = collected − discount.

Add `fundedBy: PLATFORM | THERAPIST` now even though only `PLATFORM` is ever set — it costs nothing
and leaves room for opt-in therapist promos (discounting to fill empty slots) later.

## A6. Points-to-rupee ratio

**1 pt = Rs 1, stored as config, never hardcoded [R].**

Two schools exist: cash-equivalent 1:1 (simple and trustworthy, but frames points as money for
accounting) versus an abstract ratio like 10:1 (allows quiet devaluation; standard in airline and
hotel programs). For a young marketplace building trust, 1:1 is right — but the design still prints
"≈ Rs 340 in credit" beside a 1:1 rate, which hints someone anticipates divergence.

Never re-rate points already earned.

## A7. Admin controls

**Promo bonuses — manual grant in v1, not a campaign engine [R].**

```
POST /admin/points/grant { userIds[], amount, reason, expiresAt }
```

"Dashain promo bonus" is a handful of festival campaigns a year. A segment builder with scheduling
and auto-award is weeks of work for something run three or four times annually. Graduate later if
frequency justifies it.

**Expiry — 12 months, per-batch, FIFO consumption [R].** Oldest points spend first; each batch dies
on its own date; notify at 30 and 7 days. Typical industry range is 12–24 months.

Consider launching with expiry **off**: it is easy to introduce later for newly earned points, and
much uglier to explain if switched on retroactively.

> **Flagged, not asserted:** expiry of *promotional* credit is generally unproblematic, but rules
> differ where credit was effectively paid for. Worth a local check for Nepal — this is outside what
> this spec can responsibly determine.

**Caps [R]** — the monthly one is what actually stops farming:

| Control | Default | Configurable |
|---|---|---|
| Rewarded referrals per calendar month | 5 | yes |
| Lifetime rewarded referrals | 50 | yes |
| Velocity rule | >3 in 24h → hold for manual review | yes |
| Award amount | Rs 200 / Rs 200 | yes |
| Max redemption per booking | 50% of fee | yes |

**Start conservative [R].** Raising a reward is a happy announcement; cutting one is a trust event.

Config belongs in the existing `Setting` table (`key`/`jsonValue`), which already backs working
hours — no new mechanism needed.

## A8. Integrity & clawback

- **Reverse with a negative entry, never delete.** Type `ADJUSTMENT`, reason `REFUND` / `FRAUD`.
  The original row stays for audit.
- Balances may go negative → block redemption until cured; do not pursue the debt.
- With the 7-day hold, most reversals never touch spendable points.
- Blocked: self-referral, duplicate phone, referred account not reaching the milestone itself.

## A9. API surface

```
GET  /points/me                      -- balance, earned, used, referred
GET  /points/me/transactions         -- paginated ledger → "Recent activity"
GET  /points/me/referrals            -- referral history + states
GET  /rewards                        -- redeemable catalogue
POST /bookings/{id}/apply-points     -- or points field on the existing booking payload
POST /admin/points/grant             -- manual/bulk grant
GET  /admin/points/config            -- award amounts, caps, expiry, ratio
PUT  /admin/points/config
```

Unify the existing `GET /patients/me/referral` and the therapist dashboard's referral fields behind
one role-agnostic `/points/me/referrals`.

## A10. Screens

| Screen | State today | Work |
|---|---|---|
| Rewards / My points | Does not exist | New — balance, earned/used/referred, redeem list |
| Referral history | Does not exist | New — or a section of the above |
| Recent activity | Does not exist | New — renders the ledger |
| Referral share | Built, **unrouted** | Route it; add points context |
| Therapist referral | Built, **unrouted** | Route it; therapist reward copy |
| Signup | Exists | Add "Have a referral code?" field |
| Booking | Exists and working | Add "use points" step |

**Placement [R]:** Account → "Rewards & referrals", plus a Home card for discovery. Do not spend a
bottom-nav tab. The highest-converting prompt is immediately after a completed session — *"Enjoyed
your session? Give Rs 200, get Rs 200"* — worth designing explicitly.

**Keep the two-sided reward** the design shows (both parties earn). It reliably outperforms
one-sided, because the sharer has a non-selfish reason to send it.

## A11. Hard dependency — notifications

There is **no patient- or therapist-facing notification system**. "Your friend joined" is the
highest-converting message in any referral program, so this is a prerequisite, not a nice-to-have.

Minimum: `Notification { userId, type, title, body, readAt, refType, refId }` + `GET /notifications`
+ push. Events: referral joined, referral rewarded, points expiring, redemption confirmed.

Sessions and bookings need this anyway, so it is not points-specific cost. The mobile notifications
screen already exists as an honest empty state, ready to be filled.

---

# B. Therapist profile types

Two profiles, distinguished by one field.

```
Therapist
  listingType  ListingType @default(BOOKABLE)

enum ListingType { BOOKABLE, INFO_ONLY }
```

**The discriminator comes first.** Without it the two profiles cannot diverge, and every UI rule
below has nothing to branch on.

## B1. Bookable therapist — mostly built

| Requirement | Today |
|---|---|
| Home visit available | ✅ `SessionType.HOME_VISIT`, flow verified working |
| Available time slots shown | ✅ real slot calendar on the profile |
| Patient can book and pay | ✅ `POST /payments/process` |
| **Online consultation** | ❌ no online session type |

Online consultation is a feature in its own right — a third `SessionType` plus meeting-link
plumbing — not a field. Out of scope for this spec beyond noting the dependency.

## B2. Information-only therapist — essentially absent

| Requirement | Today |
|---|---|
| Profile visible | ✅ |
| Services / specialization | ⚠️ single `specialty` **string**; the requirement implies multiple |
| **Workplace / hospital** | ❌ no field anywhere |
| **Working days and hours** | ⚠️ data exists but is the wrong thing — see below |
| **No booking button** | ❌ CTA is unconditional (`therapist_profile_screen.dart:138`) |
| Visit at workplace | ❌ depends on the missing workplace |

**On working hours.** Hours do exist, but as a JSON blob in the generic `Setting` table keyed
`wh_{user_id}`, reachable only through the therapist's own authenticated availability endpoints.
It is private scheduling config whose job is *generating bookable slots*. For an information-only
therapist it is close to the opposite concept — they publish hours precisely because there are no
slots to generate. Do not reuse it; see Part C.

## B3. UI rules

These ripple further than the profile screen, and are easy to miss:

1. **Therapist profile** — hide the booking CTA and the slot grid; show workplace, hours and services.
2. **Find list** — every card currently renders a "Book now" button. For `INFO_ONLY` it must become
   "View profile".
3. **Map · coverage** — a service radius is meaningless for an info-only therapist; they render as a
   fixed workplace pin instead (Part D).
4. **Booking guards** — server-side rejection so a deep link or stale client cannot book an
   `INFO_ONLY` therapist. Client-side hiding is not sufficient.
5. **Search / filter** — decide whether info-only therapists appear in default results (see §F).

---

# C. Clinic & workplace model

## C1. Recommendation — model workplace as a relation, not new fields **[R]**

`Clinic` already carries almost exactly what an information-only therapist needs:

```
Clinic { id, name, area, city, address, services[], phone, hours }
```

Seeded example: *Patan Physiotherapy Centre, Lagankhel, Lalitpur,
`hours: "Sun–Fri: 8:00 AM – 5:00 PM"`, `services: [...]`*.

So rather than duplicating workplace fields onto `Therapist`:

```
Therapist.clinicId  String?  → Clinic     -- their workplace
Session.clinicId    String?  → Clinic     -- where a CLINIC visit happens
```

An information-only therapist becomes **"a therapist with a clinic and no bookable slots"** — their
workplace, hours and services all resolve through the linked `Clinic`. One source of truth, one
foreign key instead of four fields, and it makes the map coherent.

This decision changes whether Part B adds ~4 fields to `Therapist` or one relation. **Decide before
implementation starts.**

## C2. Gaps to close

| Gap | Impact |
|---|---|
| No Therapist ↔ Clinic relation | Workplace cannot be expressed at all |
| No `Session.clinicId` | A `CLINIC`-type session doesn't record *where* |
| No clinic booking endpoint | `clinic_api.dart` has only two GETs; `clinic_booking_screen` has nothing behind it |
| Clinic screens unrouted | 4 built screens unreachable — `app_router.dart` names none of them |

Routing the existing clinic screens is hours of work and makes a built feature real. Worth doing
early and independently of everything else here.

## C3. Multi-clinic

A therapist may plausibly work at more than one location. `clinicId` as a single FK is the simple
start; a join table (`TherapistClinic`) is the extensible one. See §F.

---

# D. Map · coverage

New screen in the prototype. Not a generic map — a **coverage** screen.

**Design contents:** area selector chips (Jhamsikhel, Sanepa, Pulchowk, Baneshwor, Maharajgunj,
Chabahil, Bhaktapur Durbar, Nagarkot, Dhulikhel, Pokhara Lakeside) · **Therapists | Clinics**
toggle · pins on a "Kathmandu Valley · Service Map" · a coverage list showing per-therapist radius
("Sports & post-surgery · 6 km radius") badged **COVERS YOU** / **OUT OF RANGE** · CTA "Browse full
therapist list".

Entry point: a third card on Home under "What are you looking for?" — 🗺️ **View on Map**. The
baseline design had only two cards.

## D1. Data required — none of it exists

```
Therapist
  latitude      Float?
  longitude     Float?
  serviceRadiusKm Int?      -- design shows 5–8 km

Clinic
  latitude      Float?
  longitude     Float?
```

Coverage is then `distance(user, therapist) <= serviceRadiusKm`.

**Area list [R]** — the design's chips are named areas, not free-form geography. Model them as a
small seeded `ServiceArea { id, name, city, latitude, longitude }` rather than free text, so
"COVERS YOU" is computed against a known point rather than string-matching a city.

`Therapist.city` and `Clinic.area`/`city` are strings today and cannot support distance maths.

## D2. Client work

- No map package in `pubspec.yaml` at all. Choose one (Google Maps needs a billed API key; consider
  cost and offline behaviour for the target market).
- Info-only therapists render as a **workplace pin**, not a radius (per Part B).

## D3. Sequencing

This screen is **blocked on backend data**. The list half ("in list format") is largely satisfied by
the existing Find screen; the map half cannot start until coordinates and radius exist.

---

# E. Localisation & the global app bar

The prototype now carries a header on **every** screen that the previous design did not have at all:

```
Sahayatri  |  Aakar Sharma  |  [EN] [नेपाली]  |  ⌕
```

**This is the largest single item in this spec**, and the most time-sensitive.

- The mobile app has **zero i18n scaffolding** — no `l10n/`, no `flutter_localizations`, no `.arb`
  files. Every user-facing string is hardcoded in widgets across ~56 screens.
- Retrofitting grows more expensive with every screen built afterwards. **Sequence it early.**
- `pv-core-web` already does this (`useLang()` with `en.ts` / `ne.ts`), so there is an existing
  Nepali translation set to borrow from rather than translating from scratch.

Also needed: the global app bar itself (brand, user name, language toggle, search entry) applied
across screens, replacing the current per-screen headers.

**Unrelated pre-existing drift, worth folding into this work:** the implemented bottom nav is
Home / Find / Sessions / Account. The design — both the old spec and the current prototype — is
**Home / Sessions / (+) / Notifications / Account**. We are missing the Notifications tab and carry
an extra Find tab.

---

# F. Open decisions

Ordered by how much they block. The first three constrain data modelling and should be settled
before implementation.

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| 1 | Who funds redemptions | Platform, 100% (§A5) | Payment model, payout logic |
| 2 | Workplace as `Clinic` relation vs fields on `Therapist` | Relation (§C1) | Parts B, C, D schema |
| 3 | Ledger vs mutable balance | Ledger (§A1) | All of Part A |
| 4 | Therapist referral trigger | First completed session (§A3) | Award logic |
| 5 | What therapists redeem for | Cash on next payout (§A4) | Payout logic |
| 6 | Points ratio fixed or configurable | 1:1, config-stored (§A6) | Display + redemption |
| 7 | Expiry on at launch? | Off initially; 12 months when on (§A7) | Ledger `expiresAt` |
| 8 | Multi-clinic per therapist | Single FK now, join table if needed (§C3) | Part C schema |
| 9 | Do `INFO_ONLY` therapists appear in default search? | — **needs a product call** | Find screen, map |
| 10 | Award amounts and caps | Rs 200/200, 5/month, 50 lifetime (§A7) | Config seed |
| 11 | Deferred deep linking | Defer past v1 (§A2) | Attribution rate only |
| 12 | Nepal rules on promotional credit expiry | **Needs local legal/accounting input** | Expiry policy |

---

# G. Suggested sequencing

Ordered so that nothing is built twice.

**1 — Cheap wins, no dependencies (hours–days)**
Route the already-built screens: clinics (4), referral (2). They are finished, API-wired and
unreachable. This alone makes several board items demonstrably done.

**2 — Localisation scaffolding + global app bar**
Cross-cutting, cheapest now, taxes everything built after it. Borrow the web's `ne.ts` strings.

**3 — Notifications**
Prerequisite for Part A, and independently needed by sessions and bookings.

**4 — Schema foundations** (decisions 1–3 settled first)
`PointTransaction`, `User.referredById`, `Therapist.listingType`, `Therapist.clinicId`,
`Session.clinicId`, coordinates + `serviceRadiusKm`. One migration, then parts B–D unblock in
parallel.

**5 — Part A vertical slice**
Attribution → award on completed session → ledger → My Points screen → apply-at-checkout.

**6 — Parts B and D**
Therapist types and the map, both of which depend on step 4.

---

*Packages are deliberately absent from every section above. When that work lands, Part A's
redemption rules will need a short amendment covering whether points apply to package purchases —
recommend deciding that only once the package model is settled.*
