# REL-HF: Release checkpoint, Hotfix track (branch from `main`, ship before M1)

| Field | Value |
|---|---|
| Stack | release |
| Depends on | HF-001, HF-002, HF-003, HF-004 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

HF-001 to HF-004 (S-17 verify, B-16, S-04, S-19). Branch from `main`. No migrations. Suggested version bump: PATCH.

## 1. Review

- [ ] Each HF task has its evidence in the PR (HF-001: test and staging output; HF-004: the reproduction result either way).
- [ ] Behaviour changes called out in the PR text: revoked tokens are now refused (HF-003); reset without OTP is refused (HF-004); bad Stripe signatures give 400 (HF-002).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] FIRST ACTION: confirm how staging is deployed and which database it uses. `backend/docs/release-management.md` documents only the production tag flow; the staging process is ⚠️ UNVERIFIED. Write the answer into this file.
- [ ] Deploy the hotfix branch/tag to staging and apply no migrations (none in this release).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] `GET /admin/users?page=1&limit=50` as admin: no item has a `password` key (HF-001).
- [ ] `POST /webhooks/payment/stripe` and `POST /connect/webhook` with no signature and with a wrong one: 400; with a Stripe test event signed correctly: 200 (HF-002).
- [ ] Log in, log out, replay the old access token on a protected route and on the socket handshake: both refuse it (HF-003).
- [ ] Admin forgot-password: full flow works; skipping the verify step returns 403 and the password does not change (HF-004).
- [ ] Normal login, one ticket purchase in Stripe test mode and one webhook delivery still succeed (regression).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

No migrations in this release, so rolling back is safe: set `IMAGE_TAG` to the previous tag (`release-management.md` section 4). Rolling back reopens S-04, S-19 and B-16; do it only if the hotfix itself breaks login or payments.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
