# Sahayatri Physio — Mobile Design Spec (from Lovable prototype)

Source of truth: <https://sahayatri-care-connect-mobile-app.lovable.app>
Captured: 2026-08-20 — 43 screens (Shared 7, Patient 23, Physiotherapist 13).
All values below are **computed styles read from the live prototype**, not estimates.

> The prototype is a single page: a sidebar of 43 buttons swaps the content of one phone
> mockup. There is no URL routing, so "navigates to" below describes intent, not a real link.
> Several in-screen buttons in the prototype are inert (noted per screen).

---

## Design system

### Canvas / device frame

| Property | Value |
|---|---|
| Design canvas | **390 × 844 dp** (iPhone 14 Pro logical size) |
| Page background | `#FBFBF8` (cream) |
| Frame radius (mockup only) | 48px — not part of the app UI |
| Status bar | height **44px**, horizontal padding 28px, IBM Plex Mono 12px, color `#1E2A2E`. Left `9:41`, right `●●●●  􀙇  􀛨` (gap 6px) |
| Notch | pill 128 × 24, `#0B0E10`, top 6px, horizontally centered |
| Content scroll area | starts below 44px status bar, bottom padding 8px |

### Color tokens (exact)

These are the actual CSS custom properties defined by the prototype.

| Token | Hex | Use |
|---|---|---|
| `pine` | **#2F5D50** | Brand green. Primary surfaces, selected chips, verified ticks, secondary CTA |
| `pine-light` | **#3F7965** | Gradient end-stop |
| `pine-pale` | **#D1E8DF** | Tonal fill: success badges, avatars, icon circles, tonal buttons, dropzones |
| `cream` | **#FBFBF8** | App background |
| `mist` | **#EEF1ED** | Neutral fill: back button, segmented-tab track, neutral badges, tiles |
| `ink` | **#1E2A2E** | Primary text; also text ON amber buttons |
| `ink-mid` | **#4A5854** | Secondary/body text |
| `ink-mute` | **#8FA8A0** | Tertiary text, eyebrows, field labels, inactive nav |
| `amber-brand` | **#E2962F** | Accent. Primary CTA fill, stars, badge dot, active toggle |
| `amber-pale` | **#FBEFD9** | Warning/pending badge fill; alternate avatar fill |
| *(amber-deep)* | **#8A5A14** | Text on `amber-pale` badges (literal, not a token) |
| `danger` | **#C84B4B** | Destructive text (Cancel, Remove, Log out) |
| `danger-pale` | **#FCE8E8** | Destructive button/badge fill |
| `white` | **#FFFFFF** | Cards, inputs, bottom nav |
| *(verified)* | **#7AE2A1** | "Verified ✓" text on the therapist account header |

**Pastel category tiles** (Care packages / clinic icons only):
`#D1E8DF` (green) · `#E8DCF5` (lilac) · `#FBEFD9` (sand) · `#DCE7F5` (blue) · `#F5DCE0` (blush)

**Borders / hairlines** — always black at low alpha:
`rgba(0,0,0,0.06)` card border & dividers · `rgba(0,0,0,0.07)` · `rgba(0,0,0,0.08)` search + slot buttons · `rgba(0,0,0,0.10)` inputs & unselected chips · `rgba(0,0,0,0.12)` outline circle · `rgba(0,0,0,0.15)` toggle-off track, grab handle, empty star · `rgba(47,93,80,0.4)` dashed dropzone.

**Gradients**

| Name | Value | Where |
|---|---|---|
| Home hero | `linear-gradient(150deg, #2F5D50, #3F7965 90%)` | Patient Home hero card |
| Banner | `linear-gradient(135deg, #2F5D50, #3F7965)` | Therapist profile cover, Earnings card, Payments card |
| Referral | `linear-gradient(135deg, #2F5D50, #3B7364)` | Refer & earn cards |
| Chat header | `linear-gradient(120deg, #1E4B3F, #2F5D50)` | Chat with us header |
| Progress | `linear-gradient(90deg, #2F5D50, #E2962F)` | Recovery progress bar |

**Elevation** — one shadow only:
`0 30px 60px -20px rgba(30,42,46,0.35)` on the mock frame; bottom nav + active segmented tab use a soft `0 1px 3px rgba(0,0,0,0.08)`-class shadow.

### Typography

| Role | Family | Size / weight | Color |
|---|---|---|---|
| Body / UI default | **Inter** (`ui-sans-serif` fallback) | 14px / 400 | `#4A5854` |
| Display + headings | **Fraunces** (serif) | see below | `#1E2A2E` |
| Labels, badges, numbers | **IBM Plex Mono** | 10–12px | `#8FA8A0` |

Fraunces scale, as used:
`36px` splash wordmark · `30px` big currency / success heading · **`28px` standard page H1 (leading-tight)** · `26px` hero H1 (white) · `24px` person name, success heading small · `20px` rate figure · `18px` app-bar title, stat value, card title.

Inter scale: `15px` (package title, 600) · `14px` body / list-tile title / button · `13px` compact card title (600) · `12px` secondary · `11px` meta · `10px` micro.

Two repeating mono label styles:
* **Eyebrow** — 10px, uppercase, letter-spacing **1.8px** (`0.18em`), `#8FA8A0`. Sits above every page H1 and above every section.
* **Field label** — 10px, uppercase, letter-spacing **0.5px**, `#8FA8A0`, 6px below-margin.

Weights used: 400, **600 (semibold — the workhorse)**, 700 (totals, milestone numerals).

### Radius scale

| Name | px | Applied to |
|---|---|---|
| full | 9999 | buttons, chips, badges, inputs, avatars-adjacent pills, bottom-nav FAB |
| 3xl | **22** | hero card, bottom nav bar, bottom-sheet top corners |
| 2xl | **18** | **cards** (the default), textareas, dropzones, tiles, share buttons |
| xl | **14** | small tiles, time-slot buttons, icon squares, date chips |
| lg | **10** | bottom-sheet detail rows |
| md | **8** | schedule-grid cells |
| circle | 50% | avatars |
| Account header | `0 0 28px 28px` | bottom-only rounding on the green profile header |

### Spacing scale

Multiples of 4. Observed: `4, 6, 8, 10, 12, 16, 20, 24, 28, 32, 40`.

* Screen horizontal padding: **20px** (`px-5`); form-heavy screens use **24px** (`px-6`).
* Card padding: **16px** default, 12px compact, 20px for gradient/feature cards.
* List-row padding: **12px vertical / 16px horizontal**.
* Vertical rhythm between sections: 20–24px. Between stacked cards: 10–12px.
* Bottom padding to clear the nav bar: **96px**; to clear a fixed CTA bar: **112px**.
* App-bar padding: `8px top / 20px sides / 12px bottom`.

### Shared component patterns

**Primary button (amber)** — the default CTA
`bg #E2962F` · `text #1E2A2E` · Inter 14px/600 · radius full · padding **12px 20px** · full width · `active: scale(0.98)`.

**Primary button (pine)** — used for admin/clinic/report submissions
`bg #2F5D50` · `text #FFFFFF` · otherwise identical.

**Secondary / outline button**
transparent · `border 1px #2F5D50` · `text #2F5D50` · 14px/600 · radius full · padding 12px 20px.

**Compact button** — padding `8px 20px`, font 12px/600 (used in pairs inside cards).

**Tonal button** — `bg #D1E8DF` · `text #2F5D50` · radius full · padding 8px 0 · 12px/600 · full width.

**Danger button** — `bg #FCE8E8` · `text #C84B4B` · 14px/600 · radius full.

**Card** — `bg #FFFFFF` · radius **18px** · `border 1px rgba(0,0,0,0.06)` · padding 16px. Grouped-list variant drops padding and uses `divide-y` hairlines of the same color.

**Chip (selectable / filter)** — radius full · padding **6px 12px** · 12px.
*Selected:* `bg #2F5D50`, `text #FFFFFF`, `border 1px #2F5D50`.
*Unselected:* `bg #FFFFFF`, `text #4A5854`, `border 1px rgba(0,0,0,0.1)`.
A `text-[11px] font-semibold` variant (no border change) is used on Care packages and Find-a-clinic.

**Status badge** — radius full · padding **2px 8px** · IBM Plex Mono 10px · uppercase · ls 0.5px.

| Variant | Fill | Text | Example labels |
|---|---|---|---|
| success | `#D1E8DF` | `#2F5D50` | CONFIRMED, DONE, IN STOCK, JOINED, APPROVED, SHAREABLE, AVAILABLE TODAY, PRIMARY |
| warning | `#FBEFD9` | `#8A5A14` | NEW, PENDING, TOMORROW, UNDER REVIEW, INVITED |
| neutral | `#EEF1ED` | `#4A5854` | INFO, REPORT, SENT, PRIVATE, category tags |
| danger | `#FCE8E8` | `#C84B4B` | OUT, CANCELLED |

**Segmented tab bar** — track `bg #EEF1ED`, radius full, padding 4px, margin-x 20px.
Each tab `flex-1`, radius full, `py 8px`, 11–12px/600.
Active: `bg #FFFFFF`, `text #2F5D50`, soft shadow. Inactive: `text #4A5854`.

**Bottom navigation** — absolutely positioned, `margin 0 12px 12px`.
Bar: `bg #FFFFFF` · radius 22px · `border 1px rgba(0,0,0,0.06)` · padding `10px 20px` · shadow · `align-items: flex-end`.
Items: width 56px, column, gap 4px. Icon 18px, label 10px.
Active `#2F5D50` (label weight 600) · inactive `#8FA8A0`.
**Center FAB:** 56 × 56 circle, `bg #2F5D50`, white `+` at 24px, absolutely centered and raised 20px above the bar; the 3rd nav slot is an empty 56px spacer.

**List tile** — full-width button, padding `12px 16px`, gap 12px.
Leading: 36 × 36 circle, `bg #D1E8DF`, emoji/glyph `#2F5D50`.
Title 14px `#1E2A2E`; optional subtitle 11px `#8FA8A0`; trailing `›` in `#8FA8A0`.
Tiles stack inside one card with `divide-y` hairlines.

