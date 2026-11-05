# Sahayatri Physio — Flutter Architecture

## Overview

This is a native Flutter application for iOS and Android that replicates the Sahayatri Physio web app. It follows **Clean Architecture** with a **feature-first** folder structure and uses **Riverpod** for state management and dependency injection.

---

## Architecture Layers

### 1. Core Layer (`lib/core/`)

Shared infrastructure that any feature can depend on:

| Directory | Purpose |
|-----------|---------|
| `config/` | Environment configuration (flavors, base URLs, --dart-define) |
| `constants/` | App-wide constants (API paths, storage keys) |
| `router/` | `go_router` setup with auth redirect (`refreshListenable`) |
| `theme/` | `ThemeData`, `ColorScheme`, `TextTheme`, spacing — derived from Tailwind design tokens |
| `network/` | `Dio` instance, `AuthInterceptor`, token refresh logic, `ErrorMapper` |
| `storage/` | `FlutterSecureStorage` wrappers |
| `error/` | `Failure` sealed class hierarchy, exception → failure mapping |
| `utils/` | Extensions, formatters (currency, date) |
| `widgets/` | Shared/dumb widgets (buttons, inputs, cards, loaders, empty/error states) |

### 2. Feature Layer (`lib/features/<feature>/`)

Each feature is self-contained with three sub-layers:

```
features/<feature>/
  data/
    datasources/    — Remote (Retrofit/Dio) + local (cache) sources
    models/         — DTOs (json_serializable; `@JsonSerializable()` + a
                      hand-written fromJson/toJson pair)
    repositories/   — Repository implementations
  domain/
    entities/       — Pure Dart domain objects (no JSON/Flutter deps)
    repositories/   — Abstract repository interfaces
    usecases/       — One class per use case, single `call()` method
  presentation/
    providers/      — Riverpod providers/notifiers
    screens/        — Full-page widgets
    widgets/        — Feature-specific widgets
```

### Layer Rules

- **Domain layer** has zero dependency on Flutter, Dio, or any external package: entities are plain Dart classes.
- **Domain** only knows entities and abstract repository interfaces.
- **Presentation** never talks to `data/` directly. In `auth`, `packages` and
  `patient` (availability) it goes through a domain use case; everywhere else
  the provider reads the abstract repository — `ref.watch(clinicRepositoryProvider)`.
  Follow the feature you are in rather than adding a pass-through use case to
  match this diagram.
- **Repositories** return `Either<Failure, T>` (via `fpdart`).
- **No business logic in widgets.** Widgets are dumb; state/logic lives in Riverpod providers.

---

## Tech Stack

| Concern | Package |
|---------|---------|
| State management | `flutter_riverpod` — providers are hand-written, not generated |
| Routing | `go_router` |
| Networking | `dio` + `retrofit` |
| Models | `json_serializable` (**not** `freezed`: the repo has zero `@freezed` annotations and zero `.freezed.dart` files) |
| Error handling | `fpdart` (`Either`) |
| Localisation | `flutter_localizations` + `gen-l10n` over `lib/l10n/*.arb` |
| Secure storage | `flutter_secure_storage` |
| Code generation | `build_runner`, producing `*.g.dart` only |

---

## Data Flow

```
Screen (StatelessWidget)
  └─ reads provider (ref.watch(provider))
      └─ Provider manages notifier state
          └─ Notifier calls UseCase
              └─ UseCase calls Abstract Repository
                  └─ Repository Implementation
                      ├─ Remote DataSource (Dio/Retrofit)
                      └─ Local DataSource (cache)
```

---

## Error Handling

All repository methods return `Either<Failure, T>`:

```dart
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure { ... }
class UnauthorizedFailure extends Failure { ... }
class ValidationFailure extends Failure { ... }
class ServerFailure extends Failure { ... }
class NotFoundFailure extends Failure { ... }
```

UI code pattern-matches on `Failure` subtypes to show appropriate feedback.

---

## Routing

- `go_router` with a `refreshListenable` that watches the auth state provider.
- Unauthenticated users are redirected to `/login`.
- Authenticated users are redirected based on role (`/patient/*` or `/therapist/*`).
- Route structure:
  - `/login` — Auth screen
  - `/signup` — Signup screen (role selection)
  - `/patient/...` — Patient tab navigation
  - `/therapist/...` — Therapist tab navigation

---

## Flavors & Configuration

Three flavors: **dev**, **staging**, **prod**.

Each flavor has its own:
- API base URL
- App ID/bundle ID suffix
- App name suffix

Configuration via `--dart-define-from-file`.

---

## Where to Add New Code

1. **New API endpoint?** → Update the Retrofit interface in the relevant feature's `data/datasources/`.
2. **New screen?** → Add it to the relevant feature's `presentation/screens/`, register it in `core/router/`.
3. **New business logic?** → Add a use case to the relevant feature's `domain/usecases/`.
4. **New shared component?** → Add it to `core/widgets/`. Check
   `core/widgets/state_views.dart` first — loading (`SkeletonBox`,
   `SkeletonList`), failure (`ErrorStateView`, `InlineRetry`), empty
   (`EmptyStateView`), no-endpoint (`ApiTodoState`,
   `showUnavailableDialog`) are all already there, and radii come from
   `AppRadii`, which carries the design spec's scale.
5. **New user-facing string?** → Both `lib/l10n/app_en.arb` and
   `app_ne.arb`, with an `@key` description on the English.
   `test/core/localization_test.dart` fails if they drift.
6. **New API model?** → Add a DTO in the relevant feature's `data/models/` (a plain class with `@JsonSerializable()`) and a domain entity in `domain/entities/`, then re-run `build_runner`.
