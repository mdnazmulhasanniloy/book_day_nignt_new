# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

BookDiaNight (`bookdianight_app`) is a Flutter app (Dart SDK ^3.10.3) for a two-sided nightlife marketplace: **users** discover clubs/events, reserve tables, buy tickets/VIP modules via Stripe, join waiting lists and guest lists; **club owners** (`role == 'CLUB_OWNER'`) manage clubs/events, VIP modules, guest lists, quotes, waiting lists, promo codes, earnings, Stripe Connect payouts, and scan door QR codes. Product flows are documented in `README.md` and `docs/WORKFLOW_GUIDE.md`; backend contract notes live in `docs/backend-update-review.md` and `docs/client-vs-backend-gap.md`.

## Commands

```bash
flutter pub get
flutter run
flutter analyze                                   # lints: package:flutter_lints/flutter.yaml
flutter test                                      # all tests
flutter test test/backend_update_test.dart        # main test suite
flutter test test/backend_update_test.dart --plain-name "<test name>"   # single test
```

## Configuration

- `.env` (bundled as an asset, loaded by `AppConfig.init()` in `lib/app/config/flavor_config.dart`) supplies `BASE_URL`, `LOCAL_BASE_URL`, `MAP_API_KEY`, `STRIPE_PUBLISHABLE_KEY`.
- `AppConfig.isProduction` is a compile-time const. When `true`, `EndPoint.BASE_URL` uses `BASE_URL`; when `false`, it uses `LOCAL_BASE_URL` and wraps the app in `DevicePreview`.
- `main.dart` installs `MyHttpOverrides`, which accepts all TLS certificates.
- The app is forced to `ThemeMode.light`.

## Architecture

Code lives under `lib/app/`:

- `core/` — shared infrastructure: `network/` (`BaseClient`, `EndPoint`, `ApiErrorHandler`/`ApiException`), `local_storage/` (GetStorage wrapper `LocalStorage` with keys in `AppConst`), `auth/account_gate.dart`, `explore/` (cross-module discovery and event-commerce models and repositories), `resources/` (common widgets, dialogs, colors, assets, text styles), `utils/`, `language/` (GetX translations).
- `modules/<feature>/` — feature folders, usually split into `controllers/`, `repository/`, `model/`, `views/`, `widgets/`. User-facing features are in `modules/user_side/`, owner features in `modules/club_owner_side/`. Shared features (auth, profile, notification, splash, onboarding, rules, language) sit at the top level.
- `services/` — app-wide services: FCM + local notifications (`notification_services.dart`), notification-tap routing (`notification_router.dart`), deep links via `app_links` (`deep_link_service.dart`), media.

### Key patterns

- **State & navigation: GetX.** Controllers are created with `Get.put` / `Get.find`. Most navigation is imperative: `Get.to(() => SomeView())` / `Get.offAll(...)`. `AppPages` registers only a few named routes (splash, onboarding, notFound), so don't expect new screens to be added there.
- **Startup routing** happens in `modules/splash/splash_view.dart`: it reads the access token and role from `LocalStorage` and refreshes the session. Then it sends `CLUB_OWNER` users to `OwnerDashboard`, or to `PayoutSetupView` if payouts aren't set up yet. Other users go to `UserDashboard`, and anyone without a token goes to onboarding.
- **Guest mode:** users can browse without signing in. Actions that need auth must call `AccountGate.ensure()`, which shows a sign-in/sign-up dialog and returns whether the user is now signed in.
- **Networking:** `BaseClient` is a Dio singleton with `validateStatus: (_) => true`. Status codes therefore reach the caller instead of being thrown as Dio errors, so repositories check the status and body themselves. The client throws `ApiException` through `ApiErrorHandler`. Repositories add the `Authorization: Bearer <token>` header themselves, reading the token from `LocalStorage`. All endpoint paths are in `core/network/end_point.dart`.
- **Testability:** repositories accept an optional `BaseClient` in their constructor (`Repo({BaseClient? client})`). Tests in `test/backend_update_test.dart` subclass or fake repositories and the client instead of hitting the network.
- **Payload shape matters:** the backend uses strict Zod schemas. Sub-resource `PUT`/`POST` bodies must not include `id`, so `toPayload({bool includeId = false})` on models like `EventVipModuleModel` and `EventHostModel` leaves it out. Parsers are written defensively because responses vary: flat vs. nested objects, and alternate key names.
- **Time handling:** club opening hours and purchase times use a fixed CST (UTC−6) wall clock. Use the helpers in `core/utils/cst_time.dart` (`cstWallIso`, `clubClockIso`, `clubClockFromIso`) rather than plain `toIso8601String()`. The backend compares raw clock digits, so a wrong zone suffix shifts bookings.