**Input field** — `bg #FFFFFF` · `border 1px rgba(0,0,0,0.1)` · radius **full** · padding `12px 16px` · Inter 14px `#1E2A2E`. Placeholder color `#8FA8A0`.
**Textarea** — same, but radius **18px**.
**Search field** — row (`gap 8px`) containing a `⌕` glyph + borderless input; container `bg #FFFFFF`, radius full, `border 1px rgba(0,0,0,0.08)`, padding `10px 16px`.
**Select** — same shell as input, radius full.
**Checkbox** — 16px native, `accent-color: #2F5D50`.

**Avatar** — circle, initials, weight 600, `color #2F5D50`.
Fill cycles `#D1E8DF` → `#FBEFD9` → `#EEF1ED` per index.
**Font size = 0.38 × diameter.** Observed diameters: 40 (list row), 42 (compact row), 48, 56, 64 (account header), 80 (therapist profile).
Verified overlay: 28px circle `bg #2F5D50`, white `✓` 12px, `border 2px #FFFFFF`, anchored bottom-right (-4, -4).

**Upload dropzone** — `bg #D1E8DF` · dashed `1px rgba(47,93,80,0.4)` (2px on the therapist upload screen) · radius 18px · padding `12px 16px` · text `#2F5D50` 14px. Left label `＋ Tap to upload`, right hint 10px `#8FA8A0`.

**Toggle** — track 44 × 24, radius full, padding 3px. Off `rgba(0,0,0,0.15)`; on **`#E2962F`**. Knob 18–20px white circle.

**Radio row** — full-width card-button, radius 18px, padding `12px 16px`. Selected gets `border 1px #2F5D50` + a 20px ring with a 10px `#2F5D50` dot; unselected `border 1px rgba(0,0,0,0.08)` + empty ring `rgba(0,0,0,0.2)`.

**Bottom sheet** — overlay `rgba(0,0,0,0.35)`, aligned bottom. Sheet `bg #FFFFFF`, radius `22px 22px 0 0`, padding 20px, grab handle 40 × 4 radius full `rgba(0,0,0,0.15)`. Body scrolls at `max-height 60vh`.

**App bar** — `flex, space-between`, padding `8px 20px 12px`.
Back button: 36 × 36 circle, `bg #EEF1ED`, `←` in `#1E2A2E`.
Title: Fraunces 18px `#1E2A2E`, centered.
Trailing: a `min-width: 36px` slot (empty, or a text/pill action).

**Fixed CTA bar** — `position: fixed`, bottom, width 390, `bg #FFFFFF`, `border-top 1px rgba(0,0,0,0.06)`, padding `12px 20px`, holding one full-width primary button.

### Bottom navigation — exact tabs

**PATIENT** (5 slots, center is the FAB)

| # | Icon | Label |
|---|---|---|
| 1 | `⌂` | Home |
| 2 | `◷` | Sessions |
| — | `+` | (FAB — opens Find therapist) |
| 3 | `🔔` | Notifications |
| 4 | `☻` | Account |

**THERAPIST**

| # | Icon | Label |
|---|---|---|
| 1 | `⌂` | Home |
| 2 | `◷` | Schedule |
| — | `+` | (FAB) |
| 3 | `☰` | Availability |
| 4 | `☻` | Account |

---

# SHARED

## 1. Splash (SHARED)
**Purpose:** First-run brand screen with the two entry paths.
**App bar / header:** none. Full-bleed pine screen.
**Body, in vertical order:**
1. Full-screen container — `bg #2F5D50`, text `#FFFFFF`, padding `64px 28px 40px`, column, `justify-between`.
2. Logo mark — 80 × 80, radius 22px, `bg rgba(255,255,255,0.10)`, centered; inside letter `S` in Fraunces 36px, color **`#E2962F`**.
3. Wordmark — `Sahayatri Physio`, Fraunces 36px, white, 24px below the mark.
4. Subtitle — `Professional physiotherapy, delivered to your home — across Nepal.` 14px, `rgba(255,255,255,0.78)`, max-width 280px, centered.
5. Stat chips row (gap 8px, wrap, centered, 32px above): `180+ Therapists` · `4.8★ Rated` · `6 Cities` — each radius full, `bg rgba(255,255,255,0.12)`, 12px, padding `4px 12px`.
6. Button stack (gap 12px, full width).
**Bottom nav / footer:** none.
**Primary actions:**
- `Get started →` — amber primary → Patient sign up.
- `I'm a physiotherapist` — outline, `border 1px rgba(255,255,255,0.4)`, white text → Therapist application.
- `Already have an account? Log in` — 12px `rgba(255,255,255,0.75)`, the word **Log in** underlined → Login.
**Empty/loading/error states shown:** none.
**Notes:** Only screen using the inverted (white-on-pine) palette end-to-end.

## 2. Login (SHARED)
**Purpose:** Email/password sign-in with a role switch.
**App bar / header:** none — padding `16px 24px 40px`.
**Body, in vertical order:**
1. Eyebrow — `WELCOME BACK`.
2. H1 — `Log in to Sahayatri` (Fraunces 28px).
3. Sub — `Pick your role to continue.` (14px `#4A5854`).
4. **Segmented role switch** (24px below) — 2 tabs, `capitalize`: **`patient`** (active) · `therapist`.
5. Field `EMAIL` — input, placeholder `you@example.com`.
6. Field `PASSWORD` — input, placeholder `••••••••`.
7. Right-aligned link — `Forgot password?` 12px/600 `#2F5D50`.
8. `Log in` — amber primary, full width.
9. Divider row — hairline / `OR CONTINUE WITH` (11px `#8FA8A0`) / hairline, `my 24px`, gap 12px.
10. `Continue with Google` — outline button, `border 1px rgba(0,0,0,0.12)`, leading serif `G` 18px in **`#4285F4`**.
11. Footer — `Don't have an account?` 12px `#4A5854` + `Sign up free` (600, underlined, `#2F5D50`).
**Bottom nav / footer:** none.
**Primary actions:** `Log in` → role home; `Sign up free` → sign-up.
**Notes:** Role tabs are lowercase in source and rendered via `text-transform: capitalize`.

## 3. Sign up · Patient (SHARED)
**Purpose:** Patient registration form.
**App bar / header:** back `←`, title `Patient sign up`, no trailing action.
**Body, in vertical order:** (form column, padding 24px, gap 16px)
1. Eyebrow `CREATE YOUR ACCOUNT` + H1 `Tell us about you`.
2. `FULL NAME` — placeholder `Aakar Sharma`.
3. `PHONE (+977)` — placeholder `+977 98XXXXXXXX`.
4. `EMAIL` — placeholder `you@example.com`.
5. Two-column row (gap 12px): `PASSWORD` / `CONFIRM` — both placeholder `••••••••`.
6. Two-column row: `DATE OF BIRTH` placeholder `DD / MM / YYYY` · `GENDER (OPTIONAL)` placeholder `Female / Male / Other`.
7. `CITY / AREA` — placeholder `Lalitpur, Kupondole`.
8. `PRIMARY HEALTH CONCERN (OPTIONAL)` — chip group, wrap, gap 8px, in order:
   **Back pain** (selected) · Post-surgery · Sports injury · Neuro · Pediatric · Geriatric · Other.
9. Consent row — 16px checkbox (`accent #2F5D50`) + 12px text `I agree to the Terms & Privacy Policy.` (both links underlined `#2F5D50`).
10. `Create patient account` — amber primary, full width.
**Bottom nav / footer:** none.
**Primary actions:** `Create patient account` → Patient Home.
**Notes:** Single chip selection; chips are the standard selectable-chip pattern.

## 4. Sign up · Therapist (SHARED)
**Purpose:** Therapist application — the longest form in the app.
**App bar / header:** back `←`, title `Therapist application`.
**Body, in vertical order:**
1. Eyebrow `BECOME A SAHAYATRI PARTNER`; H1 `Apply to join`; sub `Submit your credentials — we verify every therapist before activation.`
2. `FULL NAME` — placeholder `Dr. Anisha Shrestha`.
3. Two-col: `PHONE (+977)` (`+977 98XXXXXXXX`) · `EMAIL` (`you@example.com`).
4. Two-col: `PASSWORD` · `CONFIRM` (both `••••••••`).
5. `NMC LICENSE NUMBER` — placeholder `NMC-PT-XXXXX`.
6. `UPLOAD LICENSE DOCUMENT` — dropzone: `＋ Tap to upload` / hint `JPG / PDF · max 5MB`.
7. Two-col: `YEARS OF EXPERIENCE` (`6`) · `RATE / SESSION (RS)` (`1500`).
8. `SPECIALIZATIONS` chips: **Sports & post-surgery** (selected) · Neuro · Pediatric · Geriatric · Musculoskeletal · Post-op.
9. `QUALIFICATIONS / DEGREE` — placeholder `BPT, IOM (2018)`.
10. `UPLOAD CERTIFICATE (OPTIONAL)` — dropzone, hint `JPG / PDF`.
11. `SERVICE CITIES` chips: Kathmandu · **Lalitpur** (selected) · Bhaktapur · Pokhara · Chitwan · Biratnagar.
12. `PROFILE PHOTO` — dropzone, hint `Square, JPG / PNG`.
13. `SHORT BIO` — textarea, placeholder `Tell patients about your approach...`.
14. `AVAILABLE DAYS` chips: **Sun, Mon, Tue, Wed, Thu** selected · Fri, Sat unselected.
15. `TIME BLOCKS` chips: **Morning** (selected) · Afternoon · **Evening** (selected).
16. `PAYOUT METHOD` chips: **eSewa** (selected) · Khalti · Bank.
17. `PAYOUT ID / ACCOUNT` — placeholder `98XXXXXXXX or A/C number`.
18. Consent checkbox — `I confirm my credentials are accurate and agree to the Terms and Code of Conduct.`
19. `Submit application` — amber primary.
**Bottom nav / footer:** none.
**Primary actions:** `Submit application` → Verification pending.
**Notes:** Multi-select chip groups (days, time blocks, cities, specializations); single-select for payout method.

