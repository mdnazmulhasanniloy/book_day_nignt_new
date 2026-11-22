# FL-B08: Flutter token refresh (B-08)

| Field | Value |
|---|---|
| Stack | flutter |
| Milestone | M8-early |
| CR / BUG IDs | B-08 |
| Depends on | FL-B07 (same interceptor and logout path) |
| Size | at most one day |
| Status | investigated, not implemented (no Flutter SDK on the dev machine) |

Branch: from `main` (`fix/flutter-token-refresh`) once the Flutter SDK is available.

## What the code does today (verified by reading)

- Login stores both tokens: `sign_in_controller.dart` saves `AppConst.accessToken` and `AppConst.refreshToken` (`'refreshToken'`).
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
