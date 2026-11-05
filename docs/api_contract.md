# Sahayatri Physio API Contract

## Base URL

All endpoints are prefixed with `/api/v1`.

**Base URL (dev):** `http://localhost:8000/api/v1`
**Base URL (staging):** `https://staging-api.sahayatri.np/api/v1`
**Base URL (prod):** `https://api.sahayatri.np/api/v1`

**Health check:** `GET /health` → `{"status": "ok"}`

---

## Authentication

**Mechanism:** JWT Bearer tokens (OAuth2 Password flow via FastAPI's `HTTPBearer`)

- Access token is a JWT (HS256) containing `sub` (user ID) and `exp` (expiry).
- Token expiry: 1440 minutes (24 hours) — configured via `ACCESS_TOKEN_EXPIRE_MINUTES` env var.
- No refresh token endpoint exists. The current implementation returns a single `access_token` on login/signup.
  - **Assumption for Flutter:** The mobile app should handle token expiry by storing credentials and re-logging in silently, or the backend should be extended with a `/auth/refresh` endpoint. For now, the Flutter app will store both the token and the last known email/password for silent re-auth.
- Token is sent as `Authorization: Bearer <token>` header.
- The `logout` endpoint returns 204 — the client should discard the token locally.

### Signup
```
POST /api/v1/auth/signup
Content-Type: application/json

{
  "name": "string",
  "email": "user@example.com",
  "password": "string",
  "role": "PATIENT | THERAPIST",
  "city": "string | null",
  "phone": "string | null",
  "specialty": "string | null"
}

Response 201:
{
  "access_token": "jwt-string",
  "token_type": "bearer",
  "user": { ... UserResponse }
}
```

### Login
```
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "string"
}

Response 200:
{
  "access_token": "jwt-string",
  "token_type": "bearer",
  "user": { ... UserResponse }
}
```

### Get Current User
```
GET /api/v1/auth/me
Authorization: Bearer <token>

Response 200:
{
  "id": "cuid",
  "name": "string",
  "email": "string",
  "role": "PATIENT | THERAPIST | ADMIN",
  "city": "string | null",
  "phone": "string | null",
  "specialty": "string | null",
  "status": "PENDING | APPROVED | REJECTED"
}
```

### Logout
```
POST /api/v1/auth/logout
Authorization: Bearer <token>

Response: 204 No Content
```

---

## Therapists

### List Therapists (public)
```
GET /api/v1/therapists?skip=0&limit=100

Response 200:
{
  "therapists": [
    {
      "id": "cuid",
      "userId": "cuid",
      "name": "string",
      "specialty": "string",
      "city": "string",
      "gender": "string",
      "rating": 0.0,
      "reviews": 0,
      "price": 0.0,
      "experience": 0,
      "bio": "string",
      "createdAt": "datetime",
      "updatedAt": "datetime"
    }
  ],
  "total": 0
}
```

### Get My Therapist Profile (auth required, THERAPIST role)
```
GET /api/v1/therapists/me
Authorization: Bearer <token>

Response 200: TherapistResponse (same shape as above)
```

### Get Therapist by ID
```
GET /api/v1/therapists/{therapist_id}

Response 200: TherapistResponse
```

### Create Therapist Profile (auth required, THERAPIST role)
```
POST /api/v1/therapists
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "string",
  "specialty": "string",
  "city": "string",
  "gender": "string",
  "price": 0.0,
  "experience": 0,
  "bio": "string"
}

Response 201: TherapistResponse
```

### Update Therapist Profile
```
PUT /api/v1/therapists/{therapist_id}
Authorization: Bearer <token>

Response 200: TherapistResponse
```

### Delete Therapist Profile
```
DELETE /api/v1/therapists/{therapist_id}
Authorization: Bearer <token>

Response: 204 No Content
```

---

## Sessions

### Create/Book Session (PATIENT role required)
```
POST /api/v1/sessions
Authorization: Bearer <token>
Content-Type: application/json

{
  "therapistId": "cuid",
  "date": "2026-07-07T00:00:00Z",
  "time": "09:00",
  "type": "HOME_VISIT | CLINIC",
  "address": "string",
  "fee": 1500.0,
  "notes": "string | null"
}

Response 201:
{
  "id": "cuid",
  "therapistId": "cuid",
  "patientId": "cuid",
  "date": "datetime",
  "time": "string",
  "type": "HOME_VISIT",
  "status": "SCHEDULED",
  "address": "string",
  "fee": 1500.0,
  "notes": "string | null",
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

### List Sessions (auth required, role-aware)
```
GET /api/v1/sessions?skip=0&limit=100
Authorization: Bearer <token>

Response 200:
{
  "sessions": [SessionResponse],
  "total": 0
}
```

### Get Session by ID
```
GET /api/v1/sessions/{session_id}

Response 200: SessionResponse
```

### Update Session (PATIENT or ADMIN)
```
PUT /api/v1/sessions/{session_id}
Authorization: Bearer <token>

Response 200: SessionResponse
```

### Cancel/Delete Session (PATIENT or ADMIN)
```
DELETE /api/v1/sessions/{session_id}
Authorization: Bearer <token>

Response: 204 No Content
```

---

## Products

### List Products (public)
```
GET /api/v1/products?category=EQUIPMENT|MEDICINE|NUTRITION&skip=0&limit=100

Response 200:
{
  "products": [
    {
      "id": "cuid",
      "name": "string",
      "category": "EQUIPMENT | MEDICINE | NUTRITION",
      "price": 0.0,
      "rentPerDay": 0.0,
      "inStock": 0,
      "emoji": "",
      "description": "string | null",
      "imageUrl": "string | null",
      "createdAt": "datetime",
      "updatedAt": "datetime"
    }
  ],
  "total": 0
}
```

### Get Product by ID
```
GET /api/v1/products/{product_id}

Response 200: ProductResponse
```

### Create Product (ADMIN only)
```
POST /api/v1/products
Authorization: Bearer <token>

Response 201: ProductResponse
```

### Update Product (ADMIN only)
```
PUT /api/v1/products/{product_id}
Authorization: Bearer <token>

Response 200: ProductResponse
```

### Delete Product (ADMIN only)
```
DELETE /api/v1/products/{product_id}
Authorization: Bearer <token>

Response: 204 No Content
```

---

## Cart

### Get My Cart
```
GET /api/v1/cart
Authorization: Bearer <token>

Response 200:
{
  "items": [
    {
      "id": "cuid",
      "userId": "cuid",
      "productId": "cuid",
      "product": { ProductResponse },
      "type": "BUY | RENT | MEDICINE | NUTRITION",
      "quantity": 1,
      "rentalDays": 7,
      "createdAt": "datetime",
      "updatedAt": "datetime"
    }
  ],
  "total": 0.0,
  "deliveryFee": 150.0,
  "grandTotal": 0.0
}
```

### Add Item to Cart
```
POST /api/v1/cart
Authorization: Bearer <token>
Content-Type: application/json

{
  "productId": "cuid",
  "type": "BUY | RENT | MEDICINE | NUTRITION",
  "quantity": 1,
  "rentalDays": 7
}

Response 201: CartItemResponse
```

### Update Cart Item
```
PUT /api/v1/cart/{item_id}
Authorization: Bearer <token>

Response 200: CartItemResponse
```

### Remove Cart Item
```
DELETE /api/v1/cart/{item_id}
Authorization: Bearer <token>

Response: 204 No Content
```

### Clear Cart
```
DELETE /api/v1/cart
Authorization: Bearer <token>

Response: 204 No Content
```

---

## Payments

### Create Payment
```
POST /api/v1/payments
Authorization: Bearer <token>
Content-Type: application/json

{
  "amount": 1500.0,
  "method": "CASH | ESEWA | KHALTI",
  "sessionId": "cuid | null"
}

Response 201:
{
  "id": "cuid",
  "userId": "cuid",
  "amount": 1500.0,
  "status": "PENDING",
  "method": "CASH",
  "sessionId": "cuid | null",
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

### List Payments (user's own or all for ADMIN)
```
GET /api/v1/payments?skip=0&limit=100
Authorization: Bearer <token>

Response 200:
{
  "payments": [PaymentResponse],
  "total": 0.0
}
```

### Get Payment by ID
```
GET /api/v1/payments/{payment_id}

Response 200: PaymentResponse
```

### Update Payment Status (ADMIN only)
```
PUT /api/v1/payments/{payment_id}/status?status=COMPLETED

Response 200: PaymentResponse
```

---

## Reports

### Create Report (THERAPIST or ADMIN)
```
POST /api/v1/reports
Authorization: Bearer <token>
Content-Type: application/json

{
  "patientId": "cuid",
  "sessionId": "cuid | null",
  "title": "string",
  "content": "string",
  "fileUrl": "string | null"
}

Response 201:
{
  "id": "cuid",
  "patientId": "cuid",
  "sessionId": "cuid | null",
  "title": "string",
  "content": "string",
  "fileUrl": "string | null",
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

### List Reports (role-aware)
```
GET /api/v1/reports?patient_id=cuid&skip=0&limit=100
Authorization: Bearer <token>

Response 200: [ReportResponse]
```

### Get Report by ID
```
GET /api/v1/reports/{report_id}

Response 200: ReportResponse
```

### Update Report (THERAPIST or ADMIN)
```
PUT /api/v1/reports/{report_id}
Authorization: Bearer <token>

Response 200: ReportResponse
```

### Delete Report (THERAPIST or ADMIN)
```
DELETE /api/v1/reports/{report_id}
Authorization: Bearer <token>

Response: 204 No Content
```

---

## Admin Endpoints

### List Users (ADMIN only)
```
GET /api/v1/admin/users?role=PATIENT|THERAPIST&skip=0&limit=100
Authorization: Bearer <token>

Response 200: [UserResponse]
```

### Update User Status (ADMIN only)
```
PUT /api/v1/admin/users/{user_id}/status?status=APPROVED|REJECTED
Authorization: Bearer <token>

Response 200: UserResponse
```

### List All Payments (ADMIN only)
```
GET /api/v1/admin/payments?skip=0&limit=100
Authorization: Bearer <token>

Response 200: PaymentListResponse
```

### List All Sessions (ADMIN only)
```
GET /api/v1/admin/sessions?skip=0&limit=100
Authorization: Bearer <token>

Response 200: SessionListResponse
```

### List Pending Therapists (ADMIN only)
```
GET /api/v1/admin/therapists/pending
Authorization: Bearer <token>

Response 200: [UserResponse] (users with role=THERAPIST, status=PENDING)
```

---

## Data Models (Prisma → Dart DTOs)

All backend models use Prisma ORM with PostgreSQL. Fields are in **snake_case** on the wire (Pydantic serialization). Dart DTOs should use `@JsonKey(name: 'snake_case_field')` or global `FieldRename.snake` in `build.yaml`.

### Enums

```dart
enum UserRole { patient, therapist, admin }
enum UserStatus { pending, approved, rejected }
enum SessionStatus { scheduled, inProgress, completed, cancelled }
enum SessionType { homeVisit, clinic }
enum ProductCategory { equipment, medicine, nutrition }
enum CartItemType { buy, rent, medicine, nutrition }
enum PaymentMethod { cash, esewa, khalti }
```

### Assumptions & Ambiguities

1. **No refresh token endpoint** — The backend only issues access tokens. The Flutter app will:
   - Store token in `flutter_secure_storage`
   - On 401, attempt a single re-login using stored credentials
   - If re-login fails, clear auth state and redirect to login

2. **Therapist profile creation** — The signup endpoint creates a `User` record; a separate `POST /therapists` creates the `Therapist` profile. This two-step process is preserved in the Flutter app.

3. **Therapist list is public** — `GET /therapists` does not require auth. Filtering by specialty/city is not implemented on the backend — will be done client-side.

4. **Cart delivery fee** — `deliveryFee = 0 if subtotal >= 2000 else 150`. This is computed server-side.

5. **No pagination cursor** — Uses `skip`/`limit` offset pagination everywhere.

6. **Date/time format** — Backend uses ISO 8601 `datetime` for full dates and string `"HH:MM"` for time slots.

7. **Product inStock** — An integer count, not a boolean. `inStock > 0` means available.

8. **Availability is per-therapist only — there is no "who is free at T?"** Verified against the live OpenAPI document, not inferred. The only two availability reads are
   `GET /availability/slots?from_date&to_date&therapist_id=` and
   `GET /therapists/{therapist_id}/slots?from_date&to_date`, and both answer for exactly one therapist. **Both require auth** despite `/therapists` itself being public — a prefix rule that assumes otherwise breaks the booking calendar.

   `GET /therapists` takes `search`, `city`, `specialty`, `gender`, `skip`, `limit` and nothing else: **no availability filter of any kind.**

   So "show me everyone free on Thursday afternoon" is N requests. `AvailabilityRepository` (`lib/features/patient/domain/repositories/availability_repository.dart`) is shaped as the plural question — many therapists in, one result each out — and hides the fan-out, a four-request concurrency ceiling and a per-(therapist, window) cache behind that seam. **The thing to change on the API side** is either a `therapist_ids` list parameter on `/availability/slots`, or `available_on` / `available_from` / `available_to` filters on `/therapists`. Either one turns the client fan-out into a single call and only `AvailabilityRepositoryImpl` changes.

9. **A slot with no row is open.** `GET .../slots` synthesises the grid from the therapist's working hours (default 09:00–17:00, `sessionDuration + breakDuration` apart) and only then overlays stored `AvailabilitySlot` rows, so a therapist who has never touched their calendar comes back **fully `open`** — availability is opt-out, not opt-in. Statuses are `open`, `booked` and `off`.

10. **`blocks` is returned beside the slots, not folded into them** — and `block_range` only writes `off` onto `AvailabilitySlot` rows that **already exist**. A therapist who has never edited their calendar and then books leave therefore still reads `open` for those days; the leave shows up only in the separate `blocks` array. Every mobile screen ignores `blocks` (the profile slot picker always has, and the discovery features added on top of it follow suit), so all of them can over-promise in that one case. Folding blocks in client-side would mean duplicating the server's day-of-week and part-of-day expansion and would still leave the two clients free to disagree — **the fix belongs in `get_slots_for_range`**, which should apply blocks to the synthesised grid the same way it applies rows.