## 5. Verification pending (SHARED)
**Purpose:** Post-application holding screen.
**App bar / header:** none — centered column, padding `64px 32px 40px`, `text-align: center`.
**Body, in vertical order:**
1. Icon circle 80 × 80, `bg #FBEFD9`, emoji `⏳` at 30px.
2. Badge — `UNDER REVIEW` (warning variant).
3. H1 — `Application submitted` (Fraunces 30px).
4. Body — `Our team reviews every therapist within 24–48 hours. We'll notify you by SMS and email once your account is verified.` (14px, max-width 300px).
5. Two info cards (max-width 280px, gap 12px, left-aligned rows, 12px):
   - `Application ref` (label `#8FA8A0`) → **`SAH-APP-48201`** (mono, `#1E2A2E`).
   - `Status` → badge `PENDING` (warning).
6. `Preview my dashboard` — amber primary (max-width 280px).
7. Footnote — `You'll get full booking access once verified.` 11px `#8FA8A0`.
**Bottom nav / footer:** none.
**Empty/loading/error states shown:** this *is* the pending state.

## 6. Notifications (SHARED)
**Purpose:** Notification inbox.
**App bar / header:** back `←`, title `Notifications`, trailing text button **`Mark all read`** (11px/600 `#2F5D50`).
**Body, in vertical order:**
1. Eyebrow `STAY UP TO DATE` + section title `All notifications` (Fraunces 18px).
2. Notification list, gap 10px. Each row is a card (radius 18px, padding 12px, gap 12px, `align-items: flex-start`):
   leading 40px circle (`bg #FFFFFF` when unread, transparent when read) with an emoji at 18px `#2F5D50` · title 14px/600 · optional 6px amber unread dot (`#E2962F`) · body 12px `#4A5854` · timestamp mono 10px `#8FA8A0` · trailing status badge.
   **Unread rows use `bg #D1E8DF`; read rows use `bg #FFFFFF`.**

| # | Icon | Title | Body | Time | Badge | Read |
|---|---|---|---|---|---|---|
| 1 | ✓ | Booking confirmed | Anisha Shrestha will visit tomorrow at 9:00. | 2h ago | `DONE` (text-only, `#2F5D50`) | unread |
| 2 | 🔔 | Session reminder | Your home visit starts in 1 hour. | 5h ago | `NEW` (warning) | unread |
| 3 | 💬 | New message | Anisha shared post-session exercises. | Yesterday | `INFO` (neutral) | read |
| 4 | ★ | Rate your last session | How was your session with Anisha? | 2 days ago | `INFO` | read |
| 5 | 💳 | Payment received | Khalti payment of Rs 1,500 confirmed. | 3 days ago | `DONE` (success) | read |

**Bottom nav / footer:** Patient bottom nav. **Prototype quirk:** *Home* renders as the active tab here, not *Notifications*. In Flutter, mark **Notifications** active.
**Primary actions:** `Mark all read`; tapping a row → the related detail.

**As built (branch `feat/notifications-feed`) — three deliberate departures:**

1. **Rows 2 and 3 of the sample table do not exist and are not faked.** The API's
   registry (`docs/notification_types.md` on `pv-core-api`) has no *Session
   reminder* — it is time-triggered and there is no scheduler — and no *New
   message*, because there is no messaging feature at all: no model, no
   endpoints. The closest real event to "Anisha shared post-session exercises"
   is `REPORT_UPLOADED`. Neither key has an icon in the client, because an icon
   is a promise that the row can arrive.
2. **`Mark all read` moved from the app bar to the right of the section
   title.** `TabShell` now mounts one `AppHeader` above every route in both
   shells, so this screen has no app bar of its own to hang it from. The
   styling is unchanged (11px/600 `#2F5D50`) and it is rendered only when
   something is unread. The back arrow and the centred `Notifications` title
   are gone for the same reason: they were a second header under the real one,
   on a tab root with nothing to go back to.
3. **The badge follows one rule over all 22 types, which reclassifies row 4.**
   `NEW` = waiting on the reader, `DONE` = settled (including rejections and
   denials — the tint carries the valence, not the pill), `INFO` = neither. A
   rating prompt is the plainest *your turn* row in the registry, so it reads
   `NEW`, not `INFO`. The sample rows above use the badge decoratively — the
   same `DONE` appears in two colours — and a badge whose meaning cannot be
   stated in a sentence is worth less than none. The full mapping is in
   `lib/features/notifications/presentation/widgets/notification_visuals.dart`.

## 7. Edit profile (SHARED)
**Purpose:** Edit patient profile fields.
**App bar / header:** back `←`, title `Edit profile`.
**Body, in vertical order:** (padding `8px 20px 112px`, gap 20px)
1. Avatar row (gap 16px) — 64px avatar `AS` (`bg #D1E8DF`, `fg #2F5D50`, 24.3px) + outline pill button `Change photo` (12px/600, padding `6px 12px`).
2. Section eyebrow `PERSONAL` then fields (gap 12px):
   - `FULL NAME` → value **Aakar Sharma**
   - `EMAIL` (type email) → **aakar@example.com**
   - `PHONE` (type tel) → **+977 98XXXXXX21**
   - `DATE OF BIRTH` (type date) → **1992-06-14**
   - `GENDER` chip group: Female · **Male** (selected) · Other
3. Section eyebrow `CARE`:
   - `HOME ADDRESS` → **Jhamsikhel, Lalitpur**
   - `PRIMARY CONCERN` → **Post-ACL rehab**, placeholder `e.g. Lower back pain`
4. Action row (gap 8px, `padding-top 8px`): `Cancel` (outline) · `Save changes` (amber primary) — equal width.
**Bottom nav / footer:** none.

---

# PATIENT

## 8. Home (PATIENT)
**Purpose:** Patient landing — hero CTA, next session, therapist shortlist, entry points.
**App bar / header:** none. First element is the hero.
**Body, in vertical order:**
1. **Hero card** — `margin 16px 20px 0`, radius 22px, padding `24px 20px`, gradient `linear-gradient(150deg,#2F5D50,#3F7965 90%)`, white text:
   - H1 `Find Physiotherapist` (Fraunces 26px)
   - Sub `Find the right physiotherapist for your needs.` (12px, `rgba(255,255,255,0.8)`)
   - Button `Find Physiotherapist` — amber pill, 13px/600, padding `10px 16px`, `margin-top 16px`.
2. Section eyebrow `NEXT SESSION` → card:
   - 40px avatar `AS` · name **Anisha Shrestha** (600) · `Home visit · Post-ACL rehab` (11px `#4A5854`) · `Tomorrow · 9:00 AM` (11px `#8FA8A0`) · badge `CONFIRMED` (success)
   - full-width tonal button `View details` (`bg #D1E8DF`, `#2F5D50`, 12px/600).
3. Section header row `FEW THERAPISTS` + right pill button `View All →` (`bg #D1E8DF`, `#2F5D50`, 11px/600, `border 1px rgba(47,93,80,0.18)`).
   Therapist rows (card buttons, gap 10px, padding 12px): 42px avatar · name 13px/600 · specialty 11px `#4A5854` · city 11px `#8FA8A0` · trailing `★ 4.9` (star `#E2962F`, number 11px `#4A5854`).
   - **Anisha Shrestha** — Sports & post-surgery — Lalitpur — ★ 4.9 — avatar `#D1E8DF`
   - **Bibek Rai** — Neuro rehab — Kathmandu — ★ 4.8 — avatar `#FBEFD9`
   - **Sunita Gurung** — Pediatric — Bhaktapur — ★ 4.9 — avatar `#D1E8DF`
4. Section eyebrow `WHAT ARE YOU LOOKING FOR?` → two navigation cards:
   - `🩺` (40px circle `bg #EEF1ED`) · **Find a Physiotherapist** (13px/600 `#2F5D50`) · `Book a verified therapist for a home visit.` (11px) · trailing 28px outline circle `→`
   - `🏥` · **Find a Clinic** · `Book a visit at a clinic near you.` · `→`
**Bottom nav / footer:** Patient nav — **Home** active.
**Primary actions:** `Find Physiotherapist` / `Find a Physiotherapist` → Find therapist · `Find a Clinic` → Find a clinic · `View details` → session detail · `View All →` → Find therapist.

## 9. Find therapist (PATIENT)
**Purpose:** Search + filter + book therapists.
**App bar / header:** none — inline header block, padding `8px 20px`.
**Body, in vertical order:**
1. Eyebrow `FIND A THERAPIST` + H1 `Who can help today?` (28px).
2. Search field — placeholder **`Search by name or condition`**.
3. Horizontal filter chips (scrollable, gap 8px, padding `12px 20px`): **All** (selected) · Sports · Neuro · Pediatric · Geriatric · Post-op.
4. Therapist result cards (gap 10px, padding 12px, radius 18px):
   - Top row: 48px avatar · name (600) + `✓` in `#2F5D50` · `<specialty> · <city>` 11px · meta row `★ 4.9  (182 sessions)` + availability badge (success).
   - Bottom row: price `Rs 1,500` (600) + `/ session` (11px `#8FA8A0`), right-aligned `Book now` amber primary.

| Name | Specialty · City | Rating | Sessions | Availability | Price | Avatar fill |
|---|---|---|---|---|---|---|
| Anisha Shrestha | Sports & post-surgery · Lalitpur | 4.9 | 182 | `AVAILABLE TODAY` | Rs 1,500 | `#D1E8DF` |
| Bibek Rai | Neuro rehab · Kathmandu | 4.8 | 144 | `TOMORROW` | Rs 1,800 | `#FBEFD9` |
| Sunita Gurung | Pediatric · Bhaktapur | 4.9 | 98 | `AVAILABLE TODAY` | Rs 1,600 | `#D1E8DF` |
| Rajan Thapa | Geriatric · Pokhara | 4.7 | 211 | `THIS WEEK` | Rs 1,400 | `#EEF1ED` |

**Bottom nav / footer:** Patient nav, **no tab active** (reached via the FAB).
**Primary actions:** `Book now` → Booking · tapping the row → Therapist profile.

