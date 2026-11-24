# REL-M4: Release checkpoint, M4 Discovery backend

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-029, T-030, T-031, T-032, T-033, T-034, T-035, T-036, T-037, T-038, T-039, T-040, T-041, T-042, T-043, T-044, T-045, T-046 |
| Status | not started. All M4 backend tasks T-029 to T-046 are done in code (tested locally, not deployed); release checkpoint items not run. No boxes ticked |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-029 to T-046. Migrations 3, 10, 11, 12. Seed script for cities and filter options (needs the client's content, see `blockers.md`). Suggested bump: MINOR.

## 1. Review

- [ ] Rehearsal reports for migrations 3, 10, 11, 12 attached (geog row counts, filter option counts).
- [ ] Client content received for the genre/mood starter list and city seed list, or the seed is explicitly postponed (T-032 status).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migrations 3, 10, 11, 12. Run `seed-discovery` on staging with the real files if available.
- [ ] Confirm the scheduler registered `flushEventViews` (one instance only, B-12).
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] `GET /cities?q=...` returns seeded cities (or an empty list if the seed is postponed).
- [ ] `GET /explore` with no new params: same results as before; with `radiusKm=50` and `cityId`: `distanceKm` present.
- [ ] `group=day` shows Today/Tomorrow/This Weekend/Upcoming for an overnight test event.
- [ ] `GET /explore/filters`, `GET /explore/map`, `sort=trending`, `GET /explore/most-viewed` respond.
- [ ] Mark Interested twice: count 1; remove: count 0. Open an event detail several times: after a minute `EventViewDaily` has the views.
- [ ] `GET /artists`, `GET /artists/{id}`; `GET /bookings?bucket=FUTURE`.
- [ ] Duplicate an event: it appears in a geo search (T-030).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Previous image works (new tables and columns are unused by old code; `geog` backfill is harmless). Rolling back stops the view flush, so Redis day hashes stop being written to the database (they have a 3-day TTL, T-041) and trending falls back to lifetime counts. Seeded cities and options stay in the database.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
