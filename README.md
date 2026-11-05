# Sahayatri Physio — Flutter Mobile App

[![CI](https://github.com/sahayatri/sahayatri_care_connect/actions/workflows/ci.yml/badge.svg)](https://github.com/sahayatri/sahayatri_care_connect/actions/workflows/ci.yml)

**Sahayatri Physio** is a native Flutter mobile application (iOS + Android) for an on-demand home physiotherapy platform in Nepal. Patients can find and book verified physiotherapists for home visits, rent rehabilitation equipment, purchase medical supplies, and track their recovery progress. Physiotherapists can manage their schedules, accept/decline booking requests, process payments, and view patient histories.

This app was migrated from a React/Vite/Tailwind web prototype ([Lovable](https://lovable.dev)) to a proper native Flutter architecture. It communicates with a Python FastAPI backend over REST.

---

## Features

### For Patients
- **Browse & Search Therapists** — View top-rated physiotherapists, filter by specialty, search by name or condition
- **Book Home Visits** — Schedule sessions with real-time slot selection, address input, and payment method choice
- **Manage Sessions** — View upcoming, past, and cancelled sessions with reschedule/cancel options
- **Equipment Shop** — Browse and rent/purchase rehabilitation equipment, medicines, and nutrition products
- **Cart & Checkout** — Manage rental durations, quantities, and complete orders
- **Recovery Tracking** — Monitor progress through sessions completed and goals
- **Reports & Files** — View therapist-shared reports, X-rays, and session notes
- **Address Management** — Save and manage home visit addresses
- **Payment Methods** — Link multiple payment options (eSewa, Khalti, Cash)
- **Help & Support** — FAQ, contact support with in-app messaging
- **Notifications** — Booking confirmations, session reminders, and payment receipts

### For Therapists
- **Dashboard** — Overview of today's schedule, weekly KPIs, earnings, and rating
- **Availability Management** — Toggle online/offline status, manage weekly recurring availability
- **Booking Requests** — Accept or decline session requests, manage upcoming/completed sessions
- **Schedule Calendar** — Visual weekly grid showing booked, open, and blocked time slots
- **Patient Management** — View treated patients with visit history
- **Earnings & Payouts** — Monthly earnings breakdown, transaction history, payout method management
- **Performance Dashboard** — KPI cards, session completion rates, rating trends
- **Reviews & Ratings** — View patient reviews with detailed feedback
- **Bio & Portfolio** — Manage professional bio, specializations, and certifications
- **Service Areas** — Define and update coverage zones
- **Payout Methods** — Manage eSewa, bank transfer, and other payout options
- **Session Notes** — Upload notes and reports for completed sessions

### Shared
- **Bilingual Support** — Full English/Nepali interface with in-app toggle
- **Quick Action Sheet** — Role-based FAB menu for common tasks
- **Unified Header** — Shared in-app header with language toggle and notification bell
- **Role-based Routing** — Separate navigation flows for patients and therapists
- **Notifications** — Unified notification feed for both roles
- **Account Management** — Profile editing, help & support

---

## Tech Stack

| Concern | Technology |
|---------|-----------|
| **Framework** | Flutter 3.44.4+ (Dart 3.12.2+) |
| **State Management** | Riverpod (`flutter_riverpod`) |
| **Routing** | `go_router` with auth redirect |
| **Networking** | `dio` + `retrofit` (typed API clients) |
| **Models** | `json_serializable` (plain classes, hand-written `fromJson`/`toJson` — **not** `freezed`) |
| **Error Handling** | `fpdart` (`Either<Failure, T>`) |
| **Storage** | `flutter_secure_storage` |
| **Code Generation** | `build_runner` |
| **Architecture** | Clean Architecture (feature-first) |
| **CI/CD** | GitHub Actions |

---

## Project Structure

```
lib/
├── core/                           # Shared infrastructure
│   ├── constants/                  # API paths, app constants
│   ├── error/                      # Failure types, error mapping
│   ├── network/                    # Dio client, auth interceptor
│   ├── router/                     # go_router setup with auth guards
│   ├── storage/                    # Secure storage wrappers
│   ├── theme/                      # Design tokens, ColorScheme, TextTheme
│   ├── utils/                      # Formatters (currency, dates), i18n (EN/NE)
│   └── widgets/                    # Shared components (buttons, cards, nav bars, headers)
│
├── features/
│   ├── auth/                       # Authentication (login, signup, token mgmt)
│   │   ├── data/                   #   DTOs, API client, repository impl
│   │   ├── domain/                 #   Entities, repository interface, use cases
│   │   └── presentation/           #   Providers, screens, widgets
│   │
│   ├── patient/                    # Patient flow (find, book, sessions, recovery, reports)
│   │   └── presentation/           #   15+ screens for patient journey
│   │
│   ├── therapist/                  # Therapist flow (dashboard, schedule, earnings, performance)
│   │   └── presentation/           #   14+ screens for therapist journey
│   │
│   ├── shop/                       # Equipment shop & cart
│   │   └── presentation/           #   Shop, cart, order screens
│   │
│   └── notifications/              # Notification feed
│       └── presentation/           #   Notifications screen
│
├── app.dart                        # MaterialApp.router with ProviderScope
└── main.dart                       # Entry point
```

### Architecture Principles

- **Domain layer** has zero dependency on Flutter, Dio, or any external package outside pure Dart. It only knows entities and abstract repository interfaces.
- **Presentation layer** never talks to `data/` directly — only through domain use cases.
- **Repositories** return `Either<Failure, T>` via `fpdart`.
- **No business logic in widgets.** Widgets are dumb; state/logic lives in Riverpod notifiers.

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

---

## Prerequisites

- **Flutter SDK** 3.44.4+ (stable channel)
- **Dart SDK** 3.12.2+
- **Xcode** 16+ (for iOS builds)
- **Android Studio** / Android SDK (for Android builds)
- **CocoaPods** (for iOS dependencies)
- **Backend API** — Python FastAPI server at `pvc-api` (see [docs/api_contract.md](docs/api_contract.md))

### Installing Flutter

```bash
# macOS (Homebrew)
brew install flutter

# Or download directly
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.44.4-stable.zip \
  -o /tmp/flutter.zip
unzip /tmp/flutter.zip -d ~/
export PATH="$HOME/flutter/bin:$PATH"
```

Verify installation:
```bash
flutter doctor
```

---

## Installation

```bash
# Clone the repository
git clone https://github.com/sahayatri/sahayatri_care_connect.git
cd sahayatri_care_connect

# Install dependencies
flutter pub get

# Generate code (JSON serialization, Retrofit, Freezed)
dart run build_runner build --delete-conflicting-outputs
```

---

## Running the App

### Development

```bash
# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on a specific device
flutter devices
flutter run -d <device_id>
```

### Configuration

The app connects to the backend API at configurable base URLs:

| Environment | Base URL | Notes |
|-------------|----------|-------|
| **dev** | `http://localhost:8000` | Local FastAPI server |
| **staging** | `https://staging-api.sahayatri.np` | Staging environment |
| **production** | `https://api.sahayatri.np` | Production environment |

The default dev URL is set in `lib/core/constants/app_constants.dart`. For staging/production, use `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=https://staging-api.sahayatri.np
```

### Building for Release

```bash
# iOS (requires Apple Developer account)
flutter build ios --release
open build/ios/iphoneos/Runner.ipa

# Android
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

---

## Backend API

The Flutter app communicates with a Python FastAPI backend at `/api/v1/...`. The backend is in the sibling `pvc-api` directory.

**Key endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/auth/signup` | Create account |
| `POST` | `/api/v1/auth/login` | Login, returns JWT |
| `GET` | `/api/v1/auth/me` | Get current user |
| `GET` | `/api/v1/therapists` | List therapists (public) |
| `POST` | `/api/v1/sessions` | Book a session |
| `GET` | `/api/v1/products` | List shop products |
| `POST` | `/api/v1/cart` | Add item to cart |
| `POST` | `/api/v1/payments` | Process payment |

Full API documentation: [docs/api_contract.md](docs/api_contract.md)

> **Note:** The backend is not required to run the app in prototype mode. All screens use mock data when not connected to a real API. To wire up the real API, connect the `AuthActions` provider in `lib/features/auth/presentation/providers/auth_provider.dart`.

---

## Development

### Code Generation

This project uses code generation for JSON serialization, Freezed models, and Retrofit API clients:

```bash
# Watch mode (auto-regenerate on changes)
dart run build_runner watch

# One-time build
dart run build_runner build

# Force rebuild
dart run build_runner build --delete-conflicting-outputs
```

### Running Analysis

```bash
flutter analyze
```

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/features/auth/presentation/providers/auth_provider_test.dart
```

### Adding a New Feature

1. Create the feature directory structure:
   ```
   lib/features/<feature_name>/
     data/datasources/
     data/models/
     data/repositories/
     domain/entities/
     domain/repositories/
     domain/usecases/
     presentation/providers/
     presentation/screens/
     presentation/widgets/
   ```

2. Define the domain entity and abstract repository
3. Create the DTO with `@JsonSerializable()`
4. Implement the Retrofit data source
5. Implement the repository
6. Create Riverpod provider(s)
7. Build the screen widget(s)
8. Register routes in `lib/core/router/app_router.dart`
9. Run `dart run build_runner build`

---

## Design System

The visual design is ported from the original Tailwind web prototype. Design tokens are defined in `lib/core/theme/`:

| Token | Value | Usage |
|-------|-------|-------|
| `pine` | `#2F5D50` | Primary brand color, dark green |
| `pine-light` | `#3F7965` | Lighter green for gradients |
| `pine-pale` | `#D1E8DF` | Pale green background/container |
| `amber-brand` | `#E2962F` | CTA buttons, accent |
| `cream` | `#FBFBF8` | Page background |
| `ink` | `#1E2A2E` | Primary text |
| `ink-mid` | `#4A5854` | Secondary text |
| `ink-mute` | `#8FA8A0` | Muted/label text |
| `mist` | `#EEF1ED` | Neutral background |
| `danger` | `#C84B4B` | Destructive actions |

**Typography:** Fraunces (serif headings), Inter (sans body), IBM Plex Mono (labels, codes)

---

## Testing

The project uses `flutter_test`, `mocktail`, and `riverpod_test` for testing:

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test Structure

```
test/
├── features/
│   ├── auth/
│   │   ├── data/repositories/
│   │   ├── domain/usecases/
│   │   └── presentation/providers/
│   ├── patient/
│   │   └── presentation/screens/
│   └── ...
└── core/
    ├── network/
    ├── storage/
    └── utils/
```

---

## CI/CD

The project includes a GitHub Actions workflow (`.github/workflows/ci.yml`) that:

1. **Analyzes** code with `flutter analyze`
2. **Runs tests** with `flutter test`
3. **Builds** iOS (debug, no codesign) and Android (debug APK)

Every PR to `main` or `develop` triggers the pipeline.

---

## Documentation

- [Architecture Overview](docs/architecture.md) — Clean Architecture, layers, data flow
- [API Contract](docs/api_contract.md) — All endpoints, schemas, auth, assumptions
- [Web Prototype](../sahayatri-care-connect-main) — Original Lovable React prototype

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `flutter pub get` fails | Check Flutter version: `flutter --version` (requires 3.44.4+) |
| `build_runner` errors | Run `dart run build_runner build --delete-conflicting-outputs` |
| iOS build fails | Run `cd ios && pod install && cd ..` |
| Missing generated files | Generated `.g.dart` files are in `.gitignore` — run `dart run build_runner build` |
| Analysis errors | The 200+ info-level warnings are mostly `prefer_const_constructors` — safe to ignore during development |

---

## License

[Add license information here]

---

## Team

- **Original Prototype:** Lovable.dev
- **Flutter Migration:** [Your Name/Team]
- **Backend API:** Sahayatri Physio Team