## 10. Therapist profile (PATIENT)
**Purpose:** Therapist detail + slot picking.
**App bar / header:** 128px gradient cover `linear-gradient(135deg,#2F5D50,#3F7965)` with a floating back button (36px circle, `bg rgba(255,255,255,0.2)`, white `←`) at `left 20px / top 12px`. No title.
**Body, in vertical order:**
1. Overlap row pulled up 40px: 80px avatar `AS` with 28px verified badge (`bg #2F5D50`, white `✓`, `border 2px #FFFFFF`); right side `Rs 1,500` (Fraunces 24px) over mono 10px `per session`.
2. Name block — `Anisha Shrestha` (Fraunces 24px) · `Sports & post-surgery · Lalitpur` (14px `#4A5854`).
3. Stat card — 3 columns, `divide-x`, padding 12px: **182+** / `SESSIONS` · **6 yrs** / `EXPERIENCE` · **★ 4.9** / `RATING` (values Fraunces 18px, labels mono 10px uppercase).
4. Eyebrow `ABOUT` + paragraph: `BPT, IOM (2018). 182+ home sessions across Lalitpur. Specialises in post-operative recovery and sports rehabilitation, with a manual-therapy and exercise-based approach.` (14px, relaxed leading).
5. Row: eyebrow `AVAILABLE SLOTS · TOMORROW` + right text button `Change date →` (12px/600 `#2F5D50`).
6. Slot grid — **4 columns, gap 8px**, buttons radius 14px, `py 8px`, 14px:
   `08:00, 09:00, 10:00, 11:00, 13:00, 14:00, 15:00, 16:00, 17:00, 18:00, 19:00, 20:00`
   - available: `bg #FFFFFF`, `text #1E2A2E`, `border 1px rgba(0,0,0,0.08)`
   - **selected (09:00): `bg #2F5D50`, white, `border 1px #2F5D50`**
   - **disabled (10:00, 14:00, 18:00): `bg #EEF1ED`, `text #8FA8A0`**
**Bottom nav / footer:** fixed CTA bar — `Continue to booking →` amber primary.
**Primary actions:** `Continue to booking →` → Booking.

## 11. Booking (PATIENT)
**Purpose:** Confirm session details, address, payment.
**App bar / header:** back `←`, title `Confirm booking`.
**Body, in vertical order:** (gap 16px)
1. **Session summary card** — eyebrow `SESSION SUMMARY`; therapist row (40px avatar `AS`, **Anisha Shrestha**, `Sports & post-surgery` 12px); then a 3-up grid of `bg #EEF1ED` radius-14 tiles, padding 8px, centered:
   `Tue, 7 Jul` / `Date` · `09:00` / `Time` · `60 min` / `Duration` (values Fraunces 14px, labels mono 10px).
2. `HOME ADDRESS` — textarea prefilled `Kupondole Heights, Lalitpur — 4th floor, blue gate`.
3. **Toggle card** — title `Booking for a loved one from abroad` (12px/600), sub `We'll visit them in Nepal and update you after every session.` (11px), trailing toggle (**off**).
4. Eyebrow `PAYMENT METHOD` → 3 radio rows (gap 8px):
   - `💚` **eSewa** — **selected**
   - `💜` **Khalti**
   - `💵` **Cash on visit**
5. **Fee card** — row `Session fee` / `Rs 1,500` (600); note `No hidden charges. Includes home visit.` (11px `#8FA8A0`).
**Bottom nav / footer:** fixed CTA bar — **`Confirm & pay Rs 1,500`** amber primary.
**Primary actions:** confirm → Booking success.

## 12. Booking success (PATIENT)
**Purpose:** Booking confirmation receipt.
**App bar / header:** none — column, padding `40px 24px`.
**Body, in vertical order:**
1. 80px circle `bg #D1E8DF`, `✓` 30px `#2F5D50`.
2. H1 `Booking confirmed!` (Fraunces 28px).
3. Body `Anisha Shrestha will visit you tomorrow at 09:00.` (14px).
4. Mono line `BOOKING REF · ` + **`SAH-2026-48201`** (`#1E2A2E`).
5. Detail card (`divide-y`, rows padding `12px 16px`, label mono 10px uppercase left / value 14px right-aligned):
   - `ADDRESS` → `Kupondole Heights, Lalitpur`
   - `PAYMENT` → `eSewa · Rs 1,500`
   - `CONFIRMATION` → `SMS sent to +977 98XXXXXXXX`
6. Button stack pinned to bottom (gap 8px): `View my sessions` (amber) · `Back to home` (outline).
**Bottom nav / footer:** none.

## 13. My sessions (PATIENT)
**Purpose:** Booking list across three states.
**App bar / header:** none — eyebrow `MY SESSIONS` + H1 `Your bookings` (28px), padding `8px 20px`.
**Body, in vertical order:**
1. **Segmented tabs** (order): **`Upcoming`** (active) · `Past` · `Cancelled`.
2. Session cards (gap 10px, padding 16px): 40px avatar · name (600) · specialty 11px · trailing status badge; meta row 11px `#4A5854` with date-time left and `· Rs 1,500` right; action row (gap 8px, compact buttons).

**Upcoming**
| Avatar | Name | Specialty | Badge | When | Price | Actions |
|---|---|---|---|---|---|---|
| AS `#D1E8DF` | Anisha Shrestha | Sports & post-surgery | `TOMORROW` (warning) | Tue, 7 Jul · 09:00 | Rs 1,500 | `Reschedule` (outline) · `Cancel` (danger) |
| BR `#FBEFD9` | Bibek Rai | Neuro rehab | `CONFIRMED` (success) | Fri, 10 Jul · 16:00 | Rs 1,800 | `Reschedule` · `Cancel` |

**Past** — Anisha Shrestha · Sports & post-surgery · `COMPLETED` · Fri, 3 Jul · 09:00 · Rs 1,500; and Anisha Shrestha · Tue, 30 Jun · 09:00 · Rs 1,500.
**Cancelled** — Sunita Gurung · Pediatric · `CANCELLED` · Mon, 23 Jun · 11:00 · Rs 1,600.

**Bottom nav / footer:** Patient nav — **Sessions** active.
**Notes:** `Cancel` uses the danger button (`bg #FCE8E8`, `text #C84B4B`) at compact size.

## 14. Shop (PATIENT)
**Purpose:** Rent/buy equipment, medicines and nutrition.
**App bar / header:** inline row — left: eyebrow `SHOP` + H1 `Equipment & care` (28px); right: 44px circle `bg #EEF1ED` with `🛒` and an **amber count badge** (`bg #E2962F`, white, 10px/700, radius full, min-width 20px, offset -4,-4) reading **`3`**.
**Body, in vertical order:**
1. Category chips (scrollable): **Equipment** (selected) · Medicines · Nutrition.
2. **Product grid — 2 columns, gap 12px.** Card: padding 12px, radius 18px, column.
   - image well: height 96px, `bg #EEF1ED`, radius 14px, emoji 36px centered
   - title 16px/600, subtitle 11px `#4A5854`
   - price row: `Rs 250` (14px/600) + mono 10px `/day`, right badge
   - full-width amber pill `+ Add to cart` (12px/600, `py 8px`); out-of-stock variant reads **`Out of stock`** and is `disabled:opacity-50`.

**Equipment:** `⚡` TENS unit — Pain relief electrotherapy — Rs 250 /day — `IN STOCK` · `🦯` Walking frame — Foldable aluminium — Rs 120 /day — `IN STOCK` · `🦵` Knee CPM machine — Continuous passive motion — Rs 600 /day — **`OUT`** (danger badge) — button `Out of stock`.
**Medicines:** `💊` Pain relief gel — Diclofenac 30g — Rs 320 — `IN STOCK` · `🩹` Kinesio tape — 5cm × 5m roll — Rs 450 — `IN STOCK`.
**Nutrition:** `🥛` Whey protein — Recovery support, 1kg — Rs 3,200 — `IN STOCK`.

**Bottom nav / footer:** Patient nav, no tab active.
**Primary actions:** `+ Add to cart`; cart icon → Cart.

## 15. Cart (PATIENT)
**Purpose:** Review rental cart and totals.
**App bar / header:** back `←`, title `Your cart`, trailing text `2 items` (12px `#8FA8A0`).
**Body, in vertical order:** (gap 12px)
1. Line-item cards (padding 12px): 64px image well (`bg #EEF1ED`, radius 14px, emoji 24px) · title (600) + subtitle 11px · right column price (600) + **quantity stepper** (inline pill, `border 1px rgba(0,0,0,0.1)`, radius full, padding `4px 8px`, gap 8px: `−` / mono 12px count / `+`).
   - `⚡` **TENS unit** — Pain relief electrotherapy — **Rs 250** — qty **1** — plus a duration `<select>`: `1 day` · `3 days` · `7 days` · `14 days` · `1 month` (radius full, 11px, padding `4px 8px`).
   - `🩹` **Kinesio tape** — 5cm × 5m roll — **Rs 900** — qty **2** — no select.
2. **Totals card** (14px, rows `space-between`, `#4A5854`):
   `Subtotal` `Rs 1,150` · `Delivery` `Rs 100` · `Refundable deposit` `Rs 500` · hairline · **`Total` `Rs 1,750`** (weight 700, `#1E2A2E`).
**Bottom nav / footer:** fixed CTA bar — `Proceed to checkout →` amber primary.
**Primary actions:** checkout → Order success.

## 16. Order success (PATIENT)
**Purpose:** Equipment order confirmation.
**App bar / header:** none — centered column, padding `0 32px 40px`.
**Body, in vertical order:**
1. 80px circle `bg #D1E8DF` with `✓` 30px `#2F5D50`.
2. H1 `Order placed` (Fraunces 28px).
3. Body `Your equipment will be delivered within 24 hours.`
4. Mono `ORDER REF · ` + **`SAH-EQ-90213`**.
5. Buttons (max-width 280px, gap 8px): `Back to home` (amber) · `Continue shopping` (outline).
**Bottom nav / footer:** none.

## 17. Account (PATIENT)
**Purpose:** Patient profile hub.
**App bar / header:** **green profile header** — `bg #2F5D50`, white text, radius `0 0 28px 28px`, padding `12px 20px 32px`:
- 64px avatar `AS` (`bg rgba(255,255,255,0.18)`, text `#2F5D50`)
- `Aakar Sharma` (Fraunces 24px) · `aakar@example.com` (12px `rgba(255,255,255,0.75)`) · mono 10px uppercase `PATIENT · MEMBER SINCE APR 2025`
- pill button `Edit profile` (`bg rgba(255,255,255,0.15)`, 12px/600, padding `6px 16px`)
**Body, in vertical order:** three grouped-list cards, each preceded by an eyebrow.

