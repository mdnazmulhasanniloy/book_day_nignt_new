# Independent review: Flutter auth refresh and DOB picker (2026-11-22)

Reviewed: `fix/flutter-auth-refresh` (`cba36ac`), `fix/flutter-dob-picker` (`02e432b`), `docs/flutter-auth-status` (`ef219e2`). Reviewer: the main session, independently of the implementing agent (code read in full, analyzer and tests re-run in Docker, `get_storage` 2.1.1 source read). No implementation code was changed, nothing was pushed, merged or deployed.

## 1. Summary and risk

| Branch | Verdict | Risk |
|---|---|---|
| `fix/flutter-dob-picker` | APPROVE | Low |
| `fix/flutter-auth-refresh` | APPROVE WITH CONDITIONS (fix H1 and H2 first) | Medium |
| `docs/flutter-auth-status` | APPROVE WITH CONDITIONS (correct the items in section 6 after the code fixes) | Low |

The refresh core is well built: single-flight, one retry, no recursion, correct response field, only a genuine rejection logs out. The two problems are around it, in code the branch touched or should have touched: the cold-start path in `splash_view.dart` can still log out a user whose refresh token is valid, and logout does not revoke the now-stored refresh token on the server.

**Overall recommendation: APPROVE WITH CONDITIONS.**

## 2. Findings

### Critical
None.

### High

**H1. Cold start can log the user out on a transient refresh failure.**
`flutter_app/lib/app/modules/splash/splash_view.dart`, `_refreshSession` (about lines 62-98).
The interceptor correctly returns the original 401 when the refresh fails transiently (offline, timeout, 5xx) and keeps the tokens. But `BaseClient._handleResponse` turns that 401 into `UnauthorizedException`, and splash catches `UnauthorizedException` and then removes the access token, refresh token and role. Scenario: access token expired, refresh token valid, device briefly offline at app start: the user is logged out and the still-valid refresh token is deleted. This defeats the stated goal "network errors do not clear the session" for exactly the cold-start case that was listed. Confirmed by code reading; not executed (the splash widget needs the full app).
Fix: in splash, do not clear credentials on `UnauthorizedException`. The interceptor already clears the session when refresh genuinely fails or no refresh token exists. On a surviving 401, keep the tokens and continue (or show an offline state). Add a test with a fake storage and a failing refresh.

**H2. Logout does not revoke the refresh token on the server.**
`flutter_app/lib/app/modules/profile/controllers/profile_controller.dart` (logout, about lines 245-275, body is `{"deviceIdentifier": ...}` only; account deletion has the same shape).
The backend `logoutSchema` (`backend/server/src/app/modules/auth/auth.schema.ts:115-118`) accepts an optional `refreshToken` and `revokeUserSession` deletes the Redis session. The app now stores the refresh token but never sends it, so after "logout" the server session stays valid until its TTL (3 or 30 days). The branch deletes only the local copy. The server-side session already existed before this change (the backend registered it at email login), but the app can now close it and does not.
Fix: send the stored refresh token in the logout and delete-account bodies (field already supported, no backend change), then clear locally. Add a test that the body contains it.

### Medium

**M1. Splash clears the session on 403, contradicting the docs.**
`splash_view.dart` same function: `on UnauthorizedException` (thrown for 401 and 403 by `base_client.dart` `_handleResponse`) and `on ApiException` with `statusCode == 401 || 403`. FL-B07 states "403 never touches the session". True for the interceptor, not for splash. The backend `/auth/check` chain currently returns 401, not 403, so there is no live trigger, but the code and the doc disagree. Fix together with H1, or correct the doc.

**M2. Token persistence is consistent in memory but not durable or file-atomic.**
`flutter_app/lib/app/core/network/auth_session.dart` `LocalAuthTokenStore.saveSession`; `get_storage` 2.1.1 `storage_impl.dart`.
Verified in the library source:
- In memory: `write()` updates the map synchronously, and `Future.wait` starts both writes in the same turn, so no reader ever sees a new access token with an old refresh token. Good.
- Disk: `write()` does not wait for the flush (`Microtask.exec` returns void, so `await write` completes before the file is written). Calls in one turn coalesce into one flush of the whole JSON, so both keys land together, but the file write is `setPosition(0)`, `writeFrom`, `truncate`, not an atomic rename. A crash or kill within milliseconds of a rotation can leave the previous pair on disk, whose refresh token the server has already consumed; the next refresh is rejected and the user re-logs in once. A torn write falls back to the backup file.
The claim "written together in one atomic step" in the code comment and FL-B08 is therefore only true in memory. Accepted risk: one extra re-login in a rare crash window. Document it, or move tokens to `flutter_secure_storage` (see M4).

