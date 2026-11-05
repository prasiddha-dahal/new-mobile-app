#!/usr/bin/env python3
"""A tiny stand-in for pv-core-api, for UI work when the real API is unavailable.

Why this exists: the hosted API (pvc-api-z7pn.onrender.com) is suspended, and the
local `docker compose up` path needs Docker, which is not always available. This
server implements just enough of the contract in `docs/API_CONTRACT_REF.md` to
drive the app's screens with realistic data.

It is a **development fixture, not a backend**: state lives in memory, passwords
are not checked beyond the seeded set, and nothing is persisted. Never point a
release build at it.

Run:
    python tool/mock_api.py            # serves on 0.0.0.0:8000

Then, for the Android emulator (the host is 10.0.2.2 from inside the VM):
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

or for Chrome:
    flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

Seeded logins (any password works, matching SEEDDATA.md):
    patient@test.com · therapist@test.com · admin@test.com
"""

from __future__ import annotations

import json
import re
import uuid
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PREFIX = "/api/v1"
PORT = 8000

# --- Seed data ---------------------------------------------------------------

USERS = {
    "patient@test.com": {
        "id": "usr_patient_001",
        "name": "Aakar Sharma",
        "email": "patient@test.com",
        "role": "PATIENT",
        "city": "Jhamsikhel, Lalitpur",
        "phone": "+977 9801234521",
        "specialty": None,
        "status": "APPROVED",
        "photo": None,
        "mustChangePassword": False,
    },
    "therapist@test.com": {
        "id": "usr_therapist_001",
        "name": "Dr. Anisha Shrestha",
        "email": "therapist@test.com",
        "role": "THERAPIST",
        "city": "Lalitpur",
        "phone": "+977 9801234522",
        "specialty": "Sports & post-surgery",
        "status": "APPROVED",
        "photo": None,
        "mustChangePassword": False,
    },
    "pending@test.com": {
        "id": "usr_therapist_002",
        "name": "Dr. Kiran Adhikari",
        "email": "pending@test.com",
        "role": "THERAPIST",
        "city": "Kathmandu",
        "specialty": "Neuro rehab",
        "phone": "+977 9801234523",
        "status": "PENDING",
        "photo": None,
        "mustChangePassword": False,
    },
}

THERAPISTS = [
    {
        "id": "thp_001",
        "userId": "usr_therapist_001",
        "name": "Anisha Shrestha",
        "specialty": "Sports & post-surgery",
        "city": "Lalitpur",
        "gender": "Female",
        "rating": 4.9,
        "reviews": 182,
        "price": 1500.0,
        "experience": 6,
        "bio": "BPT, IOM (2018). 182+ home sessions across Lalitpur. Specialises "
               "in post-operative recovery and sports rehabilitation, with a "
               "manual-therapy and exercise-based approach.",
    },
    {
        "id": "thp_002",
        "userId": "usr_therapist_003",
        "name": "Bibek Rai",
        "specialty": "Neuro rehab",
        "city": "Kathmandu",
        "gender": "Male",
        "rating": 4.8,
        "reviews": 144,
        "price": 1800.0,
        "experience": 9,
        "bio": "Neurological rehabilitation specialist working with stroke and "
               "spinal-cord recovery. Gait retraining and balance work.",
    },
    {
        "id": "thp_003",
        "userId": "usr_therapist_004",
        "name": "Sunita Gurung",
        "specialty": "Pediatric",
        "city": "Bhaktapur",
        "gender": "Female",
        "rating": 4.9,
        "reviews": 98,
        "price": 1600.0,
        "experience": 5,
        "bio": "Paediatric physiotherapist focused on developmental delay and "
               "post-surgical recovery in children.",
    },
    {
        "id": "thp_004",
        "userId": "usr_therapist_005",
        "name": "Rajan Thapa",
        "specialty": "Geriatric",
        "city": "Pokhara",
        "gender": "Male",
        "rating": 4.7,
        "reviews": 211,
        "price": 1400.0,
        "experience": 12,
        "bio": "Geriatric care, fall prevention and mobility maintenance for "
               "older adults at home.",
    },
    {
        "id": "thp_005",
        "userId": "usr_therapist_006",
        "name": "Prakash Lama",
        "specialty": "Musculoskeletal",
        "city": "Kathmandu",
        "gender": "Male",
        "rating": 0.0,
        "reviews": 0,
        "price": 1300.0,
        "experience": 3,
        "bio": "Musculoskeletal and posture correction. Recently joined Sahayatri.",
    },
]