`HEALTH`
| Icon | Title | Subtitle |
|---|---|---|
| ◷ | My sessions | 2 upcoming · 8 completed |
| 📄 | Reports & files | 3 from therapist |
| 📈 | Recovery progress | 60% · Post-ACL rehab |

`ACCOUNT`
| Icon | Title | Subtitle |
|---|---|---|
| 📍 | Saved addresses | 2 addresses |
| 💳 | Payment methods | eSewa, Khalti linked |
| 🔔 | Notifications | — |
| 🎁 | Refer & earn | Rs 500 per referral |

`SUPPORT`
| Icon | Title | Subtitle |
|---|---|---|
| ❔ | Help & FAQ | — |
| ✉ | Contact support | — |
| ⚠ | Report a therapist | Send feedback to admin |

Then `Log out` — danger button, full width, padding `12px 20px`.
**Bottom nav / footer:** Patient nav — **Account** active.

## 18. Reports & files (PATIENT)
**Purpose:** Documents shared by therapists.
**App bar / header:** back `←`, title `Reports & files`.
**Body, in vertical order:**
1. Eyebrow `YOUR HEALTH RECORDS` + H1 `Files from your therapists` (28px).
2. Grouped card (`divide-y`), rows padding `12px 16px`, gap 12px: 40px circle `bg #D1E8DF` with `📄` 18px · filename 14px/600 · `<author> · <when>` 11px `#4A5854` · trailing badge.
   - `Session-notes-Jul-5.pdf` — Dr. Anisha Shrestha · Today — `NEW` (warning)
   - `Home-exercise-plan.pdf` — Dr. Anisha Shrestha · 3 days ago — `EXERCISE` (success)
   - `Initial-assessment.pdf` — Dr. Bibek Rai · 2 weeks ago — `REPORT` (neutral)
3. `Upload my own report` — outline button, full width.
**Bottom nav / footer:** none (bottom padding 112px).

## 19. Recovery progress (PATIENT)
**Purpose:** Rehab progress + milestone timeline.
**App bar / header:** back `←`, title `Recovery progress`.
**Body, in vertical order:**
1. Eyebrow `POST-ACL REHAB` + H1 `You're 60% recovered` (28px).
2. **Progress card:** row `Overall progress` (12px `#4A5854`) / `60%` (600 `#2F5D50`); bar — track height **12px**, radius full, `bg #EEF1ED`, fill `linear-gradient(90deg,#2F5D50,#E2962F)`; then a 3-up stat grid:
   **8 / 14** `SESSIONS` · **4 wks** `STREAK` · **↓ 45%** `PAIN` (values Fraunces 18px).
3. Eyebrow `MILESTONES` → card containing an `<ol>` (gap 12px). Each item: 24px circle (24px, 11px/700) + title 14px/600 + date 11px `#8FA8A0`.
   - ✓ `Initial assessment` — Apr 10 — circle `bg #2F5D50`, white
   - ✓ `Pain-free range of motion` — May 6 — done
   - ✓ `Weight-bearing exercises` — Jun 2 — done
   - `4` `Return to jogging` — Jul 20 (target) — circle `bg #EEF1ED`, text `#8FA8A0`
   - `5` `Full recovery review` — Aug 15 (target) — pending
**Bottom nav / footer:** none.

## 20. Saved addresses (PATIENT)
**Purpose:** Manage visit addresses.
**App bar / header:** back `←`, title `Saved addresses`.
**Body, in vertical order:**
1. Address cards (padding 16px, gap 12px):
   - **Home** (14px/600) + badge `PRIMARY` (success) · `Kupondole Heights, Lalitpur — 4th floor, blue gate` (12px `#4A5854`) · action row: `Remove` (outline pill, 11px/600, `text #C84B4B`, `border 1px rgba(0,0,0,0.1)`, padding `4px 12px`).
   - **Parents** · `Baneshwor, Kathmandu — house #82` · actions `Set primary` (outline pill, `#2F5D50` text + border) · `Remove`.
2. `+ Add new address` — outline button, full width.
**Bottom nav / footer:** none.
**Notes:** The primary address has no `Set primary` button.

## 21. Payment methods (PATIENT)
**Purpose:** Manage wallets.
**App bar / header:** back `←`, title `Payment methods`.
**Body, in vertical order:**
1. Method cards (padding 16px, row, gap 12px): 24px emoji · name 14px/600 (+ `PRIMARY` badge) · masked number 11px `#8FA8A0` · right column of text buttons (10px/600, gap 4px).
   - `💚` **eSewa** — `PRIMARY` — `98XX••••21` — actions: `Remove` (`#C84B4B`)
   - `💜` **Khalti** — `98XX••••07` — actions: `Make primary` (`#2F5D50`) · `Remove` (`#C84B4B`)
2. `+ Add payment method` — outline button, full width.
**Bottom nav / footer:** none.

## 22. Report therapist (PATIENT)
**Purpose:** File a complaint to admin.
**App bar / header:** back `←`, title `Report therapist`.
**Body, in vertical order:**
1. Eyebrow `FEEDBACK TO ADMIN` + H1 `Tell us what happened` (28px) + sub `Reports are confidential and reviewed by the Sahayatri trust team within 24 hours.`
2. Form card (padding 16px, gap 12px):
   - `THERAPIST NAME` — placeholder `e.g. Dr. Anisha Shrestha`
   - `ISSUE CATEGORY` chips: **Rude behaviour** (selected) · Unprofessional conduct · Late / no-show · Safety concern · Other
   - `RATE YOUR EXPERIENCE` — 5 star buttons, 24px; filled `#E2962F`, empty `rgba(0,0,0,0.15)` — **2 of 5 filled**
   - `WHAT HAPPENED?` — textarea, placeholder `Describe the physiotherapist's behaviour and when it happened.`
   - `Send report to admin` — **pine primary** (`bg #2F5D50`, white), full width
**Bottom nav / footer:** none.
**Notes:** This screen intentionally uses the pine CTA rather than amber.

## 23. Referral (PATIENT)
**Purpose:** Refer & earn.
**App bar / header:** back `←`, title `Refer & earn`.
**Body, in vertical order:** (gap 16px)
1. **Gradient earnings card** — `linear-gradient(135deg,#2F5D50,#3B7364)`, radius 18px, padding 20px, white:
   mono `TOTAL EARNED` (`rgba(255,255,255,0.75)`) · **`Rs 500`** (Fraunces 30px) · body 12px `Earn Rs 500 for every friend who signs up and completes a booking.` (the amount inline in white 600).
2. **Referral code card** — mono `YOUR REFERRAL CODE`; dashed box (`bg #D1E8DF`, `border 1px dashed rgba(47,93,80,0.4)`, radius 18px, padding 12px) with **`SAHAYA-AK21`** (mono 16px/600, letter-spacing 1.6px, `#2F5D50`) and a `Copy` pill (`bg #2F5D50`, white, 12px/600, padding `6px 12px`).
   Then a **3-column share grid** (gap 8px, radius 18px, `border 1px rgba(0,0,0,0.08)`, `py 12px`, 12px/600, emoji 18px above label): `📱 SMS` · `💬 WhatsApp` · `🔗 Share`.
3. Eyebrow `YOUR INVITES` → grouped card:
   - 40px avatar `NT` (`bg #FBEFD9`) · **Nirajan T.** · `Patient` · badge `JOINED` (success) · `+ Rs 500` (11px/600 `#2F5D50`)
   - `SM` · **Sabina M.** · `Patient` · badge `INVITED` (warning) · `Pending`
**Bottom nav / footer:** none.

## 24. Care packages (PATIENT)
**Purpose:** Browse condition-based therapy packages.
**App bar / header:** back `←`, title `Therapy Packages`, trailing pill `My packages` (`bg #D1E8DF`, `#2F5D50`, 11px/600, padding `6px 12px`).
**Body, in vertical order:**
1. Intro paragraph (12px, relaxed): `Choose the therapy you need, then pick a treatment length that suits your recovery. Every package is delivered by a licensed physiotherapist.`
2. Search field — placeholder **`Search therapy or condition`**.
3. Filter chips (11px/600, scrollable): **All** (selected) · Orthopedic · Neurological · Sports Injury · Geriatric · Post-Surgical · Other.
4. Package cards (gap 12px, padding 16px). Structure: 44px rounded-18 icon tile (pastel) · category badge (neutral) · title 15px/600 · description 12px · hairline · eyebrow `AVAILABLE PACKAGES` · duration chips (`bg #EEF1ED`, `#4A5854`, 11px, radius full, padding `4px 10px`) · footer row `From Rs X` (11px `#8FA8A0`) + `View packages →` amber button.

| Icon (tile fill) | Category | Title | Description | Durations | From |
|---|---|---|---|---|---|
| 🦵 `#D1E8DF` | Orthopedic | Knee Replacement Therapy | Post-surgery physiotherapy designed to improve mobility, strength and recovery. | 1 Week, 2 Weeks, 3 Weeks, 4 Weeks | Rs 4,500 |
| 🧠 `#E8DCF5` | Neurological | Stroke Therapy | Neuro rehabilitation to regain movement, balance and daily independence after a stroke. | 1 Month, 3 Months, 6 Months | Rs 17,000 |
| 🏃 `#FBEFD9` | Sports Injury | ACL & Ligament Injury Therapy | Return-to-play rehabilitation for ligament tears, sprains and overuse injuries. | 10 Days, 3 Weeks, 6 Weeks | Rs 5,400 |
| 💪 `#DCE7F5` | Orthopedic | Frozen Shoulder Therapy | Manual therapy and guided exercise to restore shoulder movement and reduce stiffness. | 2 Weeks, 6 Weeks | Rs 6,800 |
| 🧓 `#F5DCE0` | Geriatric | Elderly Mobility & Fall Prevention | Gentle strengthening and balance care for older adults at home. | 1 Month, 3 Months | Rs 9,690 |
| 🩹 `#D1E8DF` | Post-Surgical | Post-Spine Surgery Rehabilitation | Safe, staged recovery after spinal surgery with posture and core retraining. | 2 Weeks, 5 Weeks | Rs 7,200 |
| 🫁 `#DCE7F5` | Other | Chest & Respiratory Physiotherapy | Breathing exercises and airway clearance for post-illness recovery. | 5 Days, 2 Weeks | Rs 4,000 |

