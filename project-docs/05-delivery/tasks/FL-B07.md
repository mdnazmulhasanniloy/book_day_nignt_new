# FL-B07: Flutter 401 handling (B-07)

| Field | Value |
|---|---|
| Stack | flutter |
| Milestone | M8-early (Flutter fixes that need no backend change) |
| CR / BUG IDs | B-07 |
| Depends on | none (design shares one client change with FL-B08; implement together or B-08 first) |
| Size | at most one day |
| Status | investigated, not implemented (no Flutter SDK on the dev machine; cannot run `flutter analyze` or `flutter test`) |

Branch: from `main` (`fix/flutter-401-handling`) once the Flutter SDK is available. Flutter is otherwise read-only; this task was approved on 2026-11-22.

## What the code does today (verified by reading)

- `core/network/base_client.dart`: one Dio singleton, `validateStatus: (_) => true`. `_handleResponse` throws `UnauthorizedException` for **401 and 403**, then calls `_handleUnauthorized()`, which is an **empty stub** (only a `debugPrint`; the logout and redirect lines are commented out).
- Repositories add `Authorization: Bearer <token>` themselves from `LocalStorage` (`AppConst.accessToken`). There is no shared auth interceptor.
- `splash_view.dart` `_refreshSession` clears the token only at cold start (via `POST /auth/check`). During a session an expired token just makes calls fail with a snackbar or silent null (see `MediaService`: returns null / false).
- 403 is also used for non-auth reasons (the backend returns 403 for CSRF, role checks, reset-without-OTP in HF-004), so treating every 403 as "logged out" is wrong.

## Plan

1. In `BaseClient`, treat only 401 as session expiry. Leave 403 as a normal permission error (keep `UnauthorizedException` for compatibility, but do not clear the session on 403).
2. Implement `_handleUnauthorized()` once, after FL-B08's refresh has failed or is not possible: clear `accessToken`, `refreshToken`, `role`, then `Get.offAll` to the sign-in or onboarding screen, once (guard with a flag so parallel 401s navigate only once). Guests (no token) must not be redirected: `AccountGate.ensure()` already handles them.
3. Skip the handler for the auth endpoints themselves (`/auth/login`, `/auth/signup`, `/auth/verify`, `/auth/social`, `/auth/refresh`, `/recover/*`): a 401 there means wrong credentials, not an expired session.
4. Show one message ("Session expired, please sign in again") instead of per-screen errors.

## Done when

- [ ] Unit tests (Dio with a fake adapter): 401 on a protected call with no refresh token clears storage and navigates once even with 3 parallel 401s; 401 on `/auth/login` does not; 403 does not clear the session; guest 401 does not navigate.
- [ ] `flutter analyze` clean, `flutter test` green.
- [ ] Manual on a device: expire the access token (shorten it on a local backend), open any protected screen, land on sign-in once.
- [ ] No backend change.

## Risks

- A production app consumes this; test login, signup and OTP screens to be sure their 401s still show the inline error.
- The backend 401 body has `errorType` (`TOKEN_EXPIRED`, `TOKEN_BLACKLISTED`, `TOKEN_INVALID`); use it to tell "expired, try refresh" from "revoked, log out now".