**M3. Double navigation after session expiry at cold start.**
`auth_session.dart` `handleSessionExpired` does `Get.offAll(LoginView)`, then `splash_view.dart` continues and does `Get.offNamed(AppRoutes.onboarding)`, replacing the login screen. A legacy user (no refresh token) with an expired access token sees the "Session expired" snackbar and lands on onboarding, not login. Documented in FL-B07 as "existing behaviour" but it defeats the "redirect to login" requirement and the "no duplicate navigation" requirement. Fix with H1: let splash decide navigation from the post-refresh token state instead of navigating twice.

**M4. Long-lived credentials stored in plain text, with a global accept-all TLS override (pre-existing, amplified).**
`flutter_app/lib/main.dart` installs `MyHttpOverrides` accepting all certificates; tokens live in the unencrypted `GetStorage` file. The refresh token is a more valuable secret than the access token. Not introduced by this branch and out of its scope, but it raises the impact of both. Recommend a separate task: certificate validation and `flutter_secure_storage`.

**M5. Test coverage gaps (tests are real, but cover the units, not the wiring).**
`flutter_app/test/auth_refresh_test.dart` (27 tests) exercises the coordinator and the interceptor on a test Dio with a fake adapter. Not covered:
- `LoginController` really calling `persistLoginSession` (tests call the helper directly with a fake store);
- `LocalAuthTokenStore` on real `GetStorage`;
- the interceptor installed on the real `BaseClient`;
- the splash flow (H1, M1, M3);
- the sign-up screen showing the inline DOB error (only the picker is widget-tested).
The tests that exist are meaningful: the agent mutated the code (removed single-flight) and the parallel-401 test failed. I did not find tests written to pass vacuously.

### Low

- **L1.** `auth_refresh_coordinator.dart` `_doRefresh`: a 2xx refresh response with an access token but no refresh token discards the new access token and keeps the old pair, although the server already consumed the old refresh token. The next refresh is then rejected. The backend always returns both, so this is an edge case; prefer saving the access token and dropping the refresh token.
- **L2.** `LocalAuthTokenStore.clearSession` removes three keys with sequential awaits (separate flush windows); a kill in between leaves a stale refresh token with no access token. Harmless (no session without an access token).
- **L3.** DOB equivalence with the backend is tested against a Dart port of `assertSignupDob`, not the real backend vectors. Add golden vectors copied from `backend/server/src/app/utils/dob.utils.test.ts`.
- **L4.** New files use LF while the repo uses CRLF (git normalizes); one `// ignore: constant_identifier_names` for `EndPoint.REFRESH`.
- **L5.** Multipart uploads and download streams are not resent after a refresh: the caller sees one error on the first expired upload, for example `MediaService.uploadMedia` returns null and shows "Failed to upload media". Safe and documented, but a user-visible rough edge.

## 3. Requirement checklist

| Requirement | Result |
|---|---|
| Email and social login persist both tokens | Yes, via `persistLoginSession` (`sign_in_controller.dart`); sign-up and OTP verify create no session in the app. No other place saves the access token (grepped). |
| Reads `data.token` | Yes (`auth_session.dart` `bareDioRefreshCall`); matches `issueUserSession` and the controller response. |
| Rotation persisted safely | In memory yes, on disk best effort (M2). |
| Parallel 401s share one refresh | Yes (`_inFlight`); late 401 with a replaced token reuses the new one. |
| At most one retry | Yes (`extra['retried']`). |
| No recursion on refresh failure | Yes (bare Dio, `/auth/refresh` skipped). |
| Network, timeout, 5xx do not clear session | Yes in the interceptor; NOT at cold start (H1). |
| Genuine rejection clears exactly once | Yes (`_expired` guard, re-armed by a new session); navigation duplicated at cold start (M3). |
| 403 never triggers logout | Yes in the interceptor; no in splash (M1). |
| Raw downloads covered | Yes: `getBytes` and `getAuthorizedFile` use `_dio`. `ExploreRepository` and `ClubLocationRepository` create their own `Dio()` but send no `Authorization` header (grepped), so they are not authenticated calls. |
| Multipart retry documented and safe | Yes (not resent, 401 returned after refresh; L5). |
| Cold start with expired access token | Works when refresh succeeds; wrong on transient failure (H1) and navigates twice on expiry (M3). |
| DOB 18 years, UTC calendar | Yes: `latestAllowed` uses the UTC date like the backend; checked by 900-day loop and boundary tests. |
| Leap years | Correct: today 29 Feb maps to 28 Feb; a 29 Feb birthday turns 18 on 1 March in non-leap years, as the backend does. |
| Invalid DOB rejected without losing form data | Yes in the controller (returns early, only `dobError` set); picker cannot select under-18 dates. |
| Inline error displayed | Wired with `Obx` and `errorText`; compiles; not widget-tested (M5). |
| API payload unchanged | Yes (`toApi` untouched, UTC midnight ISO). |
| Club-owner age rule unchanged | Yes, left open (decision pending). |