**Bottom nav / footer:** none.
**Primary actions:** `View packages →` → package-duration picker; `My packages` → purchased packages.
**Notes:** In the prototype `View packages →` and `My packages` are **inert** — no detail view exists to copy. Build the duration picker from the chip labels above.

## 25. Package confirmed (PATIENT)
**Purpose:** Package purchase receipt.
**App bar / header:** none — column, padding `40px 24px`.
**Body, in vertical order:**
1. 80px circle `bg #D1E8DF`, `✓` 30px.
2. H1 `Package confirmed!` (28px).
3. Body `All sessions are scheduled with the same therapist. We'll notify you before every visit.`
4. Mono `PACKAGE REF · ` + **`SAH-PKG-7714`**.
5. Detail card (`divide-y`, label mono 10px / value 14px right):
   - `PLAN` → `14-day rehab · 12 sessions`
   - `STARTS` → `Tue, 7 Jul · 09:00`
   - `PATIENT` → `Kamala Adhikari · Sanepa, Lalitpur`
   - `PAYER` → `Booked from Australia`
6. Buttons: `View my sessions` (amber) · `Back to home` (outline).
**Bottom nav / footer:** none.
**Notes:** Demonstrates the diaspora "book for a loved one" flow — the payer and patient differ.

## 26. Chat with us (PATIENT)
**Purpose:** Support chat with an assistant.
**App bar / header:** back `←`, title `Chat with us`.
**Body, in vertical order:**
1. **Assistant header card** — `linear-gradient(120deg,#1E4B3F,#2F5D50)`, radius 18px, padding 12px, white; 40px rounded-14 tile `bg rgba(255,255,255,0.14)` with `💬`; title `Sahayatri Care Assistant` (13px/600); sub `Replies instantly · human team 7am–8pm NPT` (11px, 75% white).
2. Message list (gap 10px). Incoming bubble: `bg #EEF1ED`, `text #1E2A2E`, 12px, padding `8px 12px`, **radius `18px 18px 18px 6px`**, max-width 80%, left-aligned.
   Seed message: `Namaste! I'm Sahayatri Care Assistant. Tell me what's troubling you — pain, surgery recovery, stroke, or booking for your loved ones in Nepal — and I'll point you the right way.`
3. Eyebrow `COMMON QUESTIONS` → wrapped suggestion chips (`bg #FFFFFF`, `text #2F5D50`, 11px, radius full, padding `6px 12px`, `border 1px rgba(47,93,80,0.25)`), in order:
   1. `How much does a home visit cost?`
   2. `I need stroke rehab for my father`
   3. `I'm abroad — can I book for family?`
   4. `Can I get a session today?`
   5. `Talk to a human`
4. **Prefer to talk card** — eyebrow `PREFER TO TALK?`; 40px rounded-14 tile `bg #D1E8DF` with `📞`; `+977 9801-234567` (13px/600); `Call or WhatsApp · 7am–8pm NPT · English & नेपाली` (11px).
**Bottom nav / footer:** **composer bar** — absolutely positioned, `margin 0 12px 12px`, `bg #FFFFFF`, radius 22px, `border 1px rgba(0,0,0,0.06)`, padding `8px 12px`, shadow. Contains an input (radius full, placeholder **`Type your question…`**) and a 40px circular send button (`bg #2F5D50`, white `↑`).
**Notes:** Outgoing bubble style is not shown in the prototype — mirror the incoming bubble with `bg #2F5D50`, white text, radius `18px 18px 6px 18px`.

## 27. Find a clinic (PATIENT)
**Purpose:** Browse in-person clinics.
**App bar / header:** back `←`, title `Find a clinic`.
**Body, in vertical order:**
1. Intro `Prefer visiting in person? Book a date at a verified physiotherapy clinic near you.` (11px `#4A5854`).
2. Search field — placeholder **`Search clinic, area or service`** (the `⌕` glyph here is `#2F5D50`).
3. City chips (**no border**, 11px/600, radius full, padding `6px 12px`): **All** (selected, `bg #2F5D50`) · Lalitpur · Kathmandu · Pokhara.
4. Clinic cards (card buttons, gap 10px, padding 12px, `align-items: flex-start`): 48px rounded-14 tile `bg #D1E8DF` with `🏥` 18px · name 13px/600 (truncate) · `<area> · <distance>` 11px · service badges (neutral) · footer row `★ 4.9 (214)` 10px left and `from Rs 1,200` (11px/600 `#2F5D50`) right.

| Clinic | Location · Distance | Services | Rating | From |
|---|---|---|---|---|
| Sahayatri Physio Centre — Jhamsikhel | Jhamsikhel, Lalitpur · 1.2 km | ELECTROTHERAPY, MANUAL THERAPY | ★ 4.9 (214) | Rs 1,200 |
| Himalaya Rehab Clinic | Baneshwor, Kathmandu · 3.6 km | NEURO REHAB, GAIT TRAINING | ★ 4.7 (158) | Rs 1,000 |
| Lakeside Sports Physio | Lakeside, Pokhara · — | SPORTS INJURY, POST-OP REHAB | ★ 4.8 (96) | Rs 1,300 |

5. Tonal full-width button `Or book a home visit instead →` (`bg #D1E8DF`, `#2F5D50`, 12px/600, radius **18px**, `py 10px`).
**Bottom nav / footer:** Patient nav, no tab active.

## 28. Clinic profile (PATIENT)
**Purpose:** Clinic detail + date/time selection.
**App bar / header:** back `←`, title `Clinic`.
**Body, in vertical order:**
1. **Header card** — 56px rounded-18 tile `bg #D1E8DF` `🏥` 24px · name `Sahayatri Physio Centre — Jhamsikhel` (Fraunces 18px) · `Jhamsikhel, Lalitpur · 1.2 km` (11px) · `★ 4.9 (214 reviews)` (11px, star `#E2962F`).
   Then a 2-column grid (gap 8px) of `bg #EEF1ED` radius-14 tiles (padding 10px):
   `OPENING HOURS` → `Sun–Fri · 7:00 – 19:00` (11px/600) · `CONSULTATION` → `from Rs 1,200`.
2. Eyebrow `SERVICES` → badges, **success variant** (`bg #D1E8DF` / `#2F5D50`): ELECTROTHERAPY · MANUAL THERAPY · GYM-BASED REHAB · DRY NEEDLING.
3. Eyebrow `FACILITIES` → badges, **neutral variant**: PARKING · WHEELCHAIR ACCESS · FEMALE THERAPIST.
4. Eyebrow `PICK A DATE` → horizontal date chips (radius 14px, padding `8px 12px`, 11px/600):
   `Today` · **`Tomorrow` (selected — `bg #2F5D50`, white)** · `Wed 19` · `Thu 20` · `Fri 21`. Unselected: `bg #EEF1ED`, `#4A5854`.
5. Eyebrow `AVAILABLE TIMES · TOMORROW` → **3-column grid**, gap 8px, radius 14px, `py 10px`, 12px/600:
   `07:30` · **`09:00` (selected — `bg #2F5D50`, white)** · `11:00` · `14:30` · `16:00` · `17:30`. Unselected: `bg #FFFFFF`, `#1E2A2E`, `border 1px rgba(0,0,0,0.08)`.
6. `Continue to booking →` — **pine primary**, full width.
**Bottom nav / footer:** none.

## 29. Clinic booking (PATIENT)
**Purpose:** Confirm a clinic visit.
**App bar / header:** back `←`, title `Confirm visit`.
**Body, in vertical order:**
1. **Visit summary card** — eyebrow `VISIT SUMMARY`; key/value rows (12px, `space-between`, label `#4A5854`, value 600 `#1E2A2E`):
   `Clinic` → `Sahayatri Physio Centre — Jhamsikhel` · `Address` → `Jhamsikhel, Lalitpur` · `Date & time` → `Tomorrow · 09:00` · `Consultation fee` → `Rs 1,200`.
2. Eyebrow `PAYMENT METHOD` → 3 radio rows (13px/600, radius 18px, padding `12px 16px`), selected gets `border 1px #2F5D50` + `●` in `#2F5D50`; unselected `○`:
   **eSewa** (selected) · Khalti · Pay at clinic.
3. **Notice banner** — `bg #FBEFD9`, `text #8A5A14`, 12px/600, radius 18px, padding `12px 16px`:
   `Please arrive 10 minutes early and bring any previous reports or scans.`
4. `Confirm clinic visit` — pine primary, full width.
**Bottom nav / footer:** none.

## 30. Clinic booked (PATIENT)
**Purpose:** Clinic booking confirmation.
**App bar / header:** none — centered column, padding `64px 24px 96px`.
**Body, in vertical order:**
1. 64px circle `bg #D1E8DF`, `✓` 24px `#2F5D50`.
2. H1 `Clinic visit booked!` (Fraunces 24px).
3. Body (12px) `Sahayatri Physio Centre — Jhamsikhel — Tomorrow at 09:00. We've sent the address and directions to your phone.`
4. Address card (left-aligned): eyebrow `ADDRESS` → `Jhamsikhel, Lalitpur` (13px/600) → `Sun–Fri · 7:00 – 19:00` (11px).
5. Buttons (gap 8px): `View my sessions` (**pine primary**) · `Back to home` (outline).
**Bottom nav / footer:** none.

---

# PHYSIOTHERAPIST

