# TODO register — deferred API and design work

> Regenerated at each phase boundary. Last update: **2026-08-24 — verified against the live Railway API**.
>
> **Coverage: 43/43 prototype screens built**, and every screen without a backing
> endpoint shows an honest "not available yet" state rather than fabricated data.
>
> **Built is not the same as reachable**, and this line used to claim otherwise.
> Four screens are registered in no router: three by decision, recorded as A27,
> A28 and A29 below, and `Package confirmed` as A26. Two more were unreachable
> and are not any more — `Report patient` and `Rate increase` are routed under
> `/therapist/*` and linked from the Account menu, and the Shop, which was routed
> with nothing anywhere pointing at it, is on the patient centre-action sheet.
>
> Two conventions, from `DEVELOPMENT_PLAN.md` §0.2:
> * **`TODO(api)`** — the screen is built; the backend route does not exist (or is
>   unmerged). The UI shows an honest "not available yet" state; it never fakes success.
> * **`TODO(design)`** — an image or asset is missing. A `PlaceholderBox` reserves the
>   real footprint; no invented artwork ships.
>
> Grep the code with `rg "TODO\(api\)|TODO\(design\)" lib` to check this list against reality.

---

## Blocking, and outside the app's control

| # | Item | Impact | Owner |
|---|---|---|---|
| B1 | ~~Live API suspended~~ — **RESOLVED**: now live at `https://pvc-api-production.up.railway.app` | The app's base URL is updated. Every endpoint the app calls (43/43) exists on the live server, and every response shape matches the DTOs. | done |
| B2 | ~~`origin/development` unmerged~~ — **RESOLVED**: merged into `main` and deployed | Passwordless login, Google OAuth, therapist application/onboarding, patient photo and family members are all live now. See "Newly available" below. | done |
| B3 | **Docker Desktop will not start** on this machine | Only affects running the backend locally; the live API removes the need | Environment |
| **B4** | **🔴 PRODUCTION DOWN: every authenticated request returns 401 "Invalid token"** | `create_access_token` (app/services/auth.py) encodes an `aud` claim, but all three `jwt.decode` calls in `app/deps.py` omit `audience=`. python-jose rejects a token that carries `aud` when no expected audience is given, so **the API is unusable for any signed-in user**. Confirmed end-to-end: the app logs `200 POST /auth/login` immediately followed by `401 GET /patients/me/dashboard`. Public endpoints are unaffected. | **Backend — urgent** |
| B5 | `redis: error` in `/health` | Rate limiting is degraded; it fails open, so requests still succeed | Backend/infra |

**Local development fixture (still useful for offline work):** `tool/mock_api.py` is a stdlib-only stand-in for the
backend that implements the endpoints the app calls, with data shaped like `SEEDDATA.md`.
It is a development fixture only. Run it with `python tool/mock_api.py`, then
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` (emulator) or
`http://localhost:8000` (Chrome). Every Phase 2, 3 and 4 screen was verified against it, for both roles.

---

## API-TODO

Legend for **Status**: `missing` = no endpoint anywhere · `unmerged` = exists on
`origin/development` only · `partial` = endpoint exists but does not cover the screen.

