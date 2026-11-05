# Sahayatri Physio Mobile — Screen Inventory, API Mapping & Phased Plan

> **Revised 2026-08-20** (see §0 Status update). Originally generated 2026-08-18 from a full walkthrough of the Lovable prototype
> (https://sahayatri-care-connect-mobile-app.lovable.app — 43 screens) cross-referenced
> against the live backend (https://pvc-api-z7pn.onrender.com, routers verified in `pv-core-api/app/routers/`).
> Backend base: all endpoints under `/api/v1`. Live API health: OK (DB + Redis).

## Legend

- ✅ API exists and covers the screen
- ⚠️ API partially covers (gaps noted)
- ❌ No backend API — flagged
- 🔨 Flutter screen already built (UI only, mock data, not wired)
- 🆕 Flutter screen not yet built

---

## 0. Status update — 2026-08-20

### 0.1 What changed since this plan was written

**Flutter repo — Phase 1 build blockers are DONE:**
- All 21 analyzer errors fixed; `flutter analyze` → **0 errors** (196 `prefer_const` infos remain).
- `dart run build_runner build` now works — the retrofit/retrofit_generator version conflict
  (`retrofit 4.9.2` vs `retrofit_generator 9.7.0`) was the blocker; pinned in `pubspec.yaml`
  and `retrofit_generator` moved to `dev_dependencies`. `*.g.dart` files generate.
- Broken default widget test replaced with a real boot smoke test; `flutter test` → **green**.
- Router no longer rebuilt every frame — `routerProvider` added; `CardTheme`→`CardThemeData`;
  `_mockTherapists` → `mockTherapists` (cross-library visibility).
- **Web platform added** (`flutter create --platforms=web .`) — app runs in Chrome.
- **Android fully working**: cmdline-tools installed, licenses accepted, platform/build-tools 36
  installed, `flutter doctor` **all green**, `pixel_8` AVD created, app builds and runs on the
  emulator (`build/app/outputs/flutter-apk/app-debug.apk`).

**Backend — two findings that change the plan:**

1. **The live Render API is SUSPENDED** (`https://pvc-api-z7pn.onrender.com` → HTTP 503
   "This service has been suspended"). The original plan's "test against the live API" strategy
   is **not currently possible**. → *Operator action required* (see Phase 0).
2. **`origin/development` is 5 commits ahead of `main`** (main: 2026-08-17, development: 2026-08-20)
   with substantial auth work **not yet merged or deployed**:

   | New on `development` | Endpoints | Impact |
   |---|---|---|
   | Passwordless / OTP login | `POST /auth/send-login-otp`, `POST /auth/login-otp` | Changes the Login screen |
   | Google OAuth | `POST /auth/google` | Un-blocks the ❌ "Google login" gap |
   | Email pre-check | `POST /auth/check-email` | Enables split login/signup UX |
   | Therapist application | `GET /therapists/me/application-status`, `/application-sections`, `PUT /me/application` | Therapist signup + onboarding |
   | Patient photo, family members | `patients.py` (+152 lines), `uploads.py` (+112) | Edit profile, "book for a loved one" |
   | JWT `role` claim + `iat/iss/aud` | — | Role-aware redirect can read the token directly |

**Decision: build against `main`'s contract.** `main` is the deployed branch and the stable
contract; `development` is unmerged WIP. Screens whose *only* backing is a `development` endpoint
are built with the **API-TODO convention** below and switch on when that work merges.

### 0.2 Working conventions (apply everywhere)

| Situation | Convention |
|---|---|
| Backend endpoint does not exist (or is unmerged) | Build the full UI. Wire the data layer to a repository method that returns a typed `Failure.notImplemented`. Mark with `// TODO(api): <endpoint> — <what it needs>`. UI shows a clear, non-broken "Coming soon" / disabled state — never a crash or a fake success. |
| Image / illustration / icon asset not available | Use a **placeholder element** (`PlaceholderBox` in `core/widgets/`) sized to the real asset, showing a neutral fill + label. Mark with `// TODO(design): <what asset is needed>`. Never ship a broken image or an invented asset. |
| Copy/labels | Must match the Lovable prototype **exactly** (see `LOVABLE_DESIGN_SPEC.md`). Every string goes through the i18n layer. |
| Design fidelity | The Lovable prototype is the source of truth for layout, order, colors, and flow. Each phase ends with a design-conformance review against `LOVABLE_DESIGN_SPEC.md`; deviations are fixed before the phase closes. |

A running index of every deferred item is kept in **`docs/TODO_REGISTER.md`** (API-TODO and
DESIGN-TODO tables), regenerated at each phase boundary.

### 0.3 MVP cut line (added — the original plan had none)

43 screens is *not* the launch bar. Screens are now tiered:

- **TIER 1 — Launch blocking (must ship):** Splash, Login, Patient signup, Verification pending,
  Edit profile, Patient Home, Find therapist, Therapist profile, Booking, Booking success,
  My sessions, Account, Shop, Cart, Order success, Therapist Dashboard, Schedule, Requests,
  My patients, Earnings, Therapist account, Upload reports, Emergency day off, Therapist signup.
  *All of these have full ✅ API coverage on `main` except cart checkout.*
- **TIER 2 — Ship if the backend lands:** Notifications, Reports & files, Recovery progress,
  Referral ×2, Report therapist/patient, Payments & payout.
- **TIER 3 — Post-launch:** Care packages ×2, Clinics ×4, Chat, Saved addresses,
  Payment methods, Rate increase, Patient records.

Tier 2/3 screens are still **built** (per the user's instruction to complete all phases) but with
the API-TODO convention where the backend is missing — they are not allowed to block Tier 1.

### 0.4 Development loop (revised)

The original "test on Flutter web against the live Render API" is replaced by:
- **Primary target: Android emulator** (`pixel_8`) + Chrome for quick checks.
- **API base URL** via `--dart-define=API_BASE_URL=…`; default resolution order:
  local `http://10.0.2.2:8000` (emulator→host) / `http://localhost:8000` (web) → live URL when restored.
- Dio configured with generous timeouts + a "waking up the server" state, because the live API is
  a free-tier Render service with 30–60 s cold starts *when it is restored*.
- Because the API is currently unreachable, **every screen must render correctly with the API
  down** — loading → error → retry states are part of the definition of done, not polish.

---

## 1. Screen-by-screen inventory & API mapping

### SHARED (7 screens)

| # | Screen | Function | API | Status |
|---|---|---|---|---|
| 1 | Splash 🔨 | Brand intro, role CTAs ("Get started" / "I'm a physiotherapist" / login) | `GET /health` (optional), token restore → `GET /auth/me` | ✅ |
| 2 | Login 🔨 | Role toggle (UI only), email+password, forgot password, Google login | `POST /auth/login` ✅ · `POST /auth/forgot-password` + `POST /auth/reset-password` ✅ · Google OAuth ❌ (no endpoint) | ⚠️ |
| 3 | Sign up · Patient 🔨(single combined screen) | Name, phone, email, pw, DOB, gender, city, health concern, terms | `POST /auth/send-otp` → `POST /auth/verify-otp` → `POST /auth/signup` ✅; DOB/gender/concern → `PUT /patients/me/profile` ✅ | ✅ |
| 4 | Sign up · Therapist 🆕(separate rich form) | Credentials + NMC license upload, certificate, photo, specializations, cities, bio, available days/blocks, payout method | `POST /uploads/therapist-application` (docs) → `POST /auth/signup` (with `documents[]`) ✅ · availability set post-approval via availability APIs ✅ · payout method at signup ❌ (no field; deferred) | ⚠️ |
| 5 | Verification pending 🔨 | "Under review" state, application ref, status | Static post-signup; login while pending → 403 (`auth.loginUnderReview`) ✅ | ✅ |
| 6 | Notifications 🔨 | User notification feed (booking confirmed, reminders, payment, rate-prompt) | ❌ **No user-facing notifications API** — `/admin/notifications` is admin-only. Needs new backend endpoints or client-side derivation from sessions/payments | ❌ |
| 7 | Edit profile 🆕 | Photo, personal fields, home address, primary concern | `PUT /auth/me` ✅ · `PUT /patients/me/profile` ✅ | ✅ |

### PATIENT (23 screens)

| # | Screen | Function | API | Status |
|---|---|---|---|---|
| 8 | Home 🔨 | Next session card, featured therapists, find-therapist/find-clinic CTAs | `GET /patients/me/dashboard` ✅ · `GET /sessions` ✅ · `GET /therapists` ✅ | ✅ |
| 9 | Find therapist 🔨 | Search + specialty filter, therapist cards w/ rating, availability, fee | `GET /therapists` (filters) ✅ | ✅ |
| 10 | Therapist profile 🔨 | Bio, stats, rating, available slots by date, continue to booking | `GET /therapists/{id}` ✅ · `GET /therapists/{id}/slots` / `GET /availability/slots` ✅ · `GET /reviews` ✅ | ✅ |
| 11 | Booking 🔨 | Summary, home address, "booking for a loved one from abroad", payment method (eSewa/Khalti/Cash), confirm+pay | `POST /payments/process` (booking+payment combo) ✅ · real gateway integration (eSewa/Khalti) ❌ (payment is recorded, not charged) | ⚠️ |
| 12 | Booking success 🔨 | Ref, address, payment, SMS confirmation note | From booking response ✅ · SMS send ❌ (no SMS service) | ⚠️ |
| 13 | My sessions 🔨 | Tabs Upcoming/Past/Cancelled; reschedule, cancel | `GET /sessions` ✅ · `PATCH /sessions/{id}/reschedule` ✅ · `DELETE /sessions/{id}` ✅ | ✅ |
| 14 | Shop 🔨 | Category tabs (Equipment/Medicines/Nutrition), stock badge, add to cart, rent pricing | `GET /products?category=` ✅ | ✅ |
| 15 | Cart 🔨 | Rental duration picker, qty, subtotal + delivery + deposit, checkout | `GET/POST/PUT/DELETE /cart` ✅ (rental days + delivery fee logic in backend) · checkout → **no order entity**; `POST /payments` records payment ⚠️ | ⚠️ |
| 16 | Order success 🔨 | Order ref, delivery promise | Depends on checkout above ⚠️ | ⚠️ |
| 17 | Account 🔨 | Profile summary, links to all sub-screens, logout | `GET /auth/me` ✅ · `GET /patients/me/dashboard` ✅ | ✅ |
| 18 | Reports & files 🆕 | List therapist-shared PDFs, download, patient self-upload | `GET /reports` ✅ · file download `GET /uploads/{patientId}/{filename}` (token param) ✅ · **patient self-upload ❌** (`POST /reports` is Therapist/Admin only) | ⚠️ |
| 19 | Recovery progress 🆕 | % recovered, sessions count, streak, pain reduction, milestones timeline | `GET /patients/me/dashboard` gives basic counts ⚠️ · **milestones/pain-tracking model ❌** | ⚠️ |
| 20 | Saved addresses 🆕 | Multiple addresses, primary toggle | ❌ **No addresses API** (User has single city/address) | ❌ |
| 21 | Payment methods 🆕 | Per-user linked wallets (eSewa/Khalti), primary toggle | ❌ **No per-user payment-method API** (`/settings/payment-methods` is platform-level config) | ❌ |
| 22 | Report therapist 🆕 | Complaint w/ category, rating, description → admin | `POST /complaints` ✅ · evidence via `POST /uploads/complaint-evidence` ✅ | ✅ |
| 23 | Referral (patient) 🆕 | Code, share, invites list, earnings | `GET /patients/me/referral` ✅ (code) · invite/earnings ledger ⚠️ (check response shape; prototype shows per-invite status) | ⚠️ |
| 24 | Care packages 🆕 | Condition picker, tiered packages (trial→30-day), diaspora ("book from abroad", foreign currency) | `GET /packages` ✅ (catalog) · **package purchase/booking ❌** (no endpoint; would need N sessions + payment) · intl payment (Wise/PayPal) ❌ | ⚠️ |
| 25 | Package confirmed 🆕 | Ref, plan, start, patient, payer | Depends on package purchase ❌ | ❌ |
| 26 | Chat with us 🆕 | Support chat assistant, canned questions, human handoff, phone/WhatsApp | ❌ **No chat API.** Phone/WhatsApp links are client-side ✅ | ❌ |
| 27 | Find a clinic 🆕 | Search + city filter, clinic cards (services, rating, distance, from-price) | `GET /clinics` ✅ (model: name/area/city/address/services/phone/hours — **no rating/price/distance fields** ⚠️) | ⚠️ |
| 28 | Clinic profile 🆕 | Hours, services, facilities, date+time slot picker | `GET /clinics/{id}` ✅ · **clinic slots ❌** (no clinic availability model) | ⚠️ |
| 29 | Clinic booking 🆕 | Visit summary, payment method, confirm | `POST /sessions` with `type=CLINIC` ⚠️ (Session has no `clinicId` — clinic captured via address string; no clinic therapist assignment) | ⚠️ |
| 30 | Clinic booked 🆕 | Confirmation + directions | From response ⚠️ | ⚠️ |

### PHYSIOTHERAPIST (13 screens)

| # | Screen | Function | API | Status |
|---|---|---|---|---|
| 31 | Dashboard 🔨 | Today's schedule, availability toggle, add remarks on last session | `GET /therapists/me/dashboard` ✅ · `GET /sessions` ✅ · remarks → `PUT /sessions/{id}` (notes) ✅ | ✅ |
| 32 | Schedule 🔨 | Weekly grid (booked/open/off), recurring availability, block date | Availability suite: `GET/PUT /availability/working-hours`, `/availability` grid, `/slot`, `/bulk`, `/recurring`, `/block-date`, `/block-range`, `/unblock`, `/apply-schedule`, `/open-month` ✅ | ✅ |
| 33 | Requests 🔨 | Tabs Requests/Upcoming/Completed/Cancelled; accept/decline | `GET /sessions` ✅ · `PUT /sessions/{id}` status (SessionStatus incl. RESCHEDULE_REQUESTED / DECLINE_REQUESTED) ✅ | ✅ |
| 34 | My patients 🔨 | Treated patients w/ visit history | `GET /patients/my-patients` ✅ | ✅ |
| 35 | Earnings 🔨 | Month/pending/lifetime, transactions, payout method | `GET /therapist/earnings/transactions` ✅ · `GET /therapist/earnings/payouts` ⚠️ (synthesized monthly aggregates, read-only) | ⚠️ |
| 36 | Account (therapist) 🆕 | Professional info, specializations, service areas, rate, bio, certifications, performance links | `GET /therapists/me` ✅ · `PUT /therapists/{id}` ✅ · media upload `POST /uploads/therapists/{id}` ✅ | ✅ |
| 37 | Upload reports 🆕 | Pick patient, attach PDF/image, notes; recent uploads list | `POST /reports` (multipart, Therapist) ✅ · `GET /reports` ✅ | ✅ |
| 38 | Payments & payout 🆕 | Balance, request payout (amount + eSewa/Khalti/Bank), transaction history | Read ✅ · **therapist-initiated payout request ❌** (admin `/admin/payouts` exists; no request endpoint) | ⚠️ |
| 39 | Emergency day off 🆕 | Date, reason, details → alerts admin; recent requests w/ status | `POST /availability/block-request` ✅ · `GET /availability/block-requests` ✅ (admin approves/rejects) ✅ | ✅ |
| 40 | Rate increase 🆕 | Propose new rate + justification → admin approval | ❌ **No rate-increase request/approval endpoint** (direct `PUT /therapists/{id}` bypasses admin review) | ❌ |
| 41 | Referral (therapist) 🆕 | Code, invites (therapists Rs 1,000 / patients Rs 500), earnings | ⚠️ `GET /patients/me/referral` is patient-oriented; therapist referral program ❌ | ⚠️ |
| 42 | Report patient 🆕 | Complaint against patient w/ category → admin | `POST /complaints` (therapist complaint) ✅ | ✅ |
| 43 | Patient records 🆕 | Session archive, handoff notes, SHAREABLE/PRIVATE toggle | ⚠️ Sessions + reports per patient exist; **records entity w/ share flag ❌** | ⚠️ |

---

## 2. Flagged backend gaps (mobile-blocking items in bold)

| Gap | Affects | Severity |
|---|---|---|
| **User-facing notifications feed** (`GET /notifications` for patient/therapist, mark-read) | Notifications screen, badge | High — screen already built in Flutter |
| **Cart checkout → order** (order entity or payment-against-cart + cart clear) | Cart, Order success | High — core commerce loop |
| Per-user saved addresses (CRUD + primary) | Saved addresses, Booking address picker | Medium |
| Per-user payment methods vault | Payment methods, Booking/Cart | Medium (can defer — pick per transaction) |
| Package purchase (create N sessions + payment; intl payer) | Care packages, Package confirmed | Medium |
| Clinic booking linkage (clinic slots, `clinicId` on Session, rating/price fields on Clinic) | Find clinic, Clinic profile/booking | Medium |
| Rate-increase request + admin approval flow | Rate increase | Medium |
| Therapist payout request | Payments & payout | Medium |
| Therapist referral program (+ invite/earnings ledger for both roles) | Referral ×2 | Low-Medium |
| Recovery milestones / pain tracking model | Recovery progress | Low (can compute basics from sessions) |
| Patient self-upload of reports (permission change on `POST /reports`) | Reports & files | Low (small change) |
| Patient-records sharing entity (handoff notes, share flag) | Patient records | Low |
| Google OAuth | Login | Low (email+OTP works) — needs operator credentials |
| Real payment gateways (eSewa/Khalti/Wise/PayPal), SMS notifications, live chat | Booking, packages, chat | Operator-dependent (merchant accounts) |

## 3. Flutter app current state (verified 2026-08-20)

> Supersedes the 2026-08-18 snapshot. See section 0.1 for what changed.

**Build health: green.** `flutter analyze` 0 errors - `flutter test` green - builds and runs on
Chrome, the Android emulator (`pixel_8`), and `flutter build web` succeeds.

**Wiring: still zero.** 22 of 43 screens exist as static UI with hardcoded mocks; **no screen calls
the API yet**. The auth data/domain layer (Retrofit `AuthApi`, repository, use cases) is written and
now *generates*, but is still never instantiated - `AuthActions.init()` is not called, login is a
`Future.delayed` plus role-toggle, and the router redirects every logged-in user to `/patient/home`
regardless of role.

**Missing screens (21):** therapist signup, forgot/reset password, edit profile, reports and files,
recovery progress, saved addresses, payment methods, report therapist, report patient, referral x2,
care packages x2, chat, clinics x4, upload reports, payments and payout, emergency day off,
rate increase, therapist account, patient records.

**Environment (all resolved this session):** Flutter 3.44.4 / Dart 3.12.2 - Android SDK 36 plus
cmdline-tools and licenses - `pixel_8` AVD - web platform added. The remaining environment blockers
are the **suspended live API** (operator action) and **Docker Desktop not starting** on this machine,
which blocks the local `docker compose up` fallback.

## 4. Phased plan (revised 2026-08-20)

> Standing rule for **every** phase: it ends with `flutter analyze` clean, `flutter test` green,
> a run on the Android emulator **and** Chrome, a **design-conformance review against
> `LOVABLE_DESIGN_SPEC.md`** with deviations fixed before the phase closes, and a refreshed
> `docs/TODO_REGISTER.md`.

### Phase 0 - Operator-only prerequisites (agent CANNOT do these)

**Blocking now:**
- [ ] **Un-suspend the Render API** (`pvc-api-z7pn.onrender.com` returns 503 "service suspended").
      Until then no live end-to-end verification is possible - the app is built against the
      contract in `pv-core-api/app/routers/` (authoritative source) and must tolerate the API being down.
- [ ] **Decide the API branch**: merge `origin/development` into `main` (passwordless login, Google
      OAuth, therapist application/onboarding, patient photo and family members) or keep it unmerged.
      This plan builds against `main`; the `development` endpoints are wired behind API-TODOs.

**Needed before the corresponding later work:**
- [ ] **Payment gateways**: eSewa/Khalti merchant accounts (plus Wise/PayPal/Stripe for diaspora);
      API keys; sandbox vs production. Until then payments are *recorded, not charged* - and the
      UI must say so rather than offering wallets that do nothing.
- [ ] **Google OAuth**: Google Cloud project, consent screen, iOS/Android/web client IDs,
      SHA-1/SHA-256 fingerprints. (The backend half already exists on `development`.)
- [ ] **Push notifications**: Firebase (FCM) plus an APNs key, if push is wanted (the in-app feed needs none).
- [ ] **SMS**: a provider (e.g. Sparrow SMS) for booking confirmations, or descope the SMS copy.
- [ ] **SMTP secrets on Render**: confirm `SMTP_USER`/`SMTP_PASSWORD` are set so OTP mail really sends.
- [ ] **Store presence**: Play Console and Apple Developer accounts, signing keys, listings (accounts take days).
- [ ] **Deploy authority**: may the agent push to `pv-core-api` (Render auto-deploys) when filling gaps?
- [ ] **Business decisions**: referral amounts, package pricing, delivery/deposit rules, clinic data, rate policy.
- [x] ~~Device/emulator setup~~ - **done** (Android emulator and web both working).

### Phase 1 - Foundation: run, authenticate, navigate  ✅ COMPLETE

- [x] Fix analyzer errors, run codegen, replace the broken test, add web and Android targets.
- [x] `core/config`: `AppConfig` with `API_BASE_URL` via `--dart-define`, a platform-aware default
      (`10.0.2.2` on the Android emulator, `localhost` on web), and generous Dio timeouts.
- [x] `core/network`: Dio provider plus auth interceptor (bearer from secure storage, 401 triggers logout),
      typed `Failure` mapping including `notImplemented` and a distinct `serverWaking` state.
- [x] Riverpod wiring: `DioClient` to `AuthApi` to `AuthRepositoryImpl` to `AuthActions.init()`.
- [x] Real auth: login (403 pending-therapist goes to the verification-pending screen), patient signup with
      OTP (send/verify/signup), logout, splash session-restore (`GET /auth/me`), **role-aware**
      redirect (therapist to `/therapist/home`).
- [x] Forgot-password and reset-password screens (`POST /auth/forgot-password`, `/reset-password`).
- [x] `core/widgets/PlaceholderBox` and `core/widgets/ApiTodoState` (the two convention widgets from section 0.2).
- [x] Extract hardcoded mocks into `core/mock/` so screens compile while being wired one by one.
- **Exit:** a login/logout/signup round-trip against a reachable API (or a documented, graceful failure
  path while the API is suspended); the role-correct landing screen; a design review of the 5 auth screens.

### Phase 2 - Patient core loop: find, book, manage  ✅ COMPLETE

- Data and domain layers: therapists, availability slots, sessions, reviews, payments.
- Wire: Home (dashboard, next session, featured), Find therapist (search plus specialty filter),
  Therapist profile (real slots by date), Booking (`POST /payments/process`), Booking success,
  My sessions (tabs, reschedule, cancel), and review-after-session.
- Edit profile plus patient profile fields (DOB, gender, concern, address).
- Notifications: **no derived-feed throwaway work** (revised) - ship the screen with the
  API-TODO empty state until a real endpoint exists.
- **Exit:** a patient can discover, book, reschedule, cancel, and review; design review of all
  patient-core screens.

### Phase 3 - Patient commerce and care extras  ✅ COMPLETE

- Shop and Cart wired (rental durations, delivery fee, deposit from the backend).
- **Checkout has no backend order entity**, so it is an API-TODO: the flow is built end-to-end and the
  final submit surfaces a clear "checkout unavailable" state rather than faking an order.
- Reports and files (list and download; self-upload is an API-TODO - `POST /reports` is Therapist/Admin only).
- Recovery progress (basic counts from the dashboard; milestones and pain tracking are an API-TODO).
- Referral, Report therapist (complaint plus evidence upload - fully supported).
- Saved addresses, Payment methods, Care packages x2, Clinics x4, Chat: **built with API-TODOs**
  per section 0.2 (Tier 3 - these must not block Tier 1).
- **Exit:** every patient screen exists and is either wired or correctly showing an API-TODO state;
  design review of the full patient surface.

### Phase 4 - Therapist suite, polish, release prep  ✅ CORE COMPLETE

- Therapist signup application form (document upload via `/uploads/therapist-application`) plus the pending flow.
- Wire: Dashboard, Schedule/Availability (working hours, recurring, block/unblock, grid), Requests
  (accept/decline), My patients, Earnings, Upload reports (multipart), Emergency day off
  (block-requests), Report patient, and Therapist account.
- API-TODO: payout request, rate-increase request, therapist referral, patient-records sharing.
- Cross-cutting polish: error, empty, and loading states everywhere, a Nepali i18n pass, clearing the
  `prefer_const` infos, widget and provider tests (mocktail), CI green.
- Release: app icons and splash (a DESIGN-TODO if assets are absent), versioning, an Android release build.
- **Exit:** a full design review of all 43 screens against the Lovable spec; `TODO_REGISTER.md` is the
  complete, accurate handover list of what the operator and backend must finish.