SLOT_TIMES = ["08:00", "09:00", "10:00", "11:00", "13:00", "14:00",
              "15:00", "16:00", "17:00", "18:00", "19:00", "20:00"]


def _iso(dt: datetime) -> str:
    return dt.replace(microsecond=0).isoformat()


def _seed_sessions() -> list[dict]:
    now = datetime.now(timezone.utc)
    return [
        _session(
            "ses_001", "thp_001", "Anisha Shrestha",
            now + timedelta(days=1), "09:00", "SCHEDULED", 1500.0,
            "Kupondole Heights, Lalitpur — 4th floor, blue gate",
        ),
        _session(
            "ses_002", "thp_002", "Bibek Rai",
            now + timedelta(days=4), "16:00", "SCHEDULED", 1800.0,
            "Baluwatar, Kathmandu",
        ),
        _session(
            "ses_003", "thp_001", "Anisha Shrestha",
            now - timedelta(days=4), "09:00", "COMPLETED", 1500.0,
            "Kupondole Heights, Lalitpur",
        ),
        _session(
            "ses_004", "thp_001", "Anisha Shrestha",
            now - timedelta(days=11), "09:00", "COMPLETED", 1500.0,
            "Kupondole Heights, Lalitpur",
        ),
        _session(
            "ses_005", "thp_003", "Sunita Gurung",
            now - timedelta(days=18), "11:00", "CANCELLED", 1600.0,
            "Suryabinayak, Bhaktapur",
        ),
    ]


def _session(sid, therapist_id, therapist_name, date, time, status, fee, address):
    return {
        "id": sid,
        "therapistId": therapist_id,
        "therapistName": therapist_name,
        "patientId": "usr_patient_001",
        "patientName": "",
        "patientPhone": "",
        "date": _iso(date),
        "time": time,
        "type": "HOME_VISIT",
        "status": status,
        "address": address,
        "fee": fee,
        "notes": None,
        "createdAt": _iso(datetime.now(timezone.utc)),
        "updatedAt": _iso(datetime.now(timezone.utc)),
    }


PRODUCTS = [
    {"id": "prd_001", "name": "TENS unit", "category": "EQUIPMENT",
     "price": 7500.0, "rentPerDay": 250.0, "inStock": 12, "emoji": "⚡",
     "description": "Pain relief electrotherapy", "imageUrl": None},
    {"id": "prd_002", "name": "Walking frame", "category": "EQUIPMENT",
     "price": 4200.0, "rentPerDay": 120.0, "inStock": 8, "emoji": "🦯",
     "description": "Foldable aluminium", "imageUrl": None},
    {"id": "prd_003", "name": "Knee CPM machine", "category": "EQUIPMENT",
     "price": 42000.0, "rentPerDay": 600.0, "inStock": 0, "emoji": "🦵",
     "description": "Continuous passive motion", "imageUrl": None},
    {"id": "prd_004", "name": "Pain relief gel", "category": "MEDICINE",
     "price": 320.0, "rentPerDay": 0.0, "inStock": 40, "emoji": "💊",
     "description": "Diclofenac 30g", "imageUrl": None},
    {"id": "prd_005", "name": "Kinesio tape", "category": "MEDICINE",
     "price": 450.0, "rentPerDay": 0.0, "inStock": 25, "emoji": "🩹",
     "description": "5cm × 5m roll", "imageUrl": None},
    {"id": "prd_006", "name": "Whey protein", "category": "NUTRITION",
     "price": 3200.0, "rentPerDay": 0.0, "inStock": 15, "emoji": "🥛",
     "description": "Recovery support, 1kg", "imageUrl": None},
]

CART: list[dict] = []

MY_PATIENTS = [
    {"id": "usr_patient_001", "name": "Pranita K.", "phone": "+977 9801111101",
     "condition": "Lower back pain", "sessions": 4,
     "last": _iso(datetime.now(timezone.utc)), "notes": ""},
    {"id": "usr_patient_002", "name": "Rajesh B.", "phone": "+977 9801111102",
     "condition": "Post-knee surgery", "sessions": 7,
     "last": _iso(datetime.now(timezone.utc)), "notes": ""},
    {"id": "usr_patient_003", "name": "Maya T.", "phone": "+977 9801111103",
     "condition": "Frozen shoulder", "sessions": 3,
     "last": _iso(datetime.now(timezone.utc) - timedelta(days=1)), "notes": ""},
    {"id": "usr_patient_004", "name": "Bipul S.", "phone": "+977 9801111104",
     "condition": "Sports injury", "sessions": 2,
     "last": _iso(datetime.now(timezone.utc) - timedelta(days=3)), "notes": ""},
]

