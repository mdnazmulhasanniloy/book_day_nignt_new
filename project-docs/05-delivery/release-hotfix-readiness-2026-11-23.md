# Hotfix release readiness (2026-11-23)

Status: **code complete, not released.** Waiting for a staging environment and your explicit approval. Nothing was pushed, tagged or deployed. The release checklist itself is `tasks/REL-HF.md`; this note only records where each item stands.

## What is in the release

Branch `release/hotfix`, cut from `main`, five commits, no migrations, no new dependencies:

| Commit | Task | Change |
|---|---|---|
| `08c86c8` | HF-002 | Stripe webhooks return 400 on a missing or invalid signature instead of 500 |
| `2cdd951` | HF-003 | Token revocation is read with the same key that logout writes, so revoked tokens are refused (REST and socket) |
| `f3b3220` | HF-004 | Password reset now requires a verified OTP first; skipping the verify step returns 403 |
| `3fa8264` | HF-005 | `POST /media` and `DELETE /media` require a signed-in account (mobile token, or admin session with CSRF) |
| `d9b895b` | HF-005 | `backend/openapi.yaml` updated for `/media` |

HF-001 (no password hash in admin user lists) needs no code: the fix was already in the code base. It only needs the check on staging.

Kept out on purpose, ships separately: `feat/media-ownership` (adds a table and a migration; ownership-based delete).

## Evidence so far

| Check | Result |
|---|---|
| `npm test` on `release/hotfix` | 28 of 28 pass |
| `tsc --noEmit` | clean |
| Migrations in the release | none |
| Backend code identical to the source hotfix branches | yes (compared) |
| Staging smoke list (REL-HF section 3) | **not run** |
| `npm run lint` | not run: skipped repo-wide (TypeScript 7 vs the linter) |

## Blockers before staging

1. **No staging environment or deploy stage is documented.** REL-HF says a `v*` tag deploys straight to production in the old workflows. Do not tag until a staging stage exists or you waive it in writing.
2. **No CI runs in this repository.** The workflows sit under `backend/.github/workflows`, which GitHub ignores inside a monorepo. This also means the CI job added on `ci/backend-tests` does not run yet. Root-level workflows are needed first (REL-HF section 2 describes this).
3. **Your approval** for any push, tag or deploy.
4. **Spec gap:** HF-002 to HF-004 changed behaviour but have no API-spec entry (the 403 on reset without OTP, the 400 on a bad Stripe signature). Add these when the release is documented.

## Release note text (draft, client-facing)

- A password reset now needs the emailed code to be confirmed first. Someone who only knows an email address can no longer reset a password.
- Logging out now really ends the session: a signed-out token is refused everywhere.
- Payment notifications with a missing or wrong signature are rejected cleanly.
- Uploading or deleting media now requires being signed in. The app and the admin dashboard already do this, so nothing changes for normal use.

## What to run on staging (short form of REL-HF section 3)

1. Admin user list: no password field in any item.
2. Stripe webhook with no signature and with a wrong one: 400. A correctly signed Stripe test event: 200.
3. Log in, log out, replay the old token on a protected call and on the socket: refused.
4. `/media` with no credentials: 401. With a mobile token and with the admin session: upload and delete work.
5. Admin forgot-password: full flow works; skipping verify returns 403 and the password does not change.
6. Normal login, one test-mode ticket purchase and one webhook delivery still work.

## Rollback

No migrations, so rollback is safe: point the image tag back to the previous version. It reopens the fixed issues, so do it only if the hotfix itself breaks login or payments.

## Decisions for you

- Ship `release/hotfix` alone first, or together with `feat/media-ownership`, `feat/t-004-tier-update` and `feat/t-009-social-dob`? Recommended: the hotfix alone and first, because it has no migrations.
- Who sets up the staging stage and root-level workflows, and when.
