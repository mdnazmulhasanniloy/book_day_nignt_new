# REL-M11: Release checkpoint, M11 Multi-day passes, scanning, no-show

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-146, T-147, T-148, T-149, T-150, T-151, T-152, T-153, T-154, T-155, T-156 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

Event days, per-day credentials and capacity, the v2 scan endpoint, no-show job, guest-list hold, tier progression and badges (ADR-013). Migration 18; migration 22 columns used here. v1 `POST /owner/verify-ticket` stays.

- T-146 Migration: event days, pass day entitlements, entry scans (backend, 0.5 day)
- T-147 Per-day capacity from the venue capacity, offline allocations, floor on commitments (backend, 0.5 day)
- T-148 One credential per covered day under the same pass; one place reserved per date (backend, 0.5 day)
- T-149 v2 scan endpoint: per day, repeated scan refused, two doors at once, wrong day or event (backend, 0.5 day)
- T-150 Entry cutoff per day (default event end) and the no-show job per day (backend, 0.5 day)
- T-151 Guest-list approval hold (24 h default, 1-72 h, capped by entry cutoff) and release on expiry (backend, 0.5 day)
- T-152 Tier auto progression on sellout and the startingPrice field (v2 shape) (backend, 0.5 day)
- T-153 Availability badge LAST_TICKETS at 20% or less, exact counts hidden from public responses (backend, 0.5 day)
- T-154 Venue staff reduce online inventory for offline sales, never below commitments (backend, 0.5 day)
- T-155 Analytics: scans, no-shows and attendance rate (CR-08 remainder) (backend, 0.5 day)
- T-156 Access codes: purpose, event or list, expiry, use limit; guest-list code requests (backend, 0.5 day; blocked: priority (Q19))

## 1. Review

- [ ] Old scanner (v1 verify-ticket, per-order check-in) still works for single-day tickets unchanged (golden test).
- [ ] Public responses never expose exact remaining stock (only the badge) in the v2 shape; v1 shape unchanged.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 18 (and 22 if not yet applied).
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Two-day pass: two credentials; scan Friday: valid; scan Friday again: refused as used (T-149).
- [ ] Last Friday place sold while Saturday-only stays on sale (T-147).
- [ ] No-show job at the Friday cutoff marks Friday only; Saturday stays valid (T-150).
- [ ] Guest-list request expires after the hold time and the place is released (T-151).
- [ ] Event page shows From price and Last tickets at 20% or less (T-152, T-153).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

new tables are unused by the old image; per-day credentials already issued stay in the database but only the v2 scanner understands them, so keep the v2 scanner build in the stores until the next release.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
