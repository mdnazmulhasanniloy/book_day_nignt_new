# REL-M3: Release checkpoint, M3 Fees and commissions

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-022, T-023, T-024, T-025, T-026, T-027, T-028, T-089, T-093, T-094, T-095, T-096, T-097, T-098, T-099 |
| Status | not started (rebuilt for the client rates, 2026-11-24) |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-022 to T-028. Migration 6 with the v1 write-through (ship together). Suggested bump: MINOR. Highest-risk release: changes live `Order` CHECK constraints.

## Update 2026-11-24 (client answers 2)

Phase 2. Fees and commissions are rebuilt around the client rates (ADR-003 amended): Technical Fee 5% plus EUR 0.50 once per order, Service Fee 10%/15%, overrides by country, category, club, event and table or quote. The server-calculated total, the version-policy endpoint and the gate ship in this same release together with the Flutter change (REL-M8). The old `/service-charge` and the old purchase response keep working for old app versions.

Tasks added to this checkpoint:

- T-089 Version policy endpoint and minimum supported version setting (backend, 0.5 day)
- T-093 Fee rule: percent plus fixed part, fixed once per order, fixed amount per currency, country and quote scopes (backend, 0.5 day)
- T-094 Fee allocation per item and rates saved on the order, for partial refunds (backend, 0.5 day)
- T-095 Record the actual processor cost per payment and per issued ticket, separate from commission (backend, 0.5 day)
- T-096 Server-calculated total: POST /v2/checkout/preview for tickets, tables, extras and baskets (backend, 0.5 day)
- T-097 Display mode per market and category (itemized or included) in the preview response (backend, 0.5 day; blocked: inclusive-display markets (Q2))
- T-098 Keep /service-charge and the old purchase response working for old app versions, with tests (backend, 0.5 day)
- T-099 Minimum-version enforcement switch: fee model v2 active only when the gate is on (backend, 0.5 day)

Additional review items:

- [ ] Terminology in new text: Technical Fee (customer) and Service Fee (partner).
- [ ] Do not switch fee model v2 on until the minimum-version gate is on and the new app is in the stores (ADR-012); the switch has its own rollback.
- [ ] Wording and display per market is validated by the client's adviser before activation (sample orders per market).

Additional smoke checks (staging, then the read-only subset on production):

- [ ] `POST /v2/checkout/preview` for a EUR 20 ticket returns 21.50 and for two tickets 42.50; a free ticket returns 0.
- [ ] Old app path: `GET /service-charge` and `POST /purchase/event` responses are byte-identical to before for an old client (golden test).
- [ ] `GET /v2/app/version-policy` returns the minimum version setting.

Rollback additions: turn the fee model v2 switch off first; migration 6 stays (forward-only). The v1 write-through keeps `/admin/commission` and `/service-charge` consistent.

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