| # | Feature | Needed endpoint | Status | Screen(s) | Phase |
|---|---|---|---|---|---|
| A1 | Google sign-in | `POST /auth/google` | **live** — only the operator OAuth client IDs are missing now | Login | 1 |
| A2 | Passwordless / OTP login | `POST /auth/send-login-otp`, `POST /auth/login-otp` | **live, not adopted** — optional UX addition | Login | 1 |
| A3 | Application reference number | a field on the therapist application | missing | Verification pending | 1 |
| A4 | Therapist application submit | `POST /uploads/therapist-application` then `POST /auth/signup` with `documents[]` | exists, needs a file picker | Sign up · Therapist | 4 |
| A5 | User-facing notification feed | `GET /notifications`, `POST /{id}/read`, `POST /read-all` | **endpoints and 22 producers exist on `pv-core-api` branch `feat/notification-events`, unmerged** — see its `docs/notification_types.md` | Notifications | 2 — **screen wired to all 22 types; an empty feed is the expected state until that branch lands** |
| A6 | Cart checkout / order entity | order create + cart clear | missing | Cart, Order success | 3 |
| A7 | Patient self-upload of reports | permission change on `POST /reports` (Therapist/Admin only today) | partial | Reports & files | 3 |
| A8 | Recovery milestones / pain tracking | a milestones model | missing | Recovery progress | 3 |
| A9 | Saved addresses | addresses CRUD + primary flag | missing | Saved addresses, Booking | 3 |
| A10 | Per-user payment methods | payment-method vault (`/settings/payment-methods` is platform config) | missing | Payment methods | 3 |
| A11 | Package purchase | create N sessions + payment; international payer | missing | Care packages, Package confirmed | 3 |
| A22 | Package shape mismatch | `PackageResponse` is a tier catalogue (`tag`/`cadence`/`blurb`/`points`), not the prototype's condition-based plans with selectable durations | shape differs | Care packages | 3 |
| A23 | Complaint target id | `POST /admin/complaints` needs `againstId`; the report screen only collects a free-text therapist name | partial | Report therapist | 3 |
| A12 | Clinic booking linkage | clinic slots, `clinicId` on Session, rating/price/distance on Clinic | partial | Clinics ×4 | 3 — **list and profile wired; slots and booking are API-TODO** |
| A13 | Live chat | any chat endpoint | missing | Chat with us | 3 |
| A14 | Referral ledger | invite list + earnings; therapist referral programme | partial | Referral ×2 | 3–4 |
| A15 | Therapist payout request | a therapist-initiated payout endpoint (`/admin/payouts` is admin-side) | missing | Payments & payout | 4 — **screen wired; the request button explains** |
| A16 | Rate-increase request | request + admin approval | missing | Rate increase | 4 |
| A17 | Patient-records sharing | records entity with a SHAREABLE/PRIVATE flag | missing | Patient records | 4 |
| A24 | File picking | no `file_picker`/`image_picker` dependency, so `POST /reports` (multipart) and therapist document upload cannot send a file | app-side | Upload reports, Therapist signup | 4 |
| A25 | Accepting-bookings flag | no therapist-level "available for bookings" switch; availability is per-slot only | missing | Therapist dashboard | 4 |
| A26 | Package confirmation is unreachable | the screen is built, but nothing can navigate to it until package purchase (A11) exists | blocked by A11 | Package confirmed | 3 |
| A27 | Chat is unreachable, deliberately | the screen is finished and honest — the composer is inert and says so — but there is no chat endpoint (A13) and the only thing on it that works is copying a support number. `Contact support` is routed on both Account menus and carries the *real* one, so routing this would put two different support numbers one menu row apart. Leave it out of the router until A13 lands. | blocked by A13 | Chat with us | 3 |
| A28 | Upload reports is unreachable, deliberately | both the file tile and Submit open the same "not available" dialog, because there is no file picker (A24) — so the screen cannot start its one job, let alone finish it, and `Recent uploads` is an API-TODO. `POST /reports` exists; this is a client dependency, not an API gap. Route it in the same change that adds the picker. Also still renders a hardcoded English `PATIENT` field label (`upload_report_screen.dart:94`), which `no_hardcoded_copy_test` misses because the literal is all-caps. | blocked by A24 | Upload reports | 4 |
| A29 | Patient records duplicates My patients | both read `GET /patients/my-patients` and draw the same three lines per row; `/therapist/patients` is the one that is routed, from `✓ Patients treated`. What the unrouted twin adds is a tappable row opening a detail sheet whose body is an `ApiTodoState` — because the records themselves do not exist (A17). Routing it means two Account rows listing the same people; the better fix is to give the routed screen's dead chevron that sheet. A product call on the Account menu's IA. | blocked by A17 | Patient records | 4 |
| A18 | Real payment capture | eSewa/Khalti/Wise/PayPal integration — payments are *recorded, not charged* | operator | Booking, Cart, Packages | 3 |
| A19 | SMS confirmations | an SMS provider | operator | Booking success | 3 |
| A20 | Patient profile detail | `PUT /patients/me/profile` for dob, gender, address, concern | **live, not adopted** | Edit profile | 3 |
| A21 | Patient photo upload | `POST /uploads/patients/{id}/photo` | **live, not adopted** — also needs a file picker (A24) | Edit profile | 3 |

## DESIGN-TODO

| # | Asset | Where | Placeholder in use |
|---|---|---|---|
| D1 | Therapist profile photos | Find therapist, Therapist profile, Home | `PlaceholderBox.avatar` (initials fall back first) |
| D2 | Product imagery | Shop, Cart | `PlaceholderBox` at the real tile size |
| D3 | App icon + native splash | Android/iOS launcher | Flutter default — must be replaced before release |
| D4 | Clinic photos | Find a clinic, Clinic profile | `PlaceholderBox` |
| D5 | Package-duration picker | Care packages | No prototype screen exists; needs design (flagged by the design capture) |

## Prototype quirks deliberately NOT copied

The design capture flagged these as prototype bugs rather than intended design.
They are listed so a later reviewer does not "fix" the app back to the broken behaviour.