## 4. Tests: independent re-run (Docker `ghcr.io/cirruslabs/flutter:stable`, Flutter 3.44.0 / Dart 3.12.0)

| Tree | `flutter analyze` | `flutter test` |
|---|---|---|
| `main` (baseline) | 34 issues | 30 pass, 1 fail |
| `fix/flutter-auth-refresh` | 34 issues, same set | 57 pass, 1 fail |
| `fix/flutter-dob-picker` | 34 issues, same set | 42 pass, 1 fail |

The single failure is the same test on all three trees, `test/widget_test.dart` "Counter increments smoke test" (the unmodified Flutter template, which never matched this app). It fails identically on the unmodified baseline, so it is pre-existing and unrelated. The numbers match the implementing agent's report exactly. Tests were run in detached review worktrees with a git-ignored fake `.env`; no branch or tracked file was changed.

## 5. Required before merge

1. Fix H1 (splash must not clear tokens on a surviving 401) with a test.
2. Fix H2 (send the refresh token on logout and account deletion) with a test.
3. Resolve M1 and M3 with the splash change, or document them as accepted with an owner.
4. Update the docs per section 6.

Recommended soon after, not blocking: M2 decision (accept or secure storage), L1, L3, and the wiring tests from M5.

## 6. Documentation accuracy

`FL-B07.md`, `FL-B08.md`, `FL-P01.md` are mostly honest (status says "NOT verified on a device", reproduction results are stated correctly, the original email-login error is corrected). Corrections needed:
- FL-B07: "403 still throws `UnauthorizedException` but never touches the session" is false for splash (M1). "Only a 401 ends a session" omits that splash clears on a surviving 401 (H1).
- FL-B08: the "written together" statement must say in-memory only, and note the disk durability caveat (M2). Add that logout does not yet revoke the refresh token (H2) until fixed.
- All three: the header line "Branch: from `main` ... once the Flutter SDK is available" is stale; the "Done when" boxes are unchecked although some items were done and tested.
- FL-P01: the controller test in "Done when" is still unchecked and no controller or widget test of the inline error exists (M5).

## 7. Device and backend integration tests still required

On a device or emulator, against a local or staging backend (not production):
1. Access token shortened to a few seconds: use the app past expiry, confirm silent refresh and no re-login; confirm the rotated refresh token works a second time.
2. Revoke the refresh token in Redis: next call logs out once and lands on login (not onboarding).
3. Cold start with an expired access token: (a) online, refresh succeeds; (b) airplane mode, session kept; (c) refresh rejected, login screen shown once.
4. Legacy session (no refresh token) with an expired access token: one "Session expired" message and login.
5. Parallel requests on one screen with an expired token: one `/auth/refresh` call in the server log.
6. Logout then replay the old refresh token against `/auth/refresh`: must fail (after H2).
7. Login, sign-up, OTP and password-recovery screens: 401 and validation errors still show inline (no refresh attempt, no redirect).
8. Upload a file with an expired token: one error, then success on retry; admin and mobile `/media` still work after HF-005.
9. Sign-up with a birth date exactly 18 years ago and one day later (including near midnight in a UTC+/- timezone): accepted vs blocked, matching the backend response.

## 8. Recommended merge order and dependencies

1. `fix/flutter-dob-picker` first: independent, low risk. Needs no backend change. Pending product answer on whether 18 applies to club owners (rule unchanged).
2. `fix/flutter-auth-refresh` after H1 and H2 are fixed (small follow-up commits on the same branch, no history rewrite).
3. `docs/flutter-auth-status` last, after the code is final, so the status text is true. It is based on `docs/phase2-updates`; it and `docs/t-004`, `docs/t-009` all edit `tasks/README.md` and `known-issues.md`, so merge the docs branches in sequence and resolve README row conflicts by hand.

Backend dependencies: none required for these branches. H2 uses the existing optional `refreshToken` field of `POST /auth/logout`. The Flutter work benefits from HF-005 (authenticated `/media`) being released with it, because an expired token now fails uploads. `feat/t-009-social-dob` adds a backend contract for a Flutter social DOB screen that does not exist yet (separate Flutter task).
