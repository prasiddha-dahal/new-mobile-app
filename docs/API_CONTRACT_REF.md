# API Contract Reference (Flutter)

Generated from `pv-core-api` @ `main`. Source of truth: `app/routers/*.py`, `app/models/*.py`, `prisma/schema.prisma`.

- **Base URL:** `{host}/api/v1` — every path below is relative to that prefix.
- **Auth:** `Authorization: Bearer <access_token>` (HTTPBearer). Missing header on a bearer route → **403** (FastAPI `HTTPBearer` default), bad/expired token → **401**.
- **Casing:** response/request bodies are almost all **camelCase**. Query params are almost all **snake_case**. Exceptions are flagged per endpoint and collected in [Gotchas](#gotchas-for-the-flutter-client).
- `get_current_user` additionally 401s a THERAPIST whose `status != APPROVED` (detail `"Your account is pending approval"`).
- Health probes live outside the prefix: `GET /health`, `GET /live`, `GET /ready`.

---

## Auth — `/auth`

### `POST /auth/send-otp`
**Auth:** none
**Body:** `SendOtpRequest { email: str, name: str = "" }`
**Returns:** `{ message: str, resend_after: int }` — **snake_case**
**Notes:** 409 if email already registered. 429 if resent too soon (`detail` carries the wait seconds).

### `POST /auth/verify-otp`
**Auth:** none
**Body:** `VerifyOtpRequest { email: str, code: str, purpose: str = "signup" }`
**Returns:** `{ verified: true }`
**Notes:** 400 on invalid/expired code. `purpose` is `"signup"` or `"password_reset"`.

### `POST /auth/signup`
**Auth:** none
**Body:** `SignupRequest`
**Returns:** `TokenResponse` — **201**
**Notes:** Requires a *used, unexpired* signup OTP for that email, else 400. 409 if email exists. **For `role="THERAPIST"` the response has `access_token: null`** (account is PENDING; no session). PATIENT must supply `password`; THERAPIST must not (server generates a temp one, `mustChangePassword=true`).

### `POST /auth/login`
**Auth:** none
**Body:** `LoginRequest { email: str, password: str }`
**Returns:** `TokenResponse`
**Notes:** 401 bad credentials. **403** for a THERAPIST not `APPROVED` (different `detail` for PENDING vs REJECTED).

### `GET /auth/me`
**Auth:** bearer · **Returns:** `UserResponse`

### `PUT /auth/me`
**Auth:** bearer
**Body:** `UserUpdate { name?, city?, phone?, specialty? }` (all `str | None`)
**Returns:** `UserResponse`

### `POST /auth/forgot-password`
**Auth:** none · **Body:** `ForgotPasswordRequest { email: str, name: str = "" }` · **Returns:** `{ message, resend_after }` · 404 if no account, 429 if throttled.

### `POST /auth/reset-password`
**Auth:** none · **Body:** `ResetPasswordRequest { email: str, code: str, new_password: str }` (**snake_case**) · **Returns:** **204 No Content** (empty body).

### `POST /auth/change-password`
**Auth:** bearer · **Body:** `ChangePasswordRequest { current_password: str, new_password: str }` (**snake_case**) · **Returns:** **204**. 400 if current password wrong.

### `POST /auth/logout`
**Auth:** none · **Body:** none · **Returns:** **204**. Server-side no-op — just drop the token locally.

---

## 1. Therapists — `/therapists`

### `GET /therapists`
**Auth:** none
**Query:** `search: str?`, `city: str?`, `specialty: str?`, `gender: str?`, `skip: int = 0` (≥0), `limit: int = 100` (1–200)
**Returns:** `TherapistListResponse { therapists: [TherapistResponse], total: int }`
**Notes:** key is `therapists`, **not** `items`. `search` matches name/specialty/city/gender (case-insensitive contains). Ordered `createdAt desc`.

### `GET /therapists/{therapist_id}`
**Auth:** none · **Returns:** `TherapistResponse` · 404 if missing.

### `GET /therapists/me`
**Auth:** bearer (THERAPIST) · **Returns:** `TherapistResponse` · 403 non-therapist, 404 if no Therapist row.

### `GET /therapists/me/profile`
**Auth:** bearer (THERAPIST) · **Returns:** `TherapistProfileResponse`
**Notes:** the only shape carrying `email`, `phone`, `photo`, `mediaUrls`, `documents`.

### `PUT /therapists/me/profile`
**Auth:** bearer (THERAPIST)
**Body:** `TherapistProfileUpdate { name?, phone?, city?, specialty?, gender?, price?: double, experience?: int, bio?, mediaUrls? }`
**Returns:** `TherapistProfileResponse`
**Notes:** `exclude_none` — omit or send `null` to leave a field untouched. `name/phone/city/specialty` are written to **User**; `name/city/specialty/gender/price/experience/bio/mediaUrls` to **Therapist**.

### `GET /therapists/me/dashboard`
**Auth:** bearer (THERAPIST) · **Returns:** `TherapistDashboardResponse` · 403/404.

### `GET /therapists/{therapist_id}/slots`
**Auth:** bearer (any role)
**Query:** `from_date: str` (required, `YYYY-MM-DD`), `to_date: str` (required) — **snake_case**
**Returns:** `SlotRangeResponse { slots: [SlotInfo], blocks: [BlockInfoResponse] }`
**Notes:** the patient-facing booking calendar. 404 if therapist id unknown.

### `POST /therapists`
**Auth:** bearer (THERAPIST)
**Body:** `TherapistCreate { name: str, specialty: str, city: str, gender: str, price: double, experience: int, bio: str }` (all required)
**Returns:** `TherapistResponse` — **201** · 409 if profile already exists.

### `PUT /therapists/{therapist_id}`
**Auth:** bearer (owner or ADMIN)
**Body:** `TherapistUpdate` (same fields as `TherapistCreate`, all nullable)
**Returns:** `TherapistResponse` · 403 if not owner/admin.

### `DELETE /therapists/{therapist_id}`
**Auth:** bearer (owner or ADMIN) · **Returns:** **204**, empty body.

---

## 2. Sessions — `/sessions`

### `POST /sessions`
**Auth:** bearer (PATIENT)
**Body:** `SessionCreate { therapistId: str, date: DateTime, time: str, type: str = "HOME_VISIT", address: str, fee: double, notes: str? }`
**Returns:** `SessionResponse` — **201**
**Notes:** `date` is a full ISO-8601 **datetime**, not a date string. `type` is uppercased server-side; must map to `SessionType`. `patientId` comes from the token — do not send it. No slot-conflict check here (use `POST /payments/process` for the real booking flow).

### `GET /sessions`
**Auth:** bearer (any role)
**Query:** `skip: int = 0`, `limit: int = 100`
**Returns:** `SessionListResponse { sessions: [SessionResponse], total: int }`
**Notes:** role-scoped automatically — PATIENT→own (`createdAt desc`), THERAPIST→own (`date asc`), ADMIN→all. **`patientName`/`patientPhone` come back as `""` for the PATIENT and ADMIN branches** (the patient relation is not joined); only the THERAPIST branch fills them. 404 if a therapist has no Therapist row.

### `GET /sessions/{session_id}`
**Auth:** bearer (any role)
**Returns:** `SessionResponse` · 404 if missing.
**Notes:** **no ownership check** — any authenticated user can fetch any session by id. `patientName`/`patientPhone` are `""` here.

### `PATCH /sessions/{session_id}/reschedule`
**Auth:** bearer (PATIENT)
**Body:** `RescheduleRequest { newDate: str, newTime: str }` — `newDate` is `YYYY-MM-DD`, `newTime` is `HH:MM`
**Returns:** `SessionResponse`
**Notes:** **409** with `detail: "That slot was just booked — please choose another."`; otherwise **400** with a plain-English `detail` (`"Session not found"`, `"Not authorized"`, `"Only scheduled sessions can be rescheduled"`, `"New slot must be different from the current one"`, `"Invalid time slot for this therapist"`). Only `SCHEDULED` sessions qualify.

### `PUT /sessions/{session_id}`
**Auth:** bearer (patient owner, owning therapist, or ADMIN)
**Body:** `SessionUpdate { status?: str, date?: DateTime, time?: str, notes?: str }`
**Returns:** `SessionResponse` · `exclude_none`. `status` must be a `SessionStatus` value.

### `DELETE /sessions/{session_id}`
**Auth:** bearer (patient owner or ADMIN) · **Returns:** **204**. Hard delete, not a status change.

---

## 3. Availability — `/availability`

Every route is **bearer (THERAPIST)** and scoped to the caller's own therapist row unless stated. Non-therapist → 403; therapist with no Therapist row → 404.

### `GET /availability`
**Query:** `month: int` (**required**), `year: int` (**required**)
**Returns:** `MonthlyGridResponse { month: str, year: int, slots: [SlotInfo] }`
**Notes:** `month` goes **in** as an int and comes **back** as a string.

### `GET /availability/slots`
**Query:** `from_date: str` (required), `to_date: str` (required), `therapist_id: str?`
**Auth:** bearer (any role **if** `therapist_id` is given, else THERAPIST)
**Returns:** `SlotRangeResponse` · 404 `"Therapist not found"`.

### `GET /availability/working-hours` → `WorkingHoursResponse`
### `PUT /availability/working-hours`
**Body:** `WorkingHoursUpdate { start: str, end: str, slotInterval: int = 120, sessionDuration: int = 60, breakDuration: int = 0, daysOfWeek: [str] = [] }`
**Returns:** `WorkingHoursResponse`
**Notes:** stored as a `Setting` row keyed `wh_{userId}`, merged over defaults `{start:"09:00", end:"18:00", slotInterval:60, sessionDuration:60, breakDuration:0, daysOfWeek:["Mon".."Fri"]}`. `slotInterval` default differs between the request model (120) and the server default (60).

### `GET /availability/working-days`
**Returns:** a **bare JSON array of strings**, e.g. `["Mon","Wed","Fri"]` — no wrapper object, no `response_model`.

### `POST /availability/apply-schedule`
**Body:** `ApplyScheduleRequest { recurrence: str = "weekly", dateFrom: str?, dateTo: str? }` — `recurrence` ∈ `weekly | monthly | yearly | range`
**Returns:** untyped `{ opened: int, skippedBooked: int, skippedPast: int, from: str, to: str }`

### `POST /availability/slot`
**Body:** `SlotUpdate { date: str, time: str, status: str }` · **Returns:** **204**, empty body.

### `POST /availability/bulk`
**Body:** `BulkSlotUpdate { slots: [SlotUpdate] }` · **Returns:** `SlotUpdateResponse { updated: int }`

### `POST /availability/generate`
**Body:** `GenerateAvailabilityRequest { dateFrom: str, dateTo: str?, daysOfWeek: [str], startTime: str, endTime: str, sessionDuration: int, breakDuration: int }`
**Returns:** `SlotUpdateResponse { updated: int }`

### `POST /availability/open-month`
**Body:** `OpenFullMonthRequest { days: [int], sessions: [str], month: int, year: int }`
**Returns:** `OpenMonthResponse { opened: int, skippedBooked: int, skippedPast: int }`

### `POST /availability/recurring`
**Body:** `RecurringPatternCreate { days: [int], sessions: [str] }`
**Returns:** `RecurringApplyResponse { affected: int, skippedPast: int, patternId: str }`

### `GET /availability/recurring` → `RecurringPatternListResponse { patterns: [RecurringPatternResponse] }` — **no `total`**.
### `PUT /availability/recurring/{pattern_id}`
**Body:** raw `dict` — only `{"isActive": bool}` is read (defaults to `true`) · **Returns:** **204**.
### `DELETE /availability/recurring/{pattern_id}` → **204**.

### `POST /availability/block-date`
**Body:** `BlockDateRequest { date: str, sessions: [str]? }` · **Returns:** `BlockDateResponse { blocked: int }`

### `POST /availability/block-range`
**Body:** `BlockRangeRequest { dateFrom: str, dateTo: str?, daysOfWeek: [str], partsOfDay: [str], reason: str = "Time off", notify: bool = true, blockType: str = "range" }`
**Returns:** `BlockRangeResponse { blocked: int, cancelledCount: int, affectedPatients: [str] }`

### `POST /availability/unblock`
**Body:** `UnblockRequest { date: str, time: str? }` · **Returns:** **204**.

### `GET /availability/audit-log`
**Query:** `limit: int = 5`, `offset: int = 0` — note `offset`, **not** `skip`, and a default of 5
**Returns:** `PaginatedAuditLogResponse { entries: [AuditLogEntryResponse], total: int }`

### `POST /availability/audit-log`
**Body:** `AuditLogCreateRequest { date: str, time: str?, reason: str, scope: str, source: str, blockId: str? }`
**Returns:** `AuditLogEntryResponse` — **200** (not 201).
### `DELETE /availability/audit-log/{entry_id}` → **204**.

### `POST /availability/block-request`
**Body:** `BlockRangeRequest` (same as block-range)
**Returns:** untyped `{ id: str, dateFrom: str, dateTo: str, status: str, createdAt: str }`

### `GET /availability/block-requests`
**Auth:** bearer (THERAPIST **or** ADMIN)
**Returns:** a **bare JSON array**, and **the element shape differs by role**:
- THERAPIST → `{ id, dateFrom, dateTo, daysOfWeek: [str], partsOfDay: [str], reason, status, adminNotes: str?, createdAt }` (max 20, newest first)
- ADMIN → pending only, plus `therapistId`, `therapistName`, `therapistEmail`, `notify: bool`, and **no `adminNotes`**

### `PUT /availability/block-requests/{request_id}/approve` · `.../reject`
**Auth:** bearer (ADMIN) · **Body:** raw `dict`, only `{"adminNotes": str}` is read (defaults `""`)
**Returns:** untyped dict; on a missing id it returns **200** with `{ success: false, error: "Request not found" }` — **not** a 404.

---

## 4. Reviews — `/reviews`

### `GET /reviews/therapists-to-rate`
**Auth:** bearer (PATIENT)
**Query:** `limit: int = 100` (≥0)
**Returns:** a **bare JSON array** `[TherapistToRate]` — no wrapper, no `total`.

### `POST /reviews`
**Auth:** bearer (PATIENT)
**Body:** `ReviewCreate { sessionId: str, rating: int (1–5), comment: str? }`
**Returns:** `ReviewResponse` — **201**
**Notes:** two distinct **409**s — `"This session has already been reviewed"` and `"You have already reviewed this therapist"` (one review per patient↔therapist pair, ever). 404 if the session isn't the caller's. `therapistId` is derived from the session — do not send it.

### `GET /reviews`
**Auth:** bearer (any role)
**Query:** `skip: int = 0`, `limit: int = 100`
**Returns:** `ReviewListResponse { reviews: [ReviewResponse], total: int }`
**Notes:** always filters by `patientId == current_user.id`, so a THERAPIST calling this gets an empty list — it is **not** "reviews of me".

---

## 5. Payments — `/payments`

### `POST /payments/process`
**Auth:** bearer (PATIENT)
**Body:** `BookingPaymentRequest`
**Returns:** `BookingPaymentResponse { session: SessionPaymentResponse, payment: PaymentResponse }` — **201**
**Notes:** the real booking endpoint — creates the Session **and** the Payment in one call. Charged amount is `fee + platformFee`; payment `status` is forced to `"COMPLETED"`. `paymentMethod` is uppercased and stored as `Payment.method`.

### `POST /payments`
**Auth:** bearer (any role)
**Body:** `PaymentCreate`
**Returns:** `PaymentResponse` — **201**. `status` falls to the DB default `"PENDING"`.

### `GET /payments`
**Auth:** bearer (any role) · **Query:** `skip: int = 0`, `limit: int = 100`
**Returns:** `PaymentListResponse { payments: [PaymentResponse], total: int }` — ADMIN gets all, everyone else gets their own.

### `GET /payments/{payment_id}`
**Auth:** bearer · **Returns:** `PaymentResponse` · **404** (not 403) when it belongs to someone else.

### `PUT /payments/{payment_id}/status`
**Auth:** bearer (ADMIN)
**Query:** `new_status: str` — **a required query parameter, not a body** (snake_case)
**Returns:** `PaymentResponse`

---

## 6. Products — `/products`

### `GET /products`
**Auth:** none · **Query:** `category: str?`, `skip: int = 0`, `limit: int = 100`
**Returns:** `ProductListResponse { products: [ProductResponse], total: int }` · `category` must be a `ProductCategory` value.
### `GET /products/{product_id}` — **Auth:** none · `ProductResponse` · 404.
### `POST /products` — **Auth:** bearer (ADMIN) · **Body:** `ProductCreate` · **201**.
### `PUT /products/{product_id}` — **Auth:** bearer (ADMIN) · **Body:** `ProductUpdate` (`exclude_none`) · `ProductResponse`.
### `DELETE /products/{product_id}` — **Auth:** bearer (ADMIN) · **204**.

---

## 7. Cart — `/cart`

### `GET /cart`
**Auth:** bearer (any role)
**Returns:** `CartResponse { items: [CartItemResponse], total: double, deliveryFee: double, grandTotal: double }`
**Notes:** `total` is the **subtotal** (misleading name); `grandTotal = total + deliveryFee`. `deliveryFee` is `0` when subtotal ≥ 2000, else `150`. RENT lines cost `price × quantity × rentalDays`. Each item embeds the **full nested `product`**.

### `POST /cart`
**Auth:** bearer · **Body:** `CartItemCreate { productId: str, type: str = "BUY", quantity: int = 1, rentalDays: int = 7 }`
**Returns:** `CartItemResponse` — **201** (a single item, **not** the whole cart) · 404 if `productId` unknown.

### `PUT /cart/{item_id}`
**Auth:** bearer (owner) · **Body:** `CartItemUpdate { quantity?: int, rentalDays?: int, type?: str }` · **Returns:** `CartItemResponse` · 404 if not the caller's.

### `DELETE /cart/{item_id}` — **204** · 404 if not the caller's.
### `DELETE /cart` — **204**, clears the whole cart.

---

## 8. Patients — `/patients`

### `GET /patients/me/profile`
**Auth:** bearer (any role) · **Returns:** `PatientProfileResponse` · **404 `"Patient profile not found"`** if the row was never created — handle this, it is the normal state for a fresh patient.

### `PUT /patients/me/profile`
**Auth:** bearer · **Body:** `PatientProfileUpdate` · **Returns:** `PatientProfileResponse`
**Notes:** upserts, so this is how you create the profile. `exclude_unset` — only keys actually present are written. Server-side **422** validators: `phone`/`emergencyPhone` must have 7–15 digits; `dob` must be `YYYY-MM-DD`; `gender` ∈ `Any | Male | Female`; `city` ∈ `Kathmandu | Lalitpur | Bhaktapur | Pokhara | Chitwan | Biratnagar`.

### `GET /patients/me/dashboard`
**Auth:** bearer · **Returns:** `PatientDashboardResponse` · `nextSession` is nullable.

### `GET /patients/me/referral`
**Auth:** bearer · **Returns:** `ReferralResponse { code: str, link: str }`

### `GET /patients/my-patients`
**Auth:** bearer (THERAPIST) · 403 `"Therapist access required"`
**Query:** `search: str?`, `condition: str?`, `skip: int = 0`, `limit: int = 10` (1–100) — note `limit` defaults to **10**
**Returns:** untyped `{ patients: [MyPatientItem], total: int }`

---

## 9. Reports — `/reports`

### `POST /reports`
**Auth:** bearer (THERAPIST or ADMIN)
**Body:** **`multipart/form-data` only** — fields `patientId: str`, `title: str`, `content: str`, `sessionId: str?`, plus repeated file parts named `files`
**Returns:** `ReportResponse` — **201**
**Notes:** sending JSON returns **400** `"Use multipart/form-data with patientId, title, content, and files"`. `therapistId` is resolved from the token. Allowed extensions `.jpg .jpeg .png .gif .webp .pdf .doc .docx`; >10 MB → **413**; bad extension → **400**. Multiple files are joined into the single `fileUrl` string **comma-separated**.

### `GET /reports`
**Auth:** bearer (any role)
**Query:** `patient_id: str?` (**snake_case**; required for THERAPIST/ADMIN, ignored for PATIENT), `skip: int = 0`, `limit: int = 100`
**Returns:** a **bare JSON array** `[ReportResponse]` — no `total`. 400 if a therapist/admin omits `patient_id`.

### `GET /reports/therapist`
**Auth:** bearer (THERAPIST or ADMIN) · **Query:** `skip`, `limit`
**Returns:** untyped `{ reports: [TherapistReportItem], total: int }` — **a different shape from `ReportResponse`** (adds `patient`, `files`, `date`; `createdAt`/`updatedAt` are ISO strings).

### `GET /reports/{report_id}` — **Auth:** bearer · `ReportResponse` · **404** (not 403) when not yours.
### `PUT /reports/{report_id}` — **Auth:** bearer (THERAPIST owner or ADMIN) · **Body:** `ReportUpdate { title?, content?, fileUrl? }` · `ReportResponse`.
### `DELETE /reports/{report_id}` — **Auth:** bearer (THERAPIST owner or ADMIN) · **204**.

---

## 10. Earnings — `/therapist`

> Note the prefix is **`/therapist`** (singular), not `/therapists`.

### `GET /therapist/earnings/transactions`
**Auth:** bearer (THERAPIST)
**Query:** `page: int = 1` (≥1), `limit: int = 20` (1–100) — **page-based, not skip-based**
**Returns:** untyped `{ transactions: [TransactionItem], total: int, page: int, limit: int }`
**Notes:** a non-therapist (or a therapist with no profile) gets **200** with an empty list, not 403/404.

### `GET /therapist/earnings/payouts`
**Auth:** bearer (THERAPIST) · **Query:** `page: int = 1`, `limit: int = 20`
**Returns:** untyped `{ payouts: [PayoutItem], total: int, page: int, limit: int }`
**Notes:** synthesized in memory from COMPLETED sessions grouped by month — `id` is `"payout-YYYY-MM"`, `status` is the literal `"Completed"`/`"Pending"` (title case, unlike every other status in the API), `paidAt` is always `"YYYY-MM-28"`. Same silent-empty behaviour.

---

## 11. Complaints — `/admin/complaints`

> They live under the `/admin` prefix but **`POST` and `GET` (list) only require a plain bearer token** — a PATIENT can file and list complaints. The rest are ADMIN-only.

### `GET /admin/complaints`
**Auth:** bearer (any role)
**Query:** `skip: int = 0`, `limit: int = 10`, `search: str?`, `type: str?`, `status: str?`, `priority: str?`, `category: str?`, `complainantId: str?` (**camelCase**), `sortBy: str?` (**camelCase**), `sortOrder: str = "desc"` (**camelCase**)
**Returns:** `ComplaintListResponse { items: [ComplaintResponse], total: int }` — the wrapper key is **`items`**, unlike every other list in the API.
**Notes:** no server-side scoping to the caller — pass `complainantId` yourself to get "my complaints".

### `POST /admin/complaints`
**Auth:** bearer (any role)
**Body:** `ComplaintCreate`
**Returns:** `ComplaintResponse` — **201**
**Notes:** `complainantId`/`complainantName` are **not** taken from the token — the client must send them.

### `GET /admin/complaints/{complaint_id}` — **Auth:** bearer (ADMIN) · `ComplaintResponse` · 404.
### `PUT /admin/complaints/{complaint_id}` — **Auth:** bearer (ADMIN) · **Body:** `ComplaintUpdate { status?, priority?, category?, description?, assignee?, adminNotes? }` · `ComplaintResponse`.
### `PUT /admin/complaints/{complaint_id}/assign` — **Auth:** bearer (ADMIN) · **Body:** `AssignRequest { assigneeId: str }` · `ComplaintResponse`.
### `DELETE /admin/complaints/{complaint_id}` — **Auth:** bearer (ADMIN) · **204**.
### `GET /admin/complaints/new-count` — **Auth:** bearer (ADMIN) · **Query:** `since: str?` (ISO-8601, `Z` accepted) · **Returns:** `{ count: int }`. An unparseable `since` is silently ignored (counts everything).

### Incidents (same Complaint table, different projection)
- `GET /admin/incidents` — **Auth:** bearer (ADMIN) · **Query:** `skip: int = 0`, `limit: int = 10`, `status: str?` · **Returns:** untyped `{ items: [IncidentItem], total: int }`
- `PUT /admin/incidents/{incident_id}/escalate` — ADMIN · **Returns:** `{ id: str, status: "Escalated" }` · 404.
- `PUT /admin/incidents/{incident_id}/resolve` — ADMIN · **Body:** raw `dict`, only `{"outcome": str}` is read · **Returns:** `{ id: str, status: "Resolved", message: str }` · 404.

---

## 12. Packages — `/packages`

### `GET /packages` — **Auth:** none · **Query:** `skip: int = 0`, `limit: int = 100` · **Returns:** `PackageListResponse { packages: [PackageResponse], total: int }`
### `GET /packages/{package_id}` — **Auth:** none · `PackageResponse` · 404.
### `POST /packages` — **Auth:** bearer (ADMIN) · **Body:** `PackageCreate` · **201**.
### `PUT /packages/{package_id}` — **Auth:** bearer (ADMIN) · **Body:** `PackageUpdate` (`exclude_none`) · `PackageResponse`.
### `DELETE /packages/{package_id}` — **Auth:** bearer (ADMIN) · **204**.

---

## 13. Clinics — `/clinics`

### `GET /clinics` — **Auth:** none · **Query:** `search: str?`, `city: str?`, `skip: int = 0`, `limit: int = 100` · **Returns:** `ClinicListResponse { clinics: [ClinicResponse], total: int }`
### `GET /clinics/{clinic_id}` — **Auth:** none · `ClinicResponse` · 404.
### `POST /clinics` — **Auth:** bearer (ADMIN) · **Body:** `ClinicCreate` · **201**.
### `PUT /clinics/{clinic_id}` — **Auth:** bearer (ADMIN) · **Body:** `ClinicUpdate` (`exclude_none`) · `ClinicResponse`.
### `DELETE /clinics/{clinic_id}` — **Auth:** bearer (ADMIN) · **204**.

---

## 14. Uploads — `/uploads`

Global limits: **10 MB** per file (`413`), extensions `.jpg .jpeg .png .gif .webp .pdf` (`400`); photos are images only. All upload bodies are `multipart/form-data`.

### `POST /uploads/therapist-application`
**Auth:** **none (public)** — used during signup before an account exists
**Body:** repeated file parts `files`, plus form field `session: str` (client-generated, 8–128 chars, no path separators; defaults to `"therapist-application"`)
**Returns:** `{ urls: [{ url: str, fileName: str, fileSize: int }] }`
**Notes:** feed these `url`s into `SignupRequest.documents[].url`.

### `POST /uploads/complaint-evidence`
**Auth:** **none (public)** · same body shape (`files` + `session`) · **Returns:** `{ urls: [{ url, fileName, fileSize }] }`. Embed into `ComplaintCreate.evidenceUrls`.

### `POST /uploads/therapists/{therapist_id}`
**Auth:** bearer (THERAPIST or ADMIN) · **Body:** repeated `files`
**Returns:** `{ urls: [str], total: int }` — plain URL strings here, unlike the two public endpoints above.
**Notes:** `{therapist_id}` accepts **either** a Therapist id or a User id; a missing Therapist row is created lazily. Appends to `Therapist.mediaUrls` (a comma-joined string).

### `POST /uploads/therapists/{therapist_id}/documents`
**Auth:** bearer (own profile or ADMIN) · **Body:** `files` + form field `documentType: str = "Additional document"` (truncated to 64 chars)
**Returns:** `{ documents: [TherapistDocument] }` · Creates `Verification` rows with `status: "Pending review"`.

### `POST /uploads/therapists/{therapist_id}/photo`
**Auth:** bearer (own profile or ADMIN) · **Body:** a **single** file part named `file` (not `files`)
**Returns:** `{ url: str }` · Becomes the first entry of `mediaUrls`, i.e. the avatar.

### `DELETE /uploads/therapists/{therapist_id}/photo`
**Auth:** bearer (own profile or ADMIN) · **Returns:** `{ success: bool, removed: int }` (**200**, not 204).

### `GET /uploads/{patient_id}/{filename}` — serve a report file
**Auth:** **`?token=<jwt>` query parameter — the Authorization header is ignored here**
**Returns:** the raw file bytes with a guessed content-type · 401 bad token, 403 wrong patient, 404 missing.
**Notes:** report `fileUrl`s already carry `?name=…&size=…`; append `&token=…`. This is the only auth-by-query-param route — never log these URLs.

### `GET /uploads/therapists/{therapist_id}/{filename}` — **Auth:** bearer (any role) · raw file bytes.
### `GET /uploads/applications/{session}/{filename}` — **Auth:** bearer (any role) · raw file bytes.
### `GET /uploads/evidence/{session}/{filename}` — **Auth:** bearer (any role) · raw file bytes.

---

## 15. Settings — `/settings`

### `GET /settings/design-tokens` — **Auth:** none · **Returns:** `{ tokens: Map<String, dynamic>? }` — **`tokens` is `null`** when unset.
### `PUT /settings/design-tokens` — **Auth:** bearer (ADMIN) · **Body:** `{ tokens: {…} }` · **Returns:** `{ ok: true }`.
### `GET /settings/currencies` — **Auth:** none · **Returns:** `{ currencies: [Currency] }` — `[]` when unset.
### `PUT /settings/currencies` — **Auth:** bearer (ADMIN) · **Body:** `{ currencies: [Currency] }` · **Returns:** `{ ok: true }`.
### `GET /settings/payment-methods` — **Auth:** none · **Returns:** `{ methods: [PaymentMethod] }` — key is **`methods`** while the writer's body key is `methods` too, but the setting is stored under `payment-methods`.
### `PUT /settings/payment-methods` — **Auth:** bearer (ADMIN) · **Body:** `{ methods: [PaymentMethod] }` · **Returns:** `{ ok: true }`.

---

## Bonus: Services — `/services`

### `GET /services` — **Auth:** none · **Query:** `category: str?` (`CLINICAL | SHOP`), `skip`, `limit` · **Returns:** `ServiceListResponse { services: [ServiceResponse], total: int }`
### `GET /services/{service_id}` — **Auth:** none · `ServiceResponse` · 404.
### `POST /services` — ADMIN · `ServiceCreate` · **201**. `PUT /services/{id}` — ADMIN. `DELETE /services/{id}` — ADMIN · **204**.

---

# Response models — exact JSON field names

All names below are **verbatim JSON keys**. `?` = nullable (send/expect `null`). `DateTime` = ISO-8601 datetime string; `String /*date*/` = `"YYYY-MM-DD"`; `String /*time*/` = `"HH:MM"`.

```
UserResponse
  id: String
  name: String
  email: String
  role: String              // Role enum
  city: String?
  phone: String?
  specialty: String?
  status: String            // UserStatus enum
  photo: String?            // injected from Therapist.mediaUrls[0]; always null for non-therapists
  mustChangePassword: bool  // defaults false

TokenResponse
  access_token: String?     // SNAKE_CASE, and NULL for a THERAPIST signup
  token_type: String        // SNAKE_CASE, always "bearer"
  user: UserResponse
```

```
TherapistResponse
  id: String                // Therapist.id — NOT the User id
  userId: String
  name: String
  specialty: String
  city: String
  gender: String
  rating: double            // 0 when unrated, never null
  reviews: int              // review COUNT, not a list
  price: double             // the session fee; called `price`, not `fee`
  experience: int
  bio: String
  createdAt: DateTime
  updatedAt: DateTime

TherapistListResponse
  therapists: List<TherapistResponse>
  total: int

TherapistProfileResponse                 // GET/PUT /therapists/me/profile only
  id: String
  userId: String
  name: String
  email: String                          // never null (from User)
  phone: String                          // "" when User.phone is null
  city: String
  specialty: String
  gender: String
  price: double
  experience: int
  bio: String
  mediaUrls: String?                     // COMMA-SEPARATED url list, not an array
  photo: String?                         // first mediaUrls entry
  documents: List<TherapistDocument>?    // nullable list

TherapistDocument
  id: String
  documentType: String?
  documentUrl: String?
  fileName: String?
  fileSize: int?
  status: String?                        // e.g. "Pending review"
  note: String?
```

```
TherapistDashboardResponse
  name: String
  sessionsThisWeek: int
  totalPatients: int
  earningsThisMonth: double
  averageRating: double
  todaySessions: List<TodaySessionData>
  recentUploads: List<RecentUploadData>
  publicProfile: PublicProfileData
  recentRatings: List<RecentRatingData>
  referralCode: String
  referralLink: String

TodaySessionData   { id: String, time: String, patient: String, patientId: String,
                     address: String, type: String, status: String }
RecentUploadData   { id: String, patient: String, kind: String, title: String,
                     content: String, files: List<String>, date: String }
PublicProfileData  { name: String, specialty: String, experience: int,
                     rating: double, totalReviews: int }
RecentRatingData   { id: String, name: String, stars: int, text: String }
```

```
SessionResponse   (== SessionPaymentResponse, field-for-field)
  id: String
  therapistId: String                    // Therapist.id
  therapistName: String                  // "" if not joined — never null
  patientId: String                      // User.id
  patientName: String                    // "" on the patient/admin list branches
  patientPhone: String                   // ""
  date: DateTime
  time: String /*time*/
  type: String                           // SessionType enum
  status: String                         // SessionStatus enum
  address: String
  fee: double
  notes: String?
  createdAt: DateTime
  updatedAt: DateTime

SessionListResponse
  sessions: List<SessionResponse>
  total: int
```

```
SlotInfo
  date: String /*date*/
  time: String /*time*/
  status: String            // "open" | "booked" | "off"
  patientName: String       // "" default
  patientPhone: String      // ""
  sessionType: String       // ""
  fee: double?
  sessionId: String?

SlotRangeResponse   { slots: List<SlotInfo>, blocks: List<BlockInfoResponse> }
MonthlyGridResponse { month: String, year: int, slots: List<SlotInfo> }

BlockInfoResponse
  id: String
  dateFrom: String /*date*/
  dateTo: String /*date*/
  daysOfWeek: List<String>
  partsOfDay: List<String>
  reason: String
  notify: bool
  createdAt: String         // ISO STRING, not DateTime

WorkingHoursResponse
  start: String /*time*/
  end: String /*time*/
  slotInterval: int
  sessionDuration: int
  breakDuration: int
  daysOfWeek: List<String>  // ["Mon","Tue",...]

SlotUpdateResponse       { updated: int }
OpenMonthResponse        { opened: int, skippedBooked: int, skippedPast: int }
BlockDateResponse        { blocked: int }
BlockRangeResponse       { blocked: int, cancelledCount: int, affectedPatients: List<String> }
RecurringApplyResponse   { affected: int, skippedPast: int, patternId: String }

RecurringPatternResponse
  id: String
  therapistId: String
  days: List<int>
  sessions: List<String>
  isActive: bool
  createdAt: String         // ISO STRING, not DateTime
RecurringPatternListResponse { patterns: List<RecurringPatternResponse> }   // no `total`

AuditLogEntryResponse
  id: String
  date: String /*date*/
  time: String?             // REQUIRED KEY but nullable — no default
  reason: String
  scope: String
  source: String
  createdAt: String         // ISO STRING
  dateTo: String?
  daysOfWeek: List<String>
  partsOfDay: List<String>
PaginatedAuditLogResponse { entries: List<AuditLogEntryResponse>, total: int }
```

```
ReviewResponse
  id: String
  sessionId: String
  patientId: String
  therapistId: String
  rating: int
  comment: String?
  createdAt: DateTime       // NO updatedAt, even though the DB has one
ReviewListResponse { reviews: List<ReviewResponse>, total: int }

TherapistToRate
  sessionId: String
  therapistId: String
  therapistName: String
  sessionDate: DateTime
  sessionType: String
```

```
PaymentResponse
  id: String
  userId: String
  amount: double            // fee + platformFee for /payments/process
  status: String            // "PENDING" | "COMPLETED" | free-form (plain DB string)
  method: String            // "CASH", "ESEWA", ... uppercased free-form string
  sessionId: String?
  currency: String          // "NPR"
  platformFee: double
  paymentType: String?
  transactionRef: String?
  cardLast4: String?
  walletMobile: String?
  billingCountry: String?
  createdAt: DateTime
  updatedAt: DateTime
PaymentListResponse    { payments: List<PaymentResponse>, total: int }
BookingPaymentResponse { session: SessionPaymentResponse, payment: PaymentResponse }
```

```
ProductResponse
  id: String
  name: String
  category: String          // ProductCategory enum
  price: double
  rentPerDay: double
  inStock: int
  emoji: String             // "" default, never null
  description: String?
  imageUrl: String?
  createdAt: DateTime
  updatedAt: DateTime
ProductListResponse { products: List<ProductResponse>, total: int }

CartItemResponse
  id: String
  userId: String
  productId: String
  product: ProductResponse  // fully nested, always present
  type: String              // CartItemType enum
  quantity: int
  rentalDays: int
  createdAt: DateTime
  updatedAt: DateTime
CartResponse { items: List<CartItemResponse>, total: double,
               deliveryFee: double, grandTotal: double }
```

```
PatientProfileResponse
  id: String                // PatientProfile.id
  userId: String
  name: String
  phone: String
  city: String
  address: String?
  history: String?
  dob: String?              // "YYYY-MM-DD" STRING
  age: int?                 // computed server-side; null when dob is null
  gender: String            // "Any" default
  condition: String?        // read from User.condition, NOT PatientProfile
  emergencyName: String?
  emergencyRelation: String?
  emergencyPhone: String?
  notifEmail: bool
  notifSms: bool
  createdAt: String         // ISO STRING, not DateTime
  updatedAt: String         // ISO STRING, not DateTime

PatientDashboardResponse
  name: String
  totalSessions: int
  completedSessions: int
  upcomingSessions: int
  nextSession: NextSessionInfo?
  referralCode: String
  referralLink: String
NextSessionInfo { id: String, therapistName: String, therapistId: String,
                  date: String, time: String, type: String, status: String }
ReferralResponse { code: String, link: String }

MyPatientItem              // untyped, from GET /patients/my-patients
  id: String               // User.id
  name: String
  phone: String            // "" default
  condition: String        // "" default
  sessions: int
  last: String             // ISO datetime string, or "" when unknown
  notes: String            // ""
```

```
ReportResponse
  id: String
  patientId: String
  therapistId: String?
  sessionId: String?
  title: String
  content: String           // NOT nullable in the response model
  fileUrl: String?          // COMMA-SEPARATED url list when >1 file
  createdAt: DateTime
  updatedAt: DateTime

TherapistReportItem        // untyped, from GET /reports/therapist — DIFFERENT SHAPE
  id: String
  patientId: String
  sessionId: String?
  title: String
  content: String           // "" when null
  fileUrl: String?
  patient: String           // patient NAME, or "Unknown"
  files: List<String>       // fileUrl already split on ","
  date: String              // pre-formatted "5 Aug" — display only
  createdAt: String         // ISO STRING
  updatedAt: String         // ISO STRING
```

```
TransactionItem            // untyped, GET /therapist/earnings/transactions
  id: String               // the SESSION id, not a payment id
  patientName: String      // "Unknown" fallback
  patientPhone: String     // ""
  date: String /*date*/    // "" when null
  time: String             // ""
  type: String
  fee: double
  status: String           // SessionStatus
  paymentMethod: String    // "" when no payment row
  paymentStatus: String    // "PENDING" fallback

PayoutItem                 // untyped, GET /therapist/earnings/payouts
  id: String               // "payout-YYYY-MM"
  month: String            // "YYYY-MM"
  earnings: double
  sessions: int
  status: String           // "Completed" | "Pending"  (TITLE CASE)
  paidAt: String           // always "YYYY-MM-28"
```

```
ComplaintResponse
  id: String
  type: String
  complainantId: String
  complainantName: String
  againstId: String
  againstName: String
  category: String
  priority: String          // "Normal" default — TITLE CASE, free-form
  status: String            // "Open" default — TITLE CASE, free-form
  description: String
  bookingId: String?
  evidenceUrls: String?     // COMMA-SEPARATED url list
  preferredOutcome: String?
  assignee: String?
  adminNotes: String?
  source: String?           // CaseSource enum, nullable in the model
  refundId: String?
  createdAt: DateTime
  updatedAt: DateTime
ComplaintListResponse { items: List<ComplaintResponse>, total: int }   // `items`!

IncidentItem               // untyped, GET /admin/incidents
  id, type, category, description, status, priority,
  complainantId, againstId: String
  createdAt: String        // ISO STRING, "" when null
```

```
PackageResponse
  id: String
  name: String
  tag: String
  icon: String              // "Brain" default
  price: int                // INT, not double
  cadence: String
  blurb: String
  points: List<String>
  featured: bool
  sortOrder: int
  isActive: bool
  createdAt: DateTime
  updatedAt: DateTime
PackageListResponse { packages: List<PackageResponse>, total: int }

ClinicResponse
  id: String
  name: String
  area: String
  city: String
  address: String
  services: List<String>    // real array (Postgres String[])
  phone: String
  hours: String
  createdAt: DateTime
  updatedAt: DateTime
ClinicListResponse { clinics: List<ClinicResponse>, total: int }

ServiceResponse
  id: String
  name: String
  description: String
  category: String          // ServiceCategory enum
  iconName: String          // "" default
  isActive: bool
  sortOrder: int
                            // NO createdAt / updatedAt
ServiceListResponse { services: List<ServiceResponse>, total: int }
```

```
Currency       { code: String, name: String, flag: String, symbol: String, rate: double }
PaymentMethod  { id: String, label: String, icon: String, type: String, subtype: String? }
UploadedFile   { url: String, fileName: String, fileSize: int }   // public upload endpoints
```

# Request models — exact JSON field names

```
SignupRequest
  name: String, email: String, password: String?, role: String = "PATIENT",
  city: String?, phone: String?, specialty: String?, gender: String?,
  license: String?, experience: int?, fee: double?, bio: String?,
  documents: List<VerificationDoc>?
VerificationDoc { documentType: String, url: String, fileName: String?, fileSize: int? }
  // NOTE: signup uses `fee`; the Therapist model/response uses `price`.

SessionCreate         { therapistId, date: DateTime, time, type = "HOME_VISIT",
                        address, fee: double, notes: String? }
SessionUpdate         { status?, date?: DateTime, time?, notes? }
RescheduleRequest     { newDate: String /*date*/, newTime: String /*time*/ }

BookingPaymentRequest { therapistId, date: DateTime, time, type = "HOME_VISIT",
                        address, fee: double, notes: String?, currency = "NPR",
                        paymentMethod = "CASH", paymentType: String?,
                        platformFee: double = 0, transactionRef: String?,
                        cardLast4: String? (max 4), walletMobile: String?,
                        billingCountry: String? }
PaymentCreate         { amount: double, method = "CASH", sessionId: String?,
                        currency = "NPR", platformFee: double = 0, paymentType: String?,
                        transactionRef: String?, cardLast4: String?,
                        walletMobile: String?, billingCountry: String? }

ReviewCreate          { sessionId: String, rating: int (1..5), comment: String? }
CartItemCreate        { productId, type = "BUY", quantity = 1, rentalDays = 7 }
CartItemUpdate        { quantity?: int, rentalDays?: int, type?: String }
ComplaintCreate       { type, complainantId, complainantName, againstId, againstName,
                        category, priority = "Normal", description, bookingId?,
                        evidenceUrls?, preferredOutcome? }
AssignRequest         { assigneeId: String }
```

# Enums

Prisma enums. Values are exact — the API emits and accepts these strings verbatim.

| Enum | Values |
|---|---|
| `Role` | `PATIENT`, `THERAPIST`, `ADMIN` |
| `UserStatus` | `PENDING`, `APPROVED`, `REJECTED` |
| `SessionStatus` | `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`, `RESCHEDULE_REQUESTED`, `DECLINE_REQUESTED` |
| `SessionType` | `HOME_VISIT`, `CLINIC` |
| `ProductCategory` | `EQUIPMENT`, `MEDICINE`, `NUTRITION` |
| `CartItemType` | `BUY`, `RENT`, `MEDICINE`, `NUTRITION` |
| `ServiceCategory` | `CLINICAL`, `SHOP` |
| `CaseSource` | `PATIENT_SUBMITTED`, `THERAPIST_SUBMITTED`, `ADMIN_MANUAL` |
| `RefundReason` | `NO_SHOW`, `DOUBLE_CHARGE`, `SERVICE_QUALITY`, `CANCELLATION` |
| `RefundStatus` | `PENDING`, `APPROVED`, `DENIED` |

**Not** DB enums — plain strings, so parse defensively:

| Field | Observed values |
|---|---|
| `AvailabilitySlot.status` / `SlotInfo.status` | `open` (default), `booked`, `off` — **lowercase** |
| `Payment.status` | `PENDING` (default), `COMPLETED` |
| `Payment.method` | uppercased client string (`CASH`, `ESEWA`, `KHALTI`, `CARD`, …) |
| `Complaint.status` | `Open` (default), `Escalated`, `Resolved` — **title case** |
| `Complaint.priority` | `Normal` (default) — title case |
| `Verification.status` | `Pending review` (default) — title case with a space |
| `ScheduleBlockRequest.status` | `PENDING`, `APPROVED`, `REJECTED` |
| `PayoutItem.status` | `Completed`, `Pending` — title case |
| `PatientProfile.gender` | `Any` (default), `Male`, `Female` — validated on write |
| `PatientProfile.city` | `Kathmandu`, `Lalitpur`, `Bhaktapur`, `Pokhara`, `Chitwan`, `Biratnagar` — validated on write |
| `daysOfWeek` entries | `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun` |

<a name="gotchas-for-the-flutter-client"></a>
# Gotchas for the Flutter client

**Casing inconsistencies**

- Bodies are camelCase **except** the auth models: `access_token`, `token_type`, `resend_after`, `current_password`, `new_password`. Do **not** apply a global camelCase JSON key strategy — it will silently null out the token.
- Query params are snake_case (`from_date`, `to_date`, `patient_id`, `therapist_id`, `new_status`) **except** on `GET /admin/complaints`, which uses camelCase (`complainantId`, `sortBy`, `sortOrder`).
- Mixed date typing: `dob`, `createdAt`/`updatedAt` on `PatientProfileResponse`, `RecurringPatternResponse`, `BlockInfoResponse`, `AuditLogEntryResponse`, `TherapistReportItem` and every untyped dict endpoint are **ISO strings**; on `TherapistResponse`, `SessionResponse`, `ReviewResponse`, `PaymentResponse`, `ProductResponse`, `CartItemResponse`, `ReportResponse`, `ComplaintResponse`, `PackageResponse`, `ClinicResponse` they are real datetimes. Use a converter that accepts both.
- List wrapper keys are per-domain (`therapists`, `sessions`, `reviews`, `payments`, `products`, `packages`, `clinics`, `services`, `patterns`, `entries`) — **only complaints and incidents use `items`**.
- `TherapistCreate`/`TherapistResponse` say `price`; `SignupRequest` says `fee`; `SessionCreate`/`SessionResponse` say `fee`. Same concept, three names.

**Bare arrays / missing wrappers (a `total`-shaped model will crash)**

- `GET /reports` → bare `[ReportResponse]`
- `GET /reviews/therapists-to-rate` → bare `[TherapistToRate]`
- `GET /availability/working-days` → bare `["Mon", …]`
- `GET /availability/block-requests` → bare array, **and the element shape differs between THERAPIST and ADMIN**
- `GET /availability/recurring` → `{patterns: […]}` with **no `total`**

**204 / null-body endpoints** — never try to decode these: `DELETE /therapists/{id}`, `DELETE /sessions/{id}`, `POST /availability/slot`, `POST /availability/unblock`, `PUT`+`DELETE /availability/recurring/{id}`, `DELETE /availability/audit-log/{id}`, `DELETE /cart/{id}`, `DELETE /cart`, `DELETE /products|packages|clinics|services|reports/{id}`, `POST /auth/reset-password`, `POST /auth/change-password`, `POST /auth/logout`.
Also null-valued but **200**: `GET /settings/design-tokens` returns `{"tokens": null}` when unset.

**Nullable fields that look required**

- `TokenResponse.access_token` is `String?` — **null on THERAPIST signup**. Branch on it instead of asserting.
- `UserResponse.photo`, `.city`, `.phone`, `.specialty` are all nullable.
- `TherapistProfileResponse.documents` is a **nullable list**, and `mediaUrls`/`photo` are nullable.
- `AuditLogEntryResponse.time` has no default — the key is always present but the value is often `null`.
- `PatientDashboardResponse.nextSession` is null for a patient with no upcoming booking.
- `SlotInfo.fee` and `.sessionId` are null on unbooked slots.
- `ComplaintResponse.source` is nullable in the response model even though the DB column is non-null.
- `PatientProfileResponse.age` is null whenever `dob` is null.

**"Never null but often empty"** — `SessionResponse.therapistName`, `.patientName`, `.patientPhone`, `SlotInfo.patientName/.patientPhone/.sessionType`, `TherapistProfileResponse.phone`, `ProductResponse.emoji`, and the `MyPatientItem`/`TransactionItem` string fields all default to `""`, not `null`. Treat `""` as "missing" in the UI.

**Comma-separated strings pretending to be lists** — `Therapist.mediaUrls`, `Report.fileUrl`, `Complaint.evidenceUrls`. Split on `,` and trim. `mediaUrls[0]` is the avatar. Report/therapist file URLs additionally carry `?name=…&size=…` query strings that must be preserved.

**Responses that don't match their endpoint name**

- `GET /reviews` returns the caller's *authored* reviews (`patientId == me`) — a therapist gets `[]`, not their received reviews.
- `GET /reports/therapist` returns `TherapistReportItem`, a different shape from `ReportResponse`.
- `CartResponse.total` is the **subtotal**; `grandTotal` is what to charge.
- `TherapistResponse.reviews` is an **int count**, not a list.
- `/therapist/earnings/*` (singular prefix) `TransactionItem.id` is the **session** id.
- `GET /admin/incidents` is the Complaint table under a different projection.
- `GET /availability/block-requests` returns pending-only for ADMIN, all-of-mine (max 20) for THERAPIST.

**Auth and status-code surprises**

- Missing `Authorization` header → **403**, not 401 (FastAPI `HTTPBearer`). Invalid/expired token → 401. Handle both as "log out".
- A THERAPIST whose status drops from `APPROVED` gets **401** on every authenticated route (`"Your account is pending approval"`) — indistinguishable from an expired token unless you read `detail`.
- Login for a non-approved therapist → **403**, not 401.
- `GET /payments/{id}` and `GET /reports/{id}` return **404 instead of 403** for someone else's record.
- `GET /sessions/{id}` performs **no ownership check at all**.
- `PUT /availability/block-requests/{id}/approve|reject` returns **200 `{success:false, error:"Request not found"}`** instead of 404.
- `/therapist/earnings/*` return **200 with empty lists** for a non-therapist instead of 403.
- `GET /uploads/{patient_id}/{filename}` authenticates via **`?token=` query param only** — the bearer header is ignored. Every other file-serving route uses the header.
- `PUT /payments/{id}/status` takes `new_status` as a **query param**, not a body.
- `POST /reports` accepts **multipart only**; a JSON body is a hard 400.
- `POST /admin/complaints` does **not** derive `complainantId` from the token — you must send it, and a client could spoof it.
- `POST /reviews` can 409 for two different reasons; the second (`"You have already reviewed this therapist"`) is easy to miss because it fires even for a brand-new session.
- Pagination is inconsistent: most lists use `skip`/`limit` (limit ≤ 200), `/admin/complaints` and `/patients/my-patients` default `limit=10`, `/availability/audit-log` uses `offset`/`limit` with `limit=5`, and `/therapist/earnings/*` use `page`/`limit`.
- `POST /availability/audit-log` returns **200**, not 201, unlike every other create.
- `DELETE /uploads/therapists/{id}/photo` returns **200 with a body**, unlike every other DELETE.
- Rate limiting is Redis-backed and fail-open; a **429** carries `detail` with the retry delay for `/auth/send-otp` and `/auth/forgot-password`.