## 31. Dashboard (PHYSIOTHERAPIST)
**Purpose:** Therapist home — today's list, availability toggle, remarks prompt.
**App bar / header:** none — content starts at `padding-top 16px`.
**Body, in vertical order:**
1. Eyebrow `TODAY'S SCHEDULE` → card containing timeline rows (gap 12px):
   48px time column (Fraunces 14px `#2F5D50`) · 1px × 40px vertical divider `rgba(0,0,0,0.08)` · name 14px/600 + condition 11px · trailing badge.
   - `10:00` — **Pranita K.** — Lower back pain — `CONFIRMED`
   - `13:30` — **Rajesh B.** — Post-knee surgery — `CONFIRMED`
   - `17:00` — **Maya T.** — Frozen shoulder — `PENDING` (warning)
   Then tonal full-width button `View full schedule`.
2. Eyebrow `MANAGE SCHEDULE` → card containing:
   - a `bg #EEF1ED` radius-18 row (padding `10px 12px`): 10px `#2F5D50` dot + `Available for bookings` (13px/600) + **toggle ON (`bg #E2962F`)**
   - note `Set your available days, time slots and unavailable periods.` (11px)
   - `Manage availability` — outline button, full width.
3. Eyebrow `ADD REMARKS ON LAST SESSION` → card: 40px avatar `RB` (`bg #FBEFD9`) · **Rajesh B.** (14px/600) · `Post-knee surgery · Yesterday, 13:30` (11px) · `Add remarks` — **pine primary**, full width.
**Bottom nav / footer:** Therapist nav — **Home** active.
**Primary actions:** `View full schedule` / `Manage availability` → Schedule; `Add remarks` → session-notes form (**inert in prototype**).

## 32. Schedule (PHYSIOTHERAPIST)
**Purpose:** Weekly availability grid + recurring rules.
**App bar / header:** none — eyebrow `SCHEDULE` + H1 `Manage availability` (28px) + sub `Tap a slot to open, block or edit it.`
**Body, in vertical order:**
1. **Week grid card** (padding 12px): CSS grid, **8 columns**, gap 6px, 10px type.
   - Row 0: empty corner cell, then day headers `SUN MON TUE WED THU FRI SAT` (mono, uppercase, `#8FA8A0`, centered).
   - Rows: right-aligned mono time label then 7 slot buttons, **height 32px, radius 8px**.
   - Time labels: `08:00, 10:00, 12:00, 14:00, 16:00, 18:00` (6 rows × 7 = 42 slots).
   - Slot colors: **booked `#2F5D50`** · **open `#D1E8DF`** · **off `#EEF1ED`**.
2. Legend row (11px `#4A5854`, gap 12px): 12px rounded-4 swatch + label — `Booked` (`#2F5D50`) · `Open` (`#D1E8DF`) · `Off` (`#EEF1ED`).
3. Eyebrow `RECURRING AVAILABILITY` → card:
   - Day chips: **Sun, Mon, Tue, Wed, Thu, Fri** — Sun/Mon/Tue/Wed/Thu selected (no Sat chip in this group).
   - Time-block chips: **Morning** (selected) · Afternoon · Evening.
   - Action row (gap 8px): `Save recurring` (**pine primary**) · `Block date` (outline).
**Bottom nav / footer:** Therapist nav — **Schedule** and **Availability** both render active (prototype quirk; pick one in Flutter).

## 33. Requests (PHYSIOTHERAPIST)
**Purpose:** Accept/decline bookings and manage session lifecycle.
**App bar / header:** none — eyebrow `BOOKING REQUESTS` + H1 `Session management` (28px).
**Body, in vertical order:**
1. **Segmented tabs (4)** — 11px/600, order: **`Requests`** (active) · `Upcoming` · `Completed` · `Cancelled`.
2. Session cards (padding 16px, gap 10px): 40px avatar · name (600) · `<condition> · <area>` 11px · trailing badge; meta row 11px with datetime left, `Rs 1,500` right; action row (gap 8px, compact buttons).

**Requests**
| Avatar | Name | Detail | Badge | When | Fee | Actions |
|---|---|---|---|---|---|---|
| SU `#FBEFD9` | Sushma R. | Sciatica · Patan | `NEW` | Wed, 8 Jul · 11:00 | Rs 1,500 | `Accept` (pine) · `Decline` |
| BI | Bipul S. | Sports follow-up · Jawalakhel | `NEW` | Thu, 9 Jul · 16:00 | Rs 1,500 | `Accept` · `Decline` |

**Upcoming** — Pranita K. · Back pain · Pulchowk · `TODAY` · Today · 10:00 · Rs 1,500 · `Mark complete` / `Reschedule`; Rajesh B. · Post-knee · Sanepa · `TODAY` · Today · 13:30 · Rs 1,500 · same actions.
**Completed** — Maya T. · Frozen shoulder · Jhamsikhel · `DONE` · Yesterday · 17:00 · Rs 1,500 · `Upload session notes` / `Add to records`.
**Cancelled** — Hari D. · Neck pain · Baluwatar · `CANCELLED` · Mon · 09:00 · Rs 1,500 · no actions.

**Bottom nav / footer:** Therapist nav, no tab active.

## 34. My patients (PHYSIOTHERAPIST)
**Purpose:** Roster of treated patients.
**App bar / header:** none — eyebrow `MY PATIENTS` + H1 `Treated patients` (28px).
**Body, in vertical order:** patient rows (card, padding 12px, gap 12px): 40px avatar · name (600) · `<condition> · N sessions` (11px `#4A5854`) · `Last visit · <when>` (11px `#8FA8A0`) · trailing `›`.
- **Pranita K.** — Lower back pain · 4 sessions — Last visit · Today
- **Rajesh B.** — Post-knee surgery · 7 sessions — Last visit · Today
- **Maya T.** — Frozen shoulder · 3 sessions — Last visit · Yesterday
- **Bipul S.** — Sports injury · 2 sessions — Last visit · 3 days ago
**Bottom nav / footer:** Therapist nav — **Home** active (prototype quirk).

## 35. Earnings (PHYSIOTHERAPIST)
**Purpose:** Earnings overview + transactions.
**App bar / header:** none — eyebrow `EARNINGS` + H1 `Your payouts` (28px).
**Body, in vertical order:**
1. **Gradient balance card** — `linear-gradient(135deg,#2F5D50,#3F7965)`, radius 18px, padding 20px, white:
   mono `THIS MONTH` · **`Rs 72,000`** (Fraunces 30px) · 2-column grid (12px, gap 16px): `Pending payout` → `Rs 18,000` (600); `Lifetime` → `Rs 4,86,000` (600) · then `Request payout` — **amber primary**, full width.
2. Eyebrow `TRANSACTION HISTORY` → grouped card, rows `space-between`, padding `12px 16px`: name (600) + `<date> · <method>` (11px `#8FA8A0`); amount `+ Rs 1,500` (600, `#2F5D50`).
   - Rajesh B. — 5 Jul · eSewa — + Rs 1,500
   - Pranita K. — 5 Jul · Khalti — + Rs 1,500
   - Maya T. — 4 Jul · Cash — + Rs 1,500
   - Bipul S. — 3 Jul · eSewa — + Rs 1,500
3. Eyebrow `PAYOUT METHOD` → card row: `💚` · `eSewa · 98XX••••21` (14px/600) · `Auto-payout every Friday` (11px `#8FA8A0`) · right text button `Change` (12px/600 `#2F5D50`).
**Bottom nav / footer:** Therapist nav — **Home** active (prototype quirk).
**Notes:** Currency uses the **Nepali lakh grouping** — `Rs 4,86,000`, not `Rs 486,000`.

## 36. Account (PHYSIOTHERAPIST)
**Purpose:** Therapist profile hub.
**App bar / header:** green profile header (same pattern as patient Account):
64px avatar `AS` · `Dr. Anisha Shrestha` (Fraunces 24px) · `anisha@sahayatri.np` (12px) · mono row `PHYSIOTHERAPIST · ` + **`VERIFIED ✓` in `#7AE2A1`** + ` · SINCE MAR 2024` · pill button `Edit profile`.
**Body, in vertical order:** four grouped-list cards with eyebrows.

`PROFESSIONAL`
| Icon | Title | Subtitle |
|---|---|---|
| 🎓 | Specializations | Sports & post-surgery, Neuro |
| 📍 | Service areas | Lalitpur, Kathmandu |
| 💰 | Rate per session | Rs 1,500 |
| 📈 | Request rate increase | Send to admin for approval |
| ✎ | Bio & portfolio | — |
| 📄 | Certifications & license | NMC-PT-04821 |
| 📤 | Upload patient reports | Share medical files with patients |

`PERFORMANCE`
| Icon | Title | Subtitle |
|---|---|---|
| ★ | Ratings & reviews | 4.9 · 182 reviews |
| ✓ | My sessions | 486 completed |
| 👥 | My patients | Treated patients |
| 📚 | Patient records | Session history & handoff notes |

`ACCOUNT`
| Icon | Title | Subtitle |
|---|---|---|
| 💳 | Payment methods | Balance & payouts |
| 🏖 | Apply for emergency day off | Alerts admin |
| 🎁 | Refer & earn | Rs 1,000 per referral |
| 🔔 | Notifications | — |

`SUPPORT`
| Icon | Title | Subtitle |
|---|---|---|
| ❔ | Help & FAQ | — |
| ✉ | Contact support | — |
| ⚠ | Report a patient | Notify admin of misbehavior |

Then `Log out` — danger button.
**Bottom nav / footer:** Therapist nav — **Account** active.

## 37. Upload reports (PHYSIOTHERAPIST)
**Purpose:** Share a medical file with a patient.
**App bar / header:** back `←`, title `Patient reports`.
**Body, in vertical order:**
1. Eyebrow `UPLOAD` + H1 `Share a medical report` (28px).
2. Form card (padding 16px, gap 12px):
   - `PATIENT` — `<select>` (radius full, 14px): `Pranita K.` · `Rajesh B.` · `Maya T.` · `Bipul S.`
   - `FILE` — dropzone label: `bg #D1E8DF`, **`border 2px dashed rgba(47,93,80,0.3)`**, radius 18px, padding 16px, row: `📎` 24px + `Tap to select PDF / image` (14px `#1E2A2E`)
   - `NOTES (OPTIONAL)` — textarea, placeholder `Assessment summary, next steps…`
   - `Upload report` — amber primary