PAYOUTS = [
    {"id": "payout-2026-07", "month": "2026-07", "earnings": 72000.0,
     "sessions": 48, "status": "Completed", "paidAt": "2026-07-28"},
    {"id": "payout-2026-08", "month": "2026-08", "earnings": 18000.0,
     "sessions": 12, "status": "Pending", "paidAt": "2026-08-28"},
]

BLOCK_REQUESTS: list[dict] = [
    {"id": "blk_seed01", "dateFrom": "2026-06-12", "dateTo": "2026-06-12",
     "daysOfWeek": [], "partsOfDay": ["Morning", "Afternoon", "Evening"],
     "reason": "Family", "status": "approved", "adminNotes": None,
     "createdAt": "2026-06-10T09:00:00+00:00"},
]

CLINICS = [
    {"id": "cln_001", "name": "Sahayatri Physio Centre — Pulchowk",
     "area": "Pulchowk", "city": "Lalitpur",
     "address": "Pulchowk Road, opposite Labim Mall, Lalitpur",
     "services": "Sports rehab, Manual therapy, Post-op care",
     "phone": "+977 9801234501", "hours": "Sun-Fri 7:00-19:00"},
    {"id": "cln_002", "name": "Kathmandu Rehab Clinic",
     "area": "Baluwatar", "city": "Kathmandu",
     "address": "Baluwatar Marg 12, Kathmandu",
     "services": "Neuro rehab, Gait training, Hydrotherapy",
     "phone": "+977 9801234502", "hours": "Sun-Sat 8:00-20:00"},
    {"id": "cln_003", "name": "Bhaktapur Family Physio",
     "area": "Suryabinayak", "city": "Bhaktapur",
     "address": "Suryabinayak Chowk, Bhaktapur",
     "services": "Pediatric, Geriatric, Posture correction",
     "phone": "+977 9801234503", "hours": "Sun-Fri 8:00-18:00"},
]

PACKAGES = [
    {"id": "pkg_001", "name": "Knee Replacement Therapy", "tag": "Orthopedic",
     "icon": "Bone", "price": 4500, "cadence": "1 week",
     "blurb": "Post-surgery physiotherapy designed to improve mobility, "
              "strength and recovery.",
     "points": ["6 home sessions", "Guided exercise plan", "Progress review"],
     "featured": True, "sortOrder": 1, "isActive": True},
    {"id": "pkg_002", "name": "Stroke Therapy", "tag": "Neurological",
     "icon": "Brain", "price": 17000, "cadence": "1 month",
     "blurb": "Neuro rehabilitation to regain movement, balance and daily "
              "independence after a stroke.",
     "points": ["20 home sessions", "Gait and balance work",
                "Family training session"],
     "featured": False, "sortOrder": 2, "isActive": True},
    {"id": "pkg_003", "name": "ACL & Ligament Injury Therapy",
     "tag": "Sports Injury", "icon": "Activity", "price": 5400,
     "cadence": "10 days",
     "blurb": "Return-to-play rehabilitation for ligament tears, sprains and "
              "overuse injuries.",
     "points": ["8 sessions", "Strength testing", "Return-to-sport clearance"],
     "featured": False, "sortOrder": 3, "isActive": True},
]


def _cart_payload() -> dict:
    """Mirrors CartResponse: `total` is the subtotal, delivery is free at 2000+."""
    items = []
    subtotal = 0.0
    for line in CART:
        product = next((p for p in PRODUCTS if p["id"] == line["productId"]), None)
        if product is None:
            continue
        if line["type"] == "RENT":
            line_total = product["rentPerDay"] * line["quantity"] * line["rentalDays"]
        else:
            line_total = product["price"] * line["quantity"]
        subtotal += line_total
        items.append({**line, "product": product, "userId": "usr_patient_001"})
    delivery = 0.0 if subtotal >= 2000 else 150.0
    return {
        "items": items,
        "total": subtotal,
        "deliveryFee": delivery,
        "grandTotal": subtotal + delivery,
    }


SESSIONS: list[dict] = _seed_sessions()
TOKENS: dict[str, str] = {}       # token -> user email
OTP_CODE = "123456"               # every mock OTP accepts this