| Quirk in the prototype | What the app does instead |
|---|---|
| Notifications, My patients and Earnings all highlight the **Home** nav tab | Highlights the tab that matches the current route |
| Schedule highlights two tabs at once | Highlights one |
| `View packages →`, `My packages`, `Add remarks` are inert | Wired, or given an API-TODO state |
| `Preview my dashboard` on Verification pending enters the dashboard | Explains that the dashboard unlocks on approval — an unapproved account is rejected by the API, so navigating there would dead-end |
| Verification pending has no way back | A `Back to log in` action was added; without it the router traps the user on that screen |
| Fixed application reference `SAH-APP-48201` | Derived from the real account id (A3 tracks the proper field) |
| Home screen had a "Quick actions" row that is not in the design | Removed; replaced with the prototype's hero card and "What are you looking for?" cards |
| `★ 0.0` would show for a therapist nobody has rated | Shows `New` instead — a zero score reads as a bad score |
| Booking success claims `SMS sent to +977…` | Says details were saved to My sessions; no SMS is actually sent (A19) |
| The Shop and Care packages have **no entry point** — the prototype only reaches them from its own sidebar | Added to the Account screen under HEALTH; without this the screens would be unreachable |
| Clinic cards show rating, price and distance | Omitted — no such fields exist on `Clinic`; inventing them would be fabricated data (A12) |
| Chat screen looks like a live chat | Composer is visibly disabled and the working phone/WhatsApp number is given prominence — an input that swallows messages is worse than none |
| Recovery progress shows `60% recovered`, a 4-week streak and `↓45% pain` | Progress is computed from real completed/total sessions; streak and pain show `—` pending a milestones model (A8) |
| Therapist dashboard has a master **Available for bookings** toggle | Replaced with a link to the availability screen — no such backend flag exists (A25), and a toggle that silently did nothing would be worse |
| Schedule highlights both **Schedule** and **Availability** tabs | One tab highlights; the availability tab points at Requests, which is what it manages |
| Past days in the weekly grid look identical to open "off" slots | Past cells are dimmed and non-tappable, with a `Past` legend entry — the backend returns no past slots and would reject the edit |
| `Add remarks` is inert in the prototype | Opens a real notes sheet that saves to `PUT /sessions/{id}` |


---

## Newly available since the Railway deploy (2026-08-24)

`origin/development` merged into `main`, so these are live but **not yet adopted by the app**.
None is required — each is an addition, not a fix.

| Endpoint(s) | What it would unlock | Blocked by |
|---|---|---|
| `POST /auth/google` | Google sign-in (A1) | operator OAuth client IDs + a Dart Google-sign-in package |
| `POST /auth/send-login-otp`, `POST /auth/login-otp` | Passwordless login | nothing — pure UX choice |
| `POST /auth/check-email` | Split "enter email → login or sign up" flow | nothing |
| `POST /auth/change-password` | Change password from Account | nothing |
| `GET/PUT /patients/me/profile` | The dob / gender / address / concern fields currently disabled on Edit profile (A20) | nothing |
| `POST/DELETE /uploads/patients/{id}/photo` | Patient profile photo (A21) | a file picker (A24) |
| `GET/POST/PUT/DELETE /patients/me/family-members` | The "book for a loved one" flow properly, rather than a note on the booking | design — no prototype screen exists |
| `POST /patients/me/onboarding`, `GET /patients/me/onboarding-status` | A first-run onboarding flow | design — no prototype screen exists |
| `GET /therapists/me/application-status`, `/application-sections`, `PUT /me/application` | Therapist application progress + resume (A4) | a file picker (A24) |
| `POST /uploads/therapist-application`, `/therapists/{id}/documents` | Therapist document upload (A4) | a file picker (A24) |
| `POST /uploads/complaint-evidence` | Photo evidence on a complaint | a file picker (A24) |

## Contract verification (2026-08-24)

Ran against the live OpenAPI spec, not against source:

- **43/43** endpoints the app calls exist on the server with the expected method.
- **0** field-name mismatches across 34 DTO/schema pairs.
- 16 nullability warnings were all false positives — the generated code emits
  `as String? ?? default` for every one.
- **1 real breaking change found and fixed:** the error envelope (see below).

### Error envelope changed — app updated

The API no longer returns FastAPI's `{"detail": ...}`. Every error is now:

```json
{"success": false, "message": "...", "requestId": "...", "timestamp": "..."}
```

and validation errors carry `errors: [{field: "body → email", message: "..."}]`.

`lib/core/network/error_mapper.dart` now reads `message`/`errors` and keeps
`detail`/`loc`+`msg` as a fallback. This mattered beyond cosmetics: the
pending-therapist routing matches on the server's message text, so before the fix
an unapproved therapist would have seen a generic permission error instead of
being sent to the verification screen.
