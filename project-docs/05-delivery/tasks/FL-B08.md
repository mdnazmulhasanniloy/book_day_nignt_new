# FL-B08: Flutter token refresh (B-08)

| Field | Value |
|---|---|
| Stack | flutter |
| Milestone | M8-early |
| CR / BUG IDs | B-08 |
| Depends on | FL-B07 (same interceptor and logout path) |
| Size | at most one day |
| Status | implemented and unit/integration-tested in Docker on branch `fix/flutter-auth-refresh` (cba36ac, follow-ups fa6cf1a and 8a1838e); NOT verified on a device or against a real backend |

Branch: from `main` (`fix/flutter-token-refresh`) once the Flutter SDK is available.

## What the code does today (verified by reading)

- CORRECTION (verified 2026-11-22): email login did NOT store the refresh token. `sign_in_controller.dart` saved only the access token, role and device id; only the social path saved `AppConst.refreshToken`. The backend login response does include `refreshToken`; the app dropped it. Fixed on `fix/flutter-auth-refresh` (both login paths now store it).
- Nothing ever calls the refresh endpoint. `EndPoint` has no refresh constant. The splash "refresh" is `POST /auth/check`, not a token refresh.
- Backend: `POST /auth/refresh` with body `{ "refreshToken": "<token>" }` (`refreshTokenSchema`, strict). It verifies the JWT, looks the token's hash up in Redis, **deletes it (single use, rotation)**, then issues a new session (new access and refresh token). A second use of the same refresh token returns 401 `TOKEN_BLACKLISTED`.

## The important constraint

Because the refresh token is single-use, two requests failing with 401 at the same moment must NOT each call refresh: the second call would fail and log the user out. Refresh must be single-flight.

## Plan

1. Add `EndPoint.REFRESH = '/auth/refresh'`.
2. Add a Dio interceptor (a `Completer`-based single-flight) in `BaseClient`:
   - On a 401 whose request is not an auth endpoint and not already retried (`extra['retried']`), start ONE refresh; all other 401s await the same future.
   - Refresh uses a separate bare Dio (no interceptors) to avoid recursion.
   - On success: save both new tokens, replace the `Authorization` header on the failed request, retry it ONCE.
   - On failure (non-2xx or no refresh token): run FL-B07's logout path. Never retry a retry (no infinite loop).
3. Repositories set the header themselves, so the retry must overwrite `Authorization` on the cloned `RequestOptions`. A consumed multipart `FormData` body cannot be resent: for uploads, return the 401 to the caller after refreshing so the caller retries.
4. Verify the response field names for the new tokens against `issueUserSession` in `backend/server/src/app/utils/session.utils.ts` before coding (read the real response, do not guess).

## Done when

- [ ] Unit tests with a fake Dio adapter: a single 401 refreshes then succeeds; 5 parallel 401s cause exactly one refresh call; refresh failure logs out once and does not loop; a retried request that 401s again does not refresh again; `/auth/login` 401 never refreshes; a multipart upload is not resent with a consumed body.
- [ ] `flutter analyze` clean, `flutter test` green.
- [ ] Manual: short-lived access token on a local backend, use the app past expiry with no forced re-login; revoke the refresh token in Redis, the next call logs out.
- [ ] No backend change (the endpoint already exists).

## Risks

- Any code path that bypasses `BaseClient` (direct Dio use) will not refresh. Grep for `Dio(` before closing.
- `MediaService`: HF-005 now requires auth on `/media`, so an expired token fails uploads with a generic error until this lands.

## Verified response shape and implementation status (2026-11-22)

`POST /auth/refresh` with body `{ "refreshToken": "<token>" }` returns `{ "success": true, "message": "...", "data": { "token": "<new access>", "refreshToken": "<new refresh>" }, "traceId": "..." }`. The new access token is `data.token` (not `accessToken`). The refresh token is single use (rotated).

Implemented on `fix/flutter-auth-refresh` (commit cba36ac), together with FL-B07; see FL-B07 for the file list.

- Single-flight: one in-flight Future shared by all concurrent 401s; a late 401 that sent an already replaced access token reuses the stored one instead of refreshing again.
- Rotation: the second refresh uses the NEW refresh token (tested). Both tokens are written through one helper (`AuthTokenStore.saveSession`), in the same turn; a refresh response missing either token overwrites nothing and does not log out. CORRECTED persistence statement (verified by reading `get_storage` 2.1.1): `write()` updates the in-memory map synchronously and both keys written in the same turn are flushed together, so the running app never reads a mixed pair. But `await write()` does not wait for the disk flush and the file write is not an atomic rename, so a crash or kill within milliseconds of a rotation can leave the previous (already consumed) pair on disk, which costs one re-login. GetStorage writes are not atomic or crash-proof, and this task does not claim they are.
- Retry once (`extra['retried']`), `Authorization` header replaced on the cloned request. Covers `getBytes` and `getAuthorizedFile` because the interceptor sits on the Dio instance. Consumed `FormData` bodies and download streams are not resent: after a successful refresh the caller gets the original 401 and retries itself (so the multipart methods and `uploadFile`/`uploadMultipleFiles`/`uploadFromBytes` still show one error on the first expired upload).
- Login: email and social paths store both tokens through `persistLoginSession`. Sign-up and OTP verify do not create a session in the app (verify returns to LoginView), so nothing else saves tokens; logout, account deletion and splash clear the refresh token too.
- Not verified: device behaviour, real backend, real token expiry. `flutter analyze` 34 issues (3 warnings, 31 infos), identical to the baseline; `flutter test` 57 pass, 1 fails, the failing one being the pre-existing template `widget_test.dart` "Counter increments smoke test" (also failing at baseline).

## Follow-up after independent review (2026-11-22): logout revokes the refresh session (H2)

Code commit `8a1838e` on `fix/flutter-auth-refresh`; logic in `core/network/logout_flow.dart` (`LogoutFlow`), used by `profile_controller.dart`.

Before: logout posted only `{deviceIdentifier}`, so the refresh session stayed valid on the server until its TTL (3 or 30 days). Now `POST /auth/logout` sends `{deviceIdentifier, refreshToken}` when a non-empty refresh token is stored (backend `logoutSchema` is strict: only those two keys; `refreshToken` is `min(1)` optional, so it is never sent empty or null). With it the server runs `revokeUserSession`, and a later `POST /auth/refresh` with that token returns 401. Legacy sessions without a refresh token send the old body. Local credentials (access token, refresh token, role, plus deep-link and notification hooks) are cleared in `finally`, also when the request fails; duplicate taps send one request; `/auth/logout` stays a skipped path (a 401 there does not refresh and does not trigger the expired handler).

Known limitation (not worked around): logout requires a valid access token. If the access token is already expired, the call returns 401, the server-side refresh session is not revoked, and the user is signed out locally only (best effort).

Account deletion (`DELETE /profile`) is unchanged: the backend route has no body schema and `deleteAccountService` soft-deletes the account and blacklists the access token but does not revoke refresh sessions, so the app sends no refresh token there. Mitigation that exists: `rotateUserSession` rejects non-ACTIVE accounts (and deletes the key). See known-issues S-24 and the proposed backend task in the follow-up report.

Not covered: the upload not being resent after a refresh (known-issues B-34) is unchanged.
