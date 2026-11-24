# REL-M10: Release checkpoint, M10 Settlement, payouts and ledger

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-123, T-124, T-125, T-126, T-127, T-128, T-129, T-130, T-131, T-132, T-133 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

Separate charges and transfers with the transfer 3 calendar days after event end (ADR-006). Migration 16.

- T-123 Migration: settlement arrangement, ledger entries, transfers (backend, 0.5 day)
- T-124 Settlement setup: admin share, owner proposal, organizer acceptance before sales open (backend, 0.5 day)
- T-125 Fallback routing to the eligible club and flags for ineligible payees (backend, 0.5 day)
- T-126 Ledger and share states: Pending, then Confirmed - scheduled for transfer with the expected date (backend, 0.5 day)
- T-127 Scheduler job: initiate transfers 3 calendar days after event end (backend, 0.5 day)
- T-128 Hold the amount affected by an open refund or dispute and release the rest (backend, 0.5 day)
- T-129 Failed transfers: retry up to 3 times in 3 days, immediate notices, idempotency (backend, 0.5 day)
- T-130 Transfer reversals after refunds (full and partial) and the unrecovered amount (backend, 0.5 day)
- T-131 Connect webhook events for transfers and payouts into the ledger (backend, 0.5 day)
- T-132 Partner statements and settlement reports (owner and admin) (backend, 0.5 day)
- T-133 Demonstration pack: one partially refunded order and one insufficient partner balance (backend, 0.5 day)

## 1. Review

- [ ] Stripe spikes (T-090, T-092) passed on the client account and the payout eligibility report for Italy, France, Monaco, Spain and the US is attached.
- [ ] Holding limits for advance sales and how the platform keeps enough available balance are answered in writing (client asks for this).
- [ ] Transfers are switched off by a setting until the product owner enables them in production.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 16; scheduler and worker images included.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] EUR 10 ticket: ledger shows EUR 1 platform, EUR 2 organizer, EUR 7 club (T-124).
- [ ] Event ended 3 days ago: the transfer job initiates exactly one transfer per partner (T-127).
- [ ] Force a failed transfer: three retries over three days and an immediate notice (T-129).
- [ ] Open refund on one order: only the affected amount is held, the rest is released (T-128).
- [ ] Partially refunded order and an insufficient partner balance demonstration (T-133).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Keep transfers disabled until the first pilot event and confirm the platform balance covers it.
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

turn transfers off by the setting; ledger rows stay. Transfers already made are corrected only by reversals through the ledger, never by deleting rows.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
