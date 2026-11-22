# Flutter auth follow-up (2026-11-22)

Follow-up to the independent review `project-docs/05-delivery/reports/flutter-review-2026-11-22.md` (kept unchanged on its own branch). Fixes findings H1 and H2 and the related M1 and M3.

Status: implemented and tested in Docker (Flutter 3.44.0, Dart 3.12.0). NOT verified on a device and NOT against a real backend. Not pushed, not merged.

## What changed

Code branch `fix/flutter-auth-refresh` (worktree `D:\vive_codding\fix_wt`), two new commits on top of `cba36ac`:

| Commit | Content |
|---|---|
| `fa6cf1a` | H1, M1, M3: cold start no longer clears tokens on a surviving 401/403; single navigation after expiry |
| `8a1838e` | H2: logout sends `refreshToken` so the server revokes the refresh session |

Files (all under `flutter_app/`):

- `lib/app/core/network/cold_start_session.dart` (new): `resolveColdStartSession`, enum `ColdStartOutcome { proceedLoggedIn, showOnboarding, alreadyAtLogin }`.
- `lib/app/modules/splash/splash_view.dart`: removed `_refreshSession` and its token wiping; maps the outcome to navigation; `alreadyAtLogin` does nothing.
- `lib/app/core/network/logout_flow.dart` (new): `LogoutFlow` (body building, in-flight guard, clear in `finally`).
- `lib/app/modules/profile/controllers/profile_controller.dart`: `logout()` uses `LogoutFlow`; account deletion untouched.
- `test/cold_start_session_test.dart` (new), `test/logout_flow_test.dart` (new).

## Behaviour

Cold start and logout behaviour is specified in FL-B07 and FL-B08 (follow-up sections). In short: offline, refresh timeout and refresh 5xx keep the session; a rejected refresh (400/401/403) or a legacy session without refresh token ends in exactly one navigation to LoginView; a 403 never clears anything; a guest goes to onboarding. Logout sends `{deviceIdentifier, refreshToken}` only when a non-empty refresh token is stored.

Backend contract for logout (re-read): `logoutSchema` in `auth.schema.ts` is `{deviceIdentifier: string min 1, refreshToken?: string min 1}` and `.strict()`; `auth.services.ts` calls `revokeUserSession(refreshToken)` when present, which deletes the hashed Redis key; a later `/auth/refresh` then fails with 401 `TOKEN_BLACKLISTED`.

## Test results versus baseline

| | Baseline (cba36ac) | Now |
|---|---|---|
| `flutter analyze` | 34 issues | 34 issues (same set; nothing in the changed files) |
| `flutter test` | 57 pass, 1 fail | 83 pass, 1 fail |

The single failure is the pre-existing template `test/widget_test.dart` "Counter increments smoke test". It was not modified, skipped or deleted. 26 tests were added (cold start, logout).

Mutation check: removing `refreshToken` from the logout body failed 4 logout tests; making the cold-start resolver clear the store on an exception failed 4 cold-start tests (8 failures in total). Both mutations were reverted before committing.

## Backend observations (nothing in `backend/` was edited)

1. Account deletion does not revoke refresh sessions (known-issues S-24). `profile.routes.ts` `DELETE /profile` has no body schema; `deleteAccountService` soft-deletes, blacklists the access token and does not touch refresh sessions; it takes no `refreshToken`, so the app sends none. Mitigation today: `rotateUserSession` rejects non-ACTIVE accounts and deletes the key, so a deleted account's refresh token cannot be rotated.
   Proposed separate backend task (not implemented): revoke all refresh sessions on account deletion. Redis keys are hashed per token with no per-user index, so this needs either a per-user session set (index of token hashes) or a token-version claim checked in `rotateUserSession`.
2. `POST /auth/logout` revokes whatever refresh token is supplied without checking it belongs to the caller (known-issues S-25). Low risk because tokens are unguessable.

## Remaining risks

- Logout with an already expired access token returns 401, so the refresh session stays valid on the server until TTL (best effort, documented, no workaround added).
- Uploads (`FormData`) are not resent after a refresh (B-34, unchanged).
- Refresh tokens are stored unencrypted in GetStorage (S-10) and the app accepts any TLS certificate (S-05); both pre-existing.
- `get_storage` writes are not atomic and `await write()` does not wait for the disk flush: a crash within milliseconds of a rotation can cost one re-login.
- On a transient failure at cold start the user sees the dashboard with an expired access token until connectivity returns.
- The splash widget mapping, GetX navigation and snackbars are not exercised by automated tests.

## Not verified

No device run, no real backend, no real token expiry, no staging. The manual checks listed in FL-B07 and FL-B08 "Done when" remain open.

## History

The existing branch history (`cba36ac` and everything before it) is preserved: only new commits were added on top, with no rebase, reset, amend or force. The review report on its own branch is unchanged. This report lives on branch `docs/flutter-auth-followup`, created from `docs/flutter-auth-status` at `ef219e2`.
