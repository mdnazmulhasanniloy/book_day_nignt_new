# REL-M5: Release checkpoint, M5 Organizer, tables, quotes, extras

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-047, T-048, T-049, T-050, T-051, T-052, T-053, T-054, T-055, T-056, T-057, T-058 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-047 to T-058. Migrations 2, 9, 8 (apply in that order). Suggested bump: MINOR.

## 1. Review

- [ ] Migration 2 adds enum values and cannot be undone: confirm the four names with the product owner before applying.
- [ ] Q1, Q3, Q4 and Q6f were answered by the client on 2026-11-22 as directions, but this release still ships no quote-to-payment, no payout split and no unregistered venues (they need the Stripe spike and new tasks). Say so in the release note.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migrations 2, 9, 8.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Create an organizer profile, follow it, view it as an anonymous user (T-049, T-050).
- [ ] Create a collaboration request to a club; accept it as the club owner; both notifications arrive (T-051).
- [ ] Create an event with `organizerId`; the event page shows the organizer (T-052).
- [ ] Create an extra, buy a table with the extra in Stripe test mode, let one order expire: extras stock is released (T-055 to T-057).
- [ ] `POST /purchase/module` on a STARTING_FROM module: 409 `QUOTE_REQUIRED` (T-056).
- [ ] `POST /v2/quotes` without a token: 401; with a token: stored with `userId`; v1 `POST /quotes` still works and is rate limited (T-058).
- [ ] Admin lists organizers and collaboration requests (T-053).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Previous image works (new tables and columns unused by old code). The four new `NotificationType` values stay (cannot be dropped); old code ignores notifications of those types only if its rendering does not break on unknown values: T-047 checks that, so verify on staging with the old image before relying on this. Rolling back hides organizer data and extras from the app but deletes nothing.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
