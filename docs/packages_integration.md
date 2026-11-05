# Packages — integration notes

The Packages feature ships as a self-contained module under
`lib/features/packages/`. Nothing outside that folder was touched, so the router,
the nav bars and the patient/therapist screens are free of merge conflicts. This
file lists the four things an integration pass has to wire up, and the API gaps
the screens deliberately do **not** paper over.

> **Status: sections 1–3 and 5 are done.** Both routes are registered in the
> patient Home branch, `ActivePackageCard` is on the patient home screen under
> the Next-session card, the centre-action sheet's Packages row points at
> `/patient/packages`, and the three superseded files in section 5 are deleted.
> Section 4 — booking *with* a package — is still open and still belongs to the
> booking screen. Tests: `test/features/packages/package_routes_test.dart`.

---

## 1. Routes

Both screens are **shell-safe**: they render no `Scaffold` of their own because
`PatientShell` already provides one (`lib/core/router/app_router.dart`). Mount
them inside the patient `ShellRoute`:

```dart
GoRoute(
  path: '/patient/packages',
  builder: (_, __) => TherapyPackagesScreen(
    onBack: () => context.canPop() ? context.pop() : context.go('/patient/home'),
    onViewMyPackages: () => context.go('/patient/packages/mine'),
  ),
),
GoRoute(
  path: '/patient/packages/mine',
  builder: (_, __) => MyPackagesScreen(
    onBack: () => context.canPop() ? context.pop() : context.go('/patient/home'),
    onBrowsePackages: () => context.go('/patient/packages'),
  ),
),
```

Imports:

```dart
import '../../features/packages/presentation/screens/my_packages_screen.dart';
import '../../features/packages/presentation/screens/therapy_packages_screen.dart';
```

Every callback is optional. `onBack: null` hides the back arrow (for a
tab-mounted use); the other callbacks simply become no-ops.

There is **no third route for package detail** — tapping a card opens
`showPackageDetailSheet`, a modal bottom sheet that also carries the purchase
confirmation. Keeping it a sheet is what lets the module stay router-free.

## 2. Home-screen card

`ActivePackageCard` is the drop-in for "if a patient has a package enabled, it
should be displayed on the home page". It reads `activePackageProvider` itself,
so mounting it is one line inside the patient home list:

```dart
import '../../../packages/presentation/widgets/active_package_card.dart';

ActivePackageCard(onOpen: () => context.go('/patient/packages/mine')),
```

It renders `SizedBox.shrink()` while loading, when there is no active package,
when the package has expired or is used up, and when the call fails — so it is
safe to place unconditionally. No spacing of its own; wrap it if the surrounding
list needs a gap (check `purchase != null` via
`ref.watch(activePackageProvider).valueOrNull` if the gap must collapse too).

## 3. Quick Action sheet entry

Add an entry pointing at `/patient/packages` ("Therapy packages") and, if the
sheet has room, `/patient/packages/mine` ("My packages").

## 4. Booking with a package

`POST /sessions` accepts `packagePurchaseId`; when present, the session's `fee`
becomes `0`, `sessionsUsed` increments, and the session comes back with
`bookedViaPackage`, `packagePurchaseId` and `packageName`. The mobile booking
flow does **not** send it yet — that belongs to the booking screen, which is out
of scope for this branch. When it is wired:

- offer the package only when `activePackageProvider` yields a purchase whose
  `isUsableAt(DateTime.now())` is true;
- after a successful booking *or* cancellation call
  `ref.read(packageActionsProvider).refreshPurchases()`, because both move
  `sessionsUsed`;
- `SessionResponse` gained `bookedViaPackage` / `packageName` /
  `packagePurchaseId`; the mobile `SessionDto`
  (`lib/features/patient/data/models/session_models.dart`) does not read them
  yet, so a package-booked session currently shows as a normal Rs 0 session.

## 5. The old, orphaned screen

`lib/features/patient/presentation/screens/packages_screen.dart` (plus its
`PackageDto` in `lib/features/patient/data/models/package_models.dart` and
`package_confirmed_screen.dart`) predates this work. It is **not referenced by
the router** — it renders the catalogue read-only and pops an "unavailable"
dialog instead of buying. Once the new screens are routed, delete all three; they
are superseded. Left in place here only because patient screens are owned by
another branch this cycle.

---

## API gaps — what the screens deliberately do not show

The designs and the schema disagree in four places. Nothing below is faked.

| # | Design | What exists | What was built |
|---|---|---|---|
| 1 | Category chips `All / Orthopedic / Neurological / Sports Injury / …` | No category field. `tag` holds marketing lines (`"Most requested from abroad"`, `"Return to play"`, `"For parents at home"`) | Chips are built from the **real distinct `tag` values**, and the row hides itself when every package has its own tag (`PackageCatalogue.hasUsefulTagFilter`) — which is the case for the three seeded rows, so no chip row renders today. Needs a real `category` column to match the mock. |
| 2 | Per-therapy duration variants (`1 Week / 2 Weeks / 3 Weeks / 4 Weeks`) and "From Rs 4,500" | One `price`, one `sessionCount`, one `validityDays` per `Package` row. No variant model at all | The card and the detail sheet state the single real price, the backend's own `cadence` string, the session count and the validity window. No variant picker. Needs a `PackageVariant` model to support the design. |
| 3 | "From Rs 4,500" | Seeded packages are Rs 16,000–24,000 | Real values, formatted with `formatCurrency`. |
| 4 | "Search therapy or condition" box | `GET /packages` takes `skip`/`limit` only — no `q`, no tag filter | Filtering is client-side over name, blurb, tag and points (`TherapyPackage.matches`). Fine for three rows; **needs a server-side `q` parameter** before the catalogue grows past a page. |

Two more, smaller:

- `Package.icon` is a **lucide-react icon name** (`Brain`, `Activity`,
  `HeartHandshake`) because the web app renders it directly. Flutter has no icon
  set keyed by those names, so `packageIconFor` maps the known values and falls
  back to a neutral medical glyph. A shared icon vocabulary (or an emoji column,
  as `Product` has) would remove the hand-mapping.
- Payments are **recorded, not charged** (TODO(api) A18). The confirm step says
  so rather than implying a gateway ran.

## Behaviour worth knowing

- **One active package at a time.** `purchase_package` refuses a second purchase
  with 400 ("You already have an active package"). The catalogue shows a notice
  when a usable package exists rather than letting the patient reach the confirm
  step and bounce.
- **`GET /packages/my-purchases/active` answers 404 when there is no active
  package.** The repository maps that to `Right(null)` — an empty state, not a
  failure. The same 404 arrives while the API branch is unmerged, and reads
  identically, which is intended.
- **The packages endpoints are not deployed.** They live on the API repo branch
  `origin/feature/packages`, unmerged. Until it ships, the catalogue shows a
  retryable "Not found" and My packages shows "No active package". Nothing
  crashes and nothing spins forever.
