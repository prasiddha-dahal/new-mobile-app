# Navigation integration notes

Written on `feat/nav-restructure`, which reshaped the **patient** bottom bar.
Everything here is a hand-off to another branch: it is what that branch has to
wire up, and why this one deliberately did not.

The therapist bar is untouched by this work.

> **Status: both hand-offs below are done.** The header search icon exists and
> pushes (§1) — though it lives in the shared `AppHeader`, which `TabShell`
> mounts once for every screen, rather than being added to `_HeaderActions`;
> that widget and the whole green `HomeHeader` are gone. The Packages row is
> routed at `/patient/packages` in the Home branch (§2), and the placeholder
> test asserting it navigated nowhere has been replaced rather than deleted.
> The therapist FAB glyph under "Not changed, on purpose" is still not changed,
> on purpose.

---

## The patient bar today

```
Home · Sessions · [ + ] · Notifications · Account
  0       1       (FAB)        2            3
```

Four branches under one `StatefulShellRoute.indexedStack`, in that order.
The centre action is **not** a tab and has no branch — it opens the
quick-action sheet over whichever tab the user is on.

Index 0 is load-bearing: `TabShell`'s back ladder treats it as Home
(`firstTabLocation: '/patient/home'`). Home stayed at 0, so the ladder is
unchanged; `test/core/tab_shell_test.dart` now walks every non-Home tab root
rather than one, so a future reorder fails loudly.

Routes moved:

| Route | Was | Now | Why |
|---|---|---|---|
| `/patient/sessions` | Home branch | **branch 1**, its own tab | it is a tab now |
| `/patient/find` | Find branch (tab 1) | **Home branch** | reached from Home's hero card |
| `/patient/therapist/:id` | Find branch | **Home branch** | follows Find |
| `/patient/coverage` | Find branch | **Home branch** | follows Find |

The rule those follow is documented at the top of
`lib/core/router/app_router.dart` and has not changed: a route lives in the
branch of the tab it is reached from.

### Added on `feat/home-discovery`

A **"What are you looking for?"** block at the bottom of the patient home
screen, with one row per way into care:

| Row | Route | Was reachable from |
|---|---|---|
| Find a Physiotherapist | `/patient/find` | the hero button (still there) |
| Find a Clinic | `/clinics` | the Account menu — **removed there** |
| View on Map | `/patient/coverage` | **nothing at all** |

The last two also appear as compact pills on `/patient/find`, pinned above
the results. Copy, destination and glyph live once, in
`lib/features/patient/presentation/widgets/discovery_section.dart`, so the
two screens cannot drift apart.

All of them `push`, for the reason spelled out below for the search icon: a
page reached from within a tab stacks on that tab, keeps it lit and keeps its
scroll, and Back returns to the card that was tapped. `/clinics` lives above
the shell, so pushing it covers the bar and Back brings it straight back —
which is what `ClinicProfileScreen`'s `canPop()` fallback already assumed.

---

## 1. Header search icon → Find  *(owner: the app-header branch)*

Find is no longer a tab. It has two entry points by design:

1. the **Find Physiotherapist** button in the green hero on the patient home
   screen — **done on this branch**
   (`lib/features/patient/presentation/screens/patient_home_screen.dart`);
2. a **search icon in the top-right of the app header** — **not done here.**

The shared header is being built on another branch, and building a second one
here would just have to be deleted. `HomeHeader` in
`lib/core/widgets/app_header.dart` exists but no screen mounts it yet, so
there was nothing to hang the icon on.

What that branch needs to add, to `_HeaderActions` in `app_header.dart`,
alongside the language toggle and the notification bell:

```dart
GestureDetector(
  onTap: () => context.push('/patient/find'),
  child: /* 32px translucent circle, Icons.search, 18px, white —
             same shell as the bell next to it */,
),
```

**`push`, not `go`.** An imperative `push` always stacks on the *current*
branch's navigator, whichever branch declares the route. So a search icon
that is present on every tab pushes Find onto the tab the user is already in:
their tab stays lit, its scroll position survives, and Back returns them
exactly where they were. `go('/patient/find')` would instead yank them to the
Home tab and replace that branch's stack — on a control that is visible from
all four tabs, that is a trap.

Guard it by role if the header is shared with the therapist shell:
`/patient/find` has no therapist equivalent, and the auth redirect bounces a
therapist off `/patient/*` to `/therapist/home`.

---

## 2. Packages row in the quick-action sheet  *(owner: `feat/packages-mobile`)*

The centre `+` opens `_QuickActionSheet` in `lib/core/widgets/nav_bars.dart`.
For a patient it now holds exactly one row — **Packages / "Browse care
packages"** — plus a Close button. The row is in the design, so it is in the
sheet; but its destination does not exist on this branch, so it navigates
nowhere and closes the sheet. No route was invented and no placeholder screen
was created.

To wire it, in `nav_bars.dart`, replace the `route: null` under the
`TODO(packages)` with the real path:

```dart
(
  icon: '📦',
  label: 'Packages',
  meta: 'Browse care packages',
  route: '/patient/packages',   // ← whatever the Packages branch registers
),
```

Nothing else in the sheet has to change: the tap handler already does
`Navigator.pop(context)` then `context.go(route)` when the route is non-null.

Then:

- **Register the route.** Per the branch rule, Packages is reached from the
  centre action, which belongs to no tab. Put it in the **Home branch**
  (branch 0) so it keeps the bottom bar and a `go` lands the user on Home —
  unless the Packages branch adds a funnel that owns the viewport, in which
  case only the funnel screens go above the shell.
- `context.go` is right for this one (not `push`): the sheet is dismissed
  first, so there is no sheet to pop back through, and the user is switching
  context rather than drilling into the page they were on.
- Update `test/core/quick_action_sheet_test.dart` — its last case asserts the
  row does **not** navigate. That assertion is a placeholder for the missing
  route, and should be replaced with one that asserts it *does*, not deleted.

Note: `lib/features/patient/presentation/screens/packages_screen.dart` and
`package_confirmed_screen.dart` already exist in the tree and are registered
in no router. They were left untouched here — the Packages branch owns them.

---

## Not changed, on purpose

- **The therapist FAB glyph.** Settled for the patient bar on
  `feat/home-discovery`: `_SahayatriBottomNav` now takes a `fabIcon`, the
  patient bar passes `Icons.add`, and the therapist bar keeps
  `Icons.calendar_month_rounded` — there is no therapist design here asking
  for a `+`. Still worth revisiting: on the therapist bar that glyph is also
  the Schedule tab's icon two slots to the left, so the bar says "calendar"
  twice and means different things by it.
- **The Find screen itself.** Only its navigation moved — plus, on
  `feat/home-discovery`, a pinned row of two shortcuts (Find a Clinic, View
  on Map) above the results.
- **`AppBottomNav` / `patientNavItems`** in `lib/core/widgets/app_bottom_nav.dart`
  — a dead prototype bar, deleted on `feat/dead-code-cleanup`. Its
  `patientNavItems` constant already described the layout this branch built,
  which is how we knew the target was the intended one. Its one live constant,
  `reservedHeight`, is now `navBarReservedHeight` in `nav_bars.dart`, same
  value, same four call sites.