3. Eyebrow `RECENTLY UPLOADED` → grouped card rows (padding `12px 16px`): 36px circle `bg #D1E8DF` `📄` · patient name 14px/600 · `<file> · <size>` 11px `#4A5854` · mono 10px timestamp `#8FA8A0` · trailing text button `View` (11px/600 `#2F5D50`).
   - Pranita K. — `MRI-lumbar.pdf · 1.4 MB` — `Today · 09:42`
   - Rajesh B. — `Post-op-notes.pdf · 820 KB` — Yesterday
   - Maya T. — `X-ray-shoulder.jpg · 2.1 MB` — 3 days ago
   - Bipul S. — `Assessment.pdf · 540 KB` — 1 week ago
**Bottom nav / footer:** none.

## 38. Payments & payout (PHYSIOTHERAPIST)
**Purpose:** Balance, payout request, ledger.
**App bar / header:** back `←`, title `Payments`.
**Body, in vertical order:**
1. **Gradient balance card** — mono `AVAILABLE BALANCE` · **`Rs 18,000`** (Fraunces 30px) · 2-column: `This month` → `Rs 72,000`; `Lifetime` → `Rs 4,86,000`.
2. **Request payout card** — eyebrow `REQUEST PAYOUT`:
   - `AMOUNT (RS)` — number input prefilled **`18000`**
   - `SEND TO` chips: **eSewa** (selected) · Khalti · Bank transfer
   - **`Request payout of Rs 18,000`** — amber primary (label interpolates the amount)
3. Eyebrow `TRANSACTION HISTORY` → grouped card, rows padding `12px 16px`: title 14px/600 + date 11px `#8FA8A0`; right column amount (600) + status badge.
   - `Payout to eSewa` — 5 Jul — `− Rs 15,000` — `SENT` (neutral)
   - `Session · Rajesh B.` — 5 Jul — `+ Rs 1,500` — `EARNED`
   - `Session · Pranita K.` — 5 Jul — `+ Rs 1,500` — `EARNED`
   - `Payout to Khalti` — 28 Jun — `− Rs 20,000` — `SENT`
   - `Payout to eSewa` — 20 Jun — `− Rs 12,000` — `SENT`
**Bottom nav / footer:** none.
**Notes:** Minus sign is the typographic `−` (U+2212), not a hyphen.

## 39. Emergency day off (PHYSIOTHERAPIST)
**Purpose:** Request urgent leave from admin.
**App bar / header:** back `←`, title `Emergency day off`.
**Body, in vertical order:**
1. Eyebrow `TIME OFF` + H1 `Apply for emergency leave` (28px) + sub `Admin will be alerted immediately and your bookings will be rescheduled.`
2. Form card:
   - `DAY OFF DATE` — date input (empty)
   - `REASON` chips: **Medical emergency** (selected) · Family · Travel · Other
   - `DETAILS FOR ADMIN` — textarea, placeholder `Brief context so admin can support your patients.`
   - `Send emergency request` — amber primary
3. Eyebrow `RECENT REQUESTS` → grouped card rows: title 14px/600 + `Emergency day off` (11px `#8FA8A0`) + badge.
   - `12 Jun · Family` — `APPROVED` (success)
   - `3 May · Medical` — `APPROVED`
**Bottom nav / footer:** none.

## 40. Rate increase (PHYSIOTHERAPIST)
**Purpose:** Request a session-rate change from admin.
**App bar / header:** back `←`, title `Rate increase`.
**Body, in vertical order:**
1. Eyebrow `PRICING` + H1 `Request a new session rate` (28px) + sub `Admin reviews rate changes to keep pricing fair across the platform.`
2. **Comparison card** — 2-column grid (gap 12px, padding 16px): mono `CURRENT` → `Rs 1,500` (Fraunces 20px) · mono `PROPOSED` → `Rs 1,700` (Fraunces 20px).
3. Form card:
   - `NEW RATE PER SESSION (RS)` — number input prefilled **`1700`**
   - `JUSTIFICATION` — textarea, placeholder `Certifications, added experience, demand…`
   - `Send request to admin` — amber primary
**Bottom nav / footer:** none.
**Notes:** The `PROPOSED` figure mirrors the input value live.

## 41. Referral (PHYSIOTHERAPIST)
**Purpose:** Therapist refer & earn.
**App bar / header:** back `←`, title `Refer & earn`.
**Body, in vertical order:** identical structure to the patient Referral screen (24) with different content:
1. Gradient card — mono `TOTAL EARNED` · **`Rs 2,500`** (Fraunces 30px) · `Earn Rs 1,000 for every therapist or patient who signs up and completes a booking.`
2. Code card — `YOUR REFERRAL CODE` → dashed box **`SAHAYA-PT-4821`** + `Copy` pill; 3-up share grid `📱 SMS` · `💬 WhatsApp` · `🔗 Share`.
3. Eyebrow `YOUR INVITES` → grouped card:
   - `DS` (`bg #FBEFD9`) — **Dr. Suman Rai** — `Therapist` — `JOINED` — `+ Rs 1,000`
   - `DK` — **Deepa Karki** — `Patient` — `BOOKED` — `+ Rs 500`
   - `KS` — **Kabin Shah** — `Therapist` — `INVITED` — `Pending`
**Bottom nav / footer:** none.

## 42. Report patient (PHYSIOTHERAPIST)
**Purpose:** File a complaint about a patient.
**App bar / header:** back `←`, title `Report patient`.
**Body, in vertical order:**
1. Eyebrow `FEEDBACK TO ADMIN` + H1 `Tell us what happened` (28px) + sub `Reports are confidential and reviewed by the Sahayatri trust team within 24 hours.`
2. Form card:
   - `PATIENT NAME` — placeholder `e.g. Rajesh B.`
   - `ISSUE CATEGORY` chips: **Rude behaviour** (selected) · Harassment · Refused to pay · Unsafe environment · Other
   - `WHAT HAPPENED?` — textarea, placeholder `Describe the patient's behaviour and when it happened.`
   - `Send report to admin` — **pine primary**
**Bottom nav / footer:** none.
**Notes:** No star-rating block here (unlike the patient version, screen 22).

## 43. Patient records (PHYSIOTHERAPIST)
**Purpose:** Session archive with handoff notes; opens a detail bottom sheet.
**App bar / header:** back `←`, title `Patient records`, trailing pill **`+ Add`** (`bg #2F5D50`, white, 11px/600, padding `4px 12px`).
**Body, in vertical order:**
1. Eyebrow `SESSION ARCHIVE` + H1 `Continuity of care` (28px) + sub `Detailed notes for future reference and safe handoff to other physiotherapists.`
2. Record cards (padding 16px, gap 10px), each a tappable button: 40px avatar · name (600) · `<condition> · N sessions` (11px `#4A5854`) · `Last · <when>` (11px `#8FA8A0`) · trailing badge.
   - `PR` — **Pranita K.** — Lower back pain · 4 sessions — Last · Today · 10:00 — `SHAREABLE` (success)
   - `RA` — **Rajesh B.** — Post-knee surgery · 7 sessions — Last · Today · 13:30 — `SHAREABLE`
   - `MA` — **Maya T.** — Frozen shoulder · 3 sessions — Last · Yesterday — `PRIVATE` (neutral)
**Bottom nav / footer:** none.
**Primary actions:** `+ Add` → new record; tapping a card opens the **record bottom sheet**.

### 43a. Record detail bottom sheet
Overlay `rgba(0,0,0,0.35)` · sheet `bg #FFFFFF`, radius `22px 22px 0 0`, padding 20px · grab handle 40 × 4 `rgba(0,0,0,0.15)` centered, `margin-bottom 12px`.
Title: patient name, Fraunces 18px.
Body: scrollable (`max-height 60vh`), gap 8px, of `bg #EEF1ED` radius-**10** rows (padding `8px 12px`): mono 10px uppercase label `#8FA8A0` over 14px value `#1E2A2E`.

| Label | Value (Pranita K.) |
|---|---|
| AGE | 34 |
| CONTACT | +977 98XX-1102 |
| CONDITION | Lower back pain |
| SESSIONS | 4 |
| LAST VISIT | Today · 10:00 |
| DIAGNOSIS | L4-L5 disc bulge, mild sciatica |
| TREATMENT PLAN | McKenzie extensions, core strengthening, TENS |
| PROGRESS | Pain reduced 7→3. ROM improving. |
| HANDOFF NOTES | Continue phase 2 exercises. Avoid heavy lifting. |

Footer action row (gap 8px, `margin-top 16px`): `Make private` (outline) · `Share handoff` (**pine primary**).

---

## Implementation notes for Flutter

1. **No dark mode.** The prototype defines a single light palette; do not add a dark variant.
2. **Three font families are load-bearing.** Bundle Fraunces (display), Inter (UI), IBM Plex Mono (labels/numerals). Every eyebrow, field label, badge and reference code is mono + uppercase + letter-spaced — this is the strongest signature of the design.
3. **Two CTA colors, used deliberately.** Amber (`#E2962F` with dark ink text) is the commercial/primary path (book, pay, upload, request payout). Pine (`#2F5D50` with white text) is used for administrative/trust actions (report to admin, clinic booking, save recurring, share handoff). Keep the split.
4. **Pill-first geometry.** Buttons, inputs, chips and badges are all `borderRadius: StadiumBorder`; cards are 18px; tiles 14px.
5. **Only one shadow.** Surfaces are separated by hairline borders (`rgba(0,0,0,0.06)`), not elevation. The bottom nav and the active segmented tab are the only elevated things.
6. **Bottom nav is a floating pill**, inset 12px from all three edges, with a raised center FAB and an empty spacer slot behind it.
7. **Currency format:** `Rs 1,500` (space after `Rs`, comma grouping), switching to Nepali lakh grouping above 99,999 → `Rs 4,86,000`.
8. **Prototype quirks to fix, not copy:** the active bottom-nav tab is wrong on Notifications, My patients and Earnings (all show *Home*), and Schedule highlights two tabs at once. `View packages →`, `My packages` and `Add remarks` are inert.
9. **Screens with a fixed bottom CTA bar** (Therapist profile, Booking, Cart) need `bottom padding: 112px`; screens with the bottom nav need `96px`.