def _slots_for(therapist_id: str, from_date: str, to_date: str) -> list[dict]:
    """Open slots for the next fortnight, with a deterministic mix of states."""
    try:
        start = datetime.fromisoformat(from_date)
        end = datetime.fromisoformat(to_date)
    except ValueError:
        return []

    booked = {
        (s["date"][:10], s["time"])
        for s in SESSIONS
        if s["therapistId"] == therapist_id and s["status"] == "SCHEDULED"
    }

    slots = []
    day = start
    seed = sum(ord(c) for c in therapist_id)
    while day <= end:
        key = day.strftime("%Y-%m-%d")
        # Sundays off, so the grid is not uniformly open.
        if day.weekday() != 6:
            for i, time in enumerate(SLOT_TIMES):
                if (seed + i + day.day) % 5 == 0:
                    status = "off"
                elif (key, time) in booked:
                    status = "booked"
                else:
                    status = "open"
                slots.append({
                    "date": key,
                    "time": time,
                    "status": status,
                    "patientName": "",
                    "patientPhone": "",
                    "sessionType": "",
                    "fee": next(
                        (t["price"] for t in THERAPISTS if t["id"] == therapist_id),
                        1500.0,
                    ),
                    "sessionId": None,
                })
        day += timedelta(days=1)
    return slots


