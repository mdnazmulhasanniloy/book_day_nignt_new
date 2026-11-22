# REL-M3: Release checkpoint, M3 Fees and commissions

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-022, T-023, T-024, T-025, T-026, T-027, T-028 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-022 to T-028. Migration 6 with the v1 write-through (ship together). Suggested bump: MINOR. Highest-risk release: changes live `Order` CHECK constraints.

## 1. Review

- [ ] Rehearsal: CHECK-violation counts were 0 before migration 6 (attach).
- [ ] Q2 values are still not given by the client (2026-11-22); they are not required to ship: seeded rules reproduce today's values. The structure answers need the ADR-003 amendments first. Fee only on paid products is confirmed (T-026).
- [ ] Regression evidence from T-024 and T-025 (old formula equals new path on the sample set).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Run the CHECK-violation queries on staging data before deploying.
- [ ] Deploy; db-migrator applies migration 6 (NOT VALID then VALIDATE). Note the lock time.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Buy a ticket, a table and a club booking in Stripe test mode: totals equal the pre-release values; the Order has rule ids.
- [ ] `PATCH /admin/commission` (v1) then `GET /v2/admin/pricing-rules`: the change appears as a new GLOBAL rule; the previous one is end-dated.
- [ ] `PATCH /admin/service-charge` likewise.
- [ ] Create a future pricing rule through v2, then confirm orders made now ignore it.
- [ ] Free tier checkout returns `freeCheckout: true` and a ticket (T-026).
- [ ] `GET /v2/admin/financials`: fee, commission and proceeds shown separately.
- [ ] Deprecated v1 routes return `Deprecation: true`.

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

The previous image still runs (the new `Order` CHECKs are weaker than the old ones, and the new columns are ignored). BUT the old code's `PATCH /admin/commission` and `/service-charge` will not write through, so `PricingRule` and the v1 tables diverge: after a rollback, do not change commission or service charge until the release is re-applied, or re-sync by hand. Orders already priced by rules keep their rule ids. Free orders already created remain valid. Treat migration 6 as forward-only once rule-based orders exist.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
