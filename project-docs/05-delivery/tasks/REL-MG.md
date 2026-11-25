# REL-MG: Release checkpoint, MG Partner approval gate (migration 1)

| Field | Value |
|---|---|
| Stack | release |
| Phase | 1 |
| Depends on | T-080, T-081, T-082, T-083 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-080 to T-083. Migration 1 (partner approval). Closes BUG-S03 for new signups. Suggested bump: MINOR.

- T-080 Migration: partner approval status, application table, backfill existing owners as approved (backend, 0.5 day)
- T-081 Signup and social sign-in: new club owners and organizers start PENDING; partnerStatus added to auth responses (backend, 0.5 day)
- T-082 Partner gate middleware: 423 PARTNER_APPROVAL_PENDING (never 401/403) with the club-area home allowed (backend, 0.5 day)
- T-083 Admin endpoints: list, approve, reject partner applications, with notification (backend, 0.5 day; blocked: D12 (named approvers))

## 1. Review

- [ ] Migration backfill: every existing owner is APPROVED (client Q23); count rows before and after on the restored dump.
- [ ] The pending answer is HTTP 423 `PARTNER_APPROVAL_PENDING`, never 401 or 403, because the live app treats 401/403 as a dead session (ADR-010).
- [ ] Named approvers (checklist item 12) exist before production is switched on.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 1.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Sign up as a new club owner: `partnerStatus` PENDING in the response; `POST /club` returns 423 `PARTNER_APPROVAL_PENDING`; the club-area home endpoint still answers.
- [ ] Log in as an existing owner (from the restored dump): `partnerStatus` APPROVED and every owner call works.
- [ ] Admin approves the pending account: the next owner call succeeds.
- [ ] Old app build against staging: a pending owner sees a message and is NOT logged out.

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

the old image ignores `partnerStatus` and the new table; pending accounts created meanwhile would act as owners again, so list them before rolling back and approve or review them after.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