def _dashboard() -> dict:
    upcoming = [s for s in SESSIONS if s["status"] == "SCHEDULED"]
    upcoming.sort(key=lambda s: s["date"])
    completed = [s for s in SESSIONS if s["status"] == "COMPLETED"]
    nxt = upcoming[0] if upcoming else None
    return {
        "name": "Aakar Sharma",
        "totalSessions": len(SESSIONS),
        "completedSessions": len(completed),
        "upcomingSessions": len(upcoming),
        "nextSession": None if nxt is None else {
            "id": nxt["id"],
            "therapistName": nxt["therapistName"],
            "therapistId": nxt["therapistId"],
            "date": nxt["date"][:10],
            "time": nxt["time"],
            "type": nxt["type"],
            "status": nxt["status"],
        },
        "referralCode": "SAH-AAKAR-42",
        "referralLink": "https://sahayatri.np/r/SAH-AAKAR-42",
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    # --- plumbing ------------------------------------------------------------

    def log_message(self, fmt, *args):
        try:
            print(f"  {fmt % args}")
        except Exception:
            pass

    def _send(self, status: int, payload=None):
        body = b"" if payload is None else json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "*")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _error(self, status: int, detail: str):
        self._send(status, {"detail": detail})

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return {}

    def _user(self):
        auth = self.headers.get("Authorization", "")
        token = auth[7:] if auth.startswith("Bearer ") else ""
        email = TOKENS.get(token)
        return USERS.get(email) if email else None

    def do_OPTIONS(self):
        self._send(204)

    # --- routing -------------------------------------------------------------

    def do_GET(self):
        path, query = self._split()

        if path == "/health":
            return self._send(200, {"status": "ok", "mock": True})

        if path == f"{PREFIX}/auth/me":
            user = self._user()
            return self._send(200, user) if user else self._error(401, "Not authenticated")

        if path == f"{PREFIX}/therapists":
            search = (query.get("search", [""])[0] or "").lower()
            specialty = (query.get("specialty", [""])[0] or "").lower()
            items = [
                t for t in THERAPISTS
                if (not search or search in t["name"].lower()
                    or search in t["specialty"].lower()
                    or search in t["city"].lower())
                and (not specialty or specialty in t["specialty"].lower())
            ]
            return self._send(200, {"therapists": items, "total": len(items)})

        m = re.fullmatch(rf"{PREFIX}/therapists/([^/]+)/slots", path)
        if m:
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, {
                "slots": _slots_for(
                    m.group(1),
                    query.get("from_date", [""])[0],
                    query.get("to_date", [""])[0],
                ),
                "blocks": [],
            })

        m = re.fullmatch(rf"{PREFIX}/therapists/([^/]+)", path)
        if m:
            found = next((t for t in THERAPISTS if t["id"] == m.group(1)), None)
            return self._send(200, found) if found else self._error(404, "Therapist not found")

        if path == f"{PREFIX}/patients/me/dashboard":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, _dashboard())

        if path == f"{PREFIX}/therapists/me/dashboard":
            user = self._user()
            if not user or user["role"] != "THERAPIST":
                return self._error(403, "Therapist access required")
            today = datetime.now(timezone.utc).date().isoformat()
            todays = [
                {"id": s["id"], "time": s["time"], "patient": "Pranita K.",
                 "patientId": "usr_patient_001", "address": s["address"],
                 "type": s["type"], "status": s["status"]}
                for s in SESSIONS
                if s["date"][:10] == today and s["status"] == "SCHEDULED"
            ]
            completed = [s for s in SESSIONS if s["status"] == "COMPLETED"]
            return self._send(200, {
                "name": "Dr. Anisha Shrestha",
                "sessionsThisWeek": len(
                    [s for s in SESSIONS if s["status"] == "SCHEDULED"]),
                "totalPatients": len(MY_PATIENTS),
                "earningsThisMonth": sum(s["fee"] for s in completed),
                "averageRating": 4.9,
                "todaySessions": todays,
                "recentUploads": [],
                "publicProfile": {"name": "Anisha Shrestha",
                                  "specialty": "Sports & post-surgery",
                                  "experience": 6, "rating": 4.9,
                                  "totalReviews": 182},
                "recentRatings": [],
                "referralCode": "SAH-ANISHA-88",
                "referralLink": "https://sahayatri.np/r/SAH-ANISHA-88",
            })

        if path == f"{PREFIX}/therapists/me/profile":
            user = self._user()
            if not user or user["role"] != "THERAPIST":
                return self._error(403, "Therapist access required")
            t = THERAPISTS[0]
            return self._send(200, {
                "id": t["id"], "userId": t["userId"], "name": t["name"],
                "email": user["email"], "phone": user.get("phone") or "",
                "city": t["city"], "specialty": t["specialty"],
                "gender": t["gender"], "price": t["price"],
                "experience": t["experience"], "bio": t["bio"],
                "mediaUrls": None, "photo": None, "documents": [],
            })

        if path == f"{PREFIX}/patients/my-patients":
            user = self._user()
            if not user or user["role"] != "THERAPIST":
                return self._error(403, "Therapist access required")
            search = (query.get("search", [""])[0] or "").lower()
            items = [p for p in MY_PATIENTS
                     if not search or search in p["name"].lower()
                     or search in p["condition"].lower()]
            return self._send(200, {"patients": items, "total": len(items)})

        if path == f"{PREFIX}/availability/slots":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, {
                "slots": _slots_for("thp_001",
                                    query.get("from_date", [""])[0],
                                    query.get("to_date", [""])[0]),
                "blocks": [],
            })

        if path == f"{PREFIX}/availability/block-requests":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, BLOCK_REQUESTS)

        if path == f"{PREFIX}/therapist/earnings/transactions":
            if not self._user():
                return self._error(401, "Not authenticated")
            items = [
                {"id": s["id"], "patientName": "Pranita K.", "patientPhone": "",
                 "date": s["date"][:10], "time": s["time"], "type": s["type"],
                 "fee": s["fee"], "status": s["status"],
                 "paymentMethod": "ESEWA", "paymentStatus": "COMPLETED"}
                for s in SESSIONS if s["status"] == "COMPLETED"
            ]
            return self._send(200, {"transactions": items, "total": len(items),
                                    "page": 1, "limit": 50})

        if path == f"{PREFIX}/therapist/earnings/payouts":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, {"payouts": PAYOUTS, "total": len(PAYOUTS),
                                    "page": 1, "limit": 24})

        if path == f"{PREFIX}/clinics":
            search = (query.get("search", [""])[0] or "").lower()
            city = (query.get("city", [""])[0] or "").lower()
            items = [
                c for c in CLINICS
                if (not search or search in c["name"].lower()
                    or search in c["services"].lower()
                    or search in c["area"].lower())
                and (not city or city == c["city"].lower())
            ]
            return self._send(200, {"clinics": items, "total": len(items)})

        m = re.fullmatch(rf"{PREFIX}/clinics/([^/]+)", path)
        if m:
            found = next((c for c in CLINICS if c["id"] == m.group(1)), None)
            return self._send(200, found) if found else self._error(404, "Clinic not found")

        if path == f"{PREFIX}/packages":
            return self._send(200, {"packages": PACKAGES, "total": len(PACKAGES)})

        if path == f"{PREFIX}/reports":
            if not self._user():
                return self._error(401, "Not authenticated")
            # A bare array, matching the real endpoint.
            return self._send(200, [
                {"id": "rep_001", "patientId": "usr_patient_001",
                 "therapistId": "thp_001", "sessionId": "ses_003",
                 "title": "Session-notes-Jul-5.pdf",
                 "content": "Post-session notes and exercise adjustments.",
                 "fileUrl": "/uploads/usr_patient_001/session-notes.pdf",
                 "createdAt": _iso(datetime.now(timezone.utc) - timedelta(hours=4)),
                 "updatedAt": _iso(datetime.now(timezone.utc))},
                {"id": "rep_002", "patientId": "usr_patient_001",
                 "therapistId": "thp_001", "sessionId": None,
                 "title": "Home-exercise-plan.pdf",
                 "content": "Daily exercises for the next three weeks.",
                 "fileUrl": "/uploads/usr_patient_001/plan.pdf,/uploads/usr_patient_001/plan2.pdf",
                 "createdAt": _iso(datetime.now(timezone.utc) - timedelta(days=3)),
                 "updatedAt": _iso(datetime.now(timezone.utc))},
            ])

        if path == f"{PREFIX}/patients/me/referral":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, {
                "code": "SAHAYA-AK21",
                "link": "https://sahayatri.np/r/SAHAYA-AK21",
            })

        if path == f"{PREFIX}/products":
            category = (query.get("category", [""])[0] or "").upper()
            items = [p for p in PRODUCTS if not category or p["category"] == category]
            return self._send(200, {"products": items, "total": len(items)})

        if path == f"{PREFIX}/availability/recurring":
            if not self._user():
                return self._error(401, "Not authenticated")
            days = body.get("days") or []
            sessions = body.get("sessions") or []
            return self._send(200, {
                "affected": len(days) * len(sessions) * 2,
                "skippedPast": 0,
                "patternId": f"pat_{uuid.uuid4().hex[:8]}",
            })

        if path == f"{PREFIX}/availability/slot":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(204)

        if path == f"{PREFIX}/availability/block-request":
            if not self._user():
                return self._error(401, "Not authenticated")
            entry = {
                "id": f"blk_{uuid.uuid4().hex[:8]}",
                "dateFrom": body.get("dateFrom") or "",
                "dateTo": body.get("dateTo") or "",
                "daysOfWeek": body.get("daysOfWeek") or [],
                "partsOfDay": body.get("partsOfDay") or [],
                "reason": body.get("reason") or "Time off",
                "status": "pending",
                "adminNotes": None,
                "createdAt": _iso(datetime.now(timezone.utc)),
            }
            BLOCK_REQUESTS.insert(0, entry)
            return self._send(200, entry)

        if path == f"{PREFIX}/admin/complaints":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(201, {
                "id": f"cmp_{uuid.uuid4().hex[:8]}",
                "category": body.get("category") or "Other",
                "status": "Open",
                "description": body.get("description") or "",
            })

        if path == f"{PREFIX}/cart":
            if not self._user():
                return self._error(401, "Not authenticated")
            return self._send(200, _cart_payload())

        if path == f"{PREFIX}/sessions":
            user = self._user()
            if not user:
                return self._error(401, "Not authenticated")
            ordered = sorted(SESSIONS, key=lambda s: s["date"], reverse=True)
            # The real API only joins the patient relation on the THERAPIST
            # branch; patient and admin callers get empty strings.
            if user["role"] == "THERAPIST":
                names = ["Pranita K.", "Rajesh B.", "Maya T.", "Bipul S."]
                ordered = [
                    {**s, "patientName": names[i % len(names)],
                     "patientPhone": "+977 9801111101"}
                    for i, s in enumerate(ordered)
                ]
            return self._send(200, {"sessions": ordered, "total": len(ordered)})

        return self._error(404, f"Mock server has no route for GET {path}")

    def do_POST(self):
        path, _ = self._split()
        body = self._body()

        if path == f"{PREFIX}/auth/login":
            email = (body.get("email") or "").lower().strip()
            user = USERS.get(email)
            if not user:
                return self._error(401, "Invalid email or password")
            if user["role"] == "THERAPIST" and user["status"] != "APPROVED":
                return self._error(
                    403,
                    "Your application is under review. You will be able to log "
                    "in once it is approved.",
                )
            token = uuid.uuid4().hex
            TOKENS[token] = email
            return self._send(200, {
                "access_token": token, "token_type": "bearer", "user": user,
            })

        if path == f"{PREFIX}/auth/send-otp":
            email = (body.get("email") or "").lower().strip()
            if email in USERS:
                return self._error(409, "Email already registered")
            print(f"  [mock] OTP for {email} is {OTP_CODE}")
            return self._send(200, {"message": "OTP sent", "resend_after": 30})

        if path == f"{PREFIX}/auth/verify-otp":
            if (body.get("code") or "") != OTP_CODE:
                return self._error(400, "Invalid or expired verification code")
            return self._send(200, {"verified": True})

        if path == f"{PREFIX}/auth/signup":
            email = (body.get("email") or "").lower().strip()
            role = (body.get("role") or "PATIENT").upper()
            user = {
                "id": f"usr_{uuid.uuid4().hex[:8]}",
                "name": body.get("name") or "New user",
                "email": email,
                "role": role,
                "city": body.get("city"),
                "phone": body.get("phone"),
                "specialty": body.get("specialty"),
                "status": "PENDING" if role == "THERAPIST" else "APPROVED",
                "photo": None,
                "mustChangePassword": False,
            }
            USERS[email] = user
            # Therapists get no token — the account waits for admin approval.
            if role == "THERAPIST":
                return self._send(201, {
                    "access_token": None, "token_type": "bearer", "user": user,
                })
            token = uuid.uuid4().hex
            TOKENS[token] = email
            return self._send(201, {
                "access_token": token, "token_type": "bearer", "user": user,
            })

        if path == f"{PREFIX}/auth/forgot-password":
            print(f"  [mock] password-reset code is {OTP_CODE}")
            return self._send(200, {"message": "OTP sent", "resend_after": 30})

        if path == f"{PREFIX}/auth/reset-password":
            return self._send(204)

        if path == f"{PREFIX}/auth/logout":
            auth = self.headers.get("Authorization", "")
            TOKENS.pop(auth[7:] if auth.startswith("Bearer ") else "", None)
            return self._send(204)

        if path == f"{PREFIX}/payments/process":
            if not self._user():
                return self._error(401, "Not authenticated")
            therapist = next(
                (t for t in THERAPISTS if t["id"] == body.get("therapistId")), None
            )
            if therapist is None:
                return self._error(404, "Therapist not found")
            date = body.get("date") or _iso(datetime.now(timezone.utc))
            new = _session(
                f"ses_{uuid.uuid4().hex[:8]}",
                therapist["id"], therapist["name"],
                datetime.fromisoformat(date.replace("Z", "+00:00")),
                body.get("time") or "09:00",
                "SCHEDULED",
                float(body.get("fee") or therapist["price"]),
                body.get("address") or "",
            )
            SESSIONS.append(new)
            return self._send(201, {
                "session": new,
                "payment": {
                    "id": f"pay_{uuid.uuid4().hex[:8]}",
                    "amount": new["fee"],
                    "method": (body.get("paymentMethod") or "CASH").upper(),
                    "status": "COMPLETED",
                    "sessionId": new["id"],
                    "currency": "NPR",
                },
            })

        if path == f"{PREFIX}/cart":
            if not self._user():
                return self._error(401, "Not authenticated")
            product_id = body.get("productId")
            if not any(p["id"] == product_id for p in PRODUCTS):
                return self._error(404, "Product not found")
            existing = next((c for c in CART if c["productId"] == product_id), None)
            if existing:
                existing["quantity"] += int(body.get("quantity") or 1)
                line = existing
            else:
                line = {
                    "id": f"cit_{uuid.uuid4().hex[:8]}",
                    "productId": product_id,
                    "type": (body.get("type") or "BUY").upper(),
                    "quantity": int(body.get("quantity") or 1),
                    "rentalDays": int(body.get("rentalDays") or 7),
                }
                CART.append(line)
            product = next(p for p in PRODUCTS if p["id"] == product_id)
            return self._send(201, {**line, "product": product,
                                    "userId": "usr_patient_001"})

        if path == f"{PREFIX}/reviews":
            if not self._user():
                return self._error(401, "Not authenticated")
            sid = body.get("sessionId")
            found = next((s for s in SESSIONS if s["id"] == sid), None)
            if found is None:
                return self._error(404, "Session not found")
            return self._send(201, {
                "id": f"rev_{uuid.uuid4().hex[:8]}",
                "sessionId": sid,
                "patientId": "usr_patient_001",
                "therapistId": found["therapistId"],
                "rating": body.get("rating") or 5,
                "comment": body.get("comment"),
            })

        return self._error(404, f"Mock server has no route for POST {path}")

    def do_PUT(self):
        path, _ = self._split()
        body = self._body()

        if path == f"{PREFIX}/auth/me":
            user = self._user()
            if not user:
                return self._error(401, "Not authenticated")
            for field in ("name", "city", "phone", "specialty"):
                if body.get(field) is not None:
                    user[field] = body[field]
            return self._send(200, user)

        m = re.fullmatch(rf"{PREFIX}/cart/([^/]+)", path)
        if m:
            if not self._user():
                return self._error(401, "Not authenticated")
            line = next((c for c in CART if c["id"] == m.group(1)), None)
            if line is None:
                return self._error(404, "Cart item not found")
            for field in ("quantity", "rentalDays", "type"):
                if body.get(field) is not None:
                    line[field] = body[field]
            product = next(p for p in PRODUCTS if p["id"] == line["productId"])
            return self._send(200, {**line, "product": product,
                                    "userId": "usr_patient_001"})

        if path == f"{PREFIX}/therapists/me/profile":
            user = self._user()
            if not user:
                return self._error(401, "Not authenticated")
            t = THERAPISTS[0]
            for field in ("name", "city", "specialty", "gender", "bio"):
                if body.get(field) is not None:
                    t[field] = body[field]
            if body.get("price") is not None:
                t["price"] = float(body["price"])
            if body.get("experience") is not None:
                t["experience"] = int(body["experience"])
            return self._send(200, {
                "id": t["id"], "userId": t["userId"], "name": t["name"],
                "email": user["email"], "phone": body.get("phone") or "",
                "city": t["city"], "specialty": t["specialty"],
                "gender": t["gender"], "price": t["price"],
                "experience": t["experience"], "bio": t["bio"],
                "mediaUrls": None, "photo": None, "documents": [],
            })

        m = re.fullmatch(rf"{PREFIX}/sessions/([^/]+)", path)
        if m:
            if not self._user():
                return self._error(401, "Not authenticated")
            found = next((s for s in SESSIONS if s["id"] == m.group(1)), None)
            if found is None:
                return self._error(404, "Session not found")
            for field in ("status", "time", "notes"):
                if body.get(field) is not None:
                    found[field] = body[field]
            return self._send(200, found)

        return self._error(404, f"Mock server has no route for PUT {path}")

    def do_PATCH(self):
        path, _ = self._split()
        body = self._body()

        m = re.fullmatch(rf"{PREFIX}/sessions/([^/]+)/reschedule", path)
        if m:
            if not self._user():
                return self._error(401, "Not authenticated")
            found = next((s for s in SESSIONS if s["id"] == m.group(1)), None)
            if found is None:
                return self._error(400, "Session not found")
            if found["status"] != "SCHEDULED":
                return self._error(400, "Only scheduled sessions can be rescheduled")
            new_date = body.get("newDate")
            new_time = body.get("newTime")
            if not new_date or not new_time:
                return self._error(400, "newDate and newTime are required")
            found["date"] = _iso(datetime.fromisoformat(new_date))
            found["time"] = new_time
            return self._send(200, found)

        return self._error(404, f"Mock server has no route for PATCH {path}")

    def do_DELETE(self):
        path, _ = self._split()

        m = re.fullmatch(rf"{PREFIX}/sessions/([^/]+)", path)
        if m:
            if not self._user():
                return self._error(401, "Not authenticated")
            found = next((s for s in SESSIONS if s["id"] == m.group(1)), None)
            if found is None:
                return self._error(404, "Session not found")
            # The real API hard-deletes; keeping it as CANCELLED makes the
            # Cancelled tab demonstrable.
            found["status"] = "CANCELLED"
            return self._send(204)

        if path == f"{PREFIX}/cart":
            if not self._user():
                return self._error(401, "Not authenticated")
            CART.clear()
            return self._send(204)

        m = re.fullmatch(rf"{PREFIX}/cart/([^/]+)", path)
        if m:
            if not self._user():
                return self._error(401, "Not authenticated")
            line = next((c for c in CART if c["id"] == m.group(1)), None)
            if line is None:
                return self._error(404, "Cart item not found")
            CART.remove(line)
            return self._send(204)

        return self._error(404, f"Mock server has no route for DELETE {path}")

    def _split(self):
        parsed = urlparse(self.path)
        return parsed.path.rstrip("/") or "/", parse_qs(parsed.query)


if __name__ == "__main__":
    print(f"Mock Sahayatri API on http://0.0.0.0:{PORT}{PREFIX}")
    print("  emulator: --dart-define=API_BASE_URL=http://10.0.2.2:8000")
    print("  chrome:   --dart-define=API_BASE_URL=http://localhost:8000")
    print(f"  logins:   {', '.join(USERS)} (any password) · OTP {OTP_CODE}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
