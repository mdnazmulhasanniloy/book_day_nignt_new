# REL-M6: Release checkpoint, M6 Analytics, refunds, admin orders

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-059, T-060, T-061, T-062, T-067, T-068, T-069, T-134, T-135, T-136, T-137, T-138, T-139, T-140, T-141, T-142, T-143, T-144, T-145 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-059 to T-069. Migrations 13 and 7. Suggested bump: MINOR.

## Update 2026-11-24 (client answers 2)

Phase 2. T-063 to T-066 are superseded by the refund engine (ADR-007): per-ticket cancellation, club authority, partner cost recovery, restock. T-067 (refund webhooks) and T-068 (admin orders) stay. Analytics tasks T-059 to T-062 stay and gain scans and no-shows in REL-M11.

Tasks added to this checkpoint:

- T-134 Migration: per-ticket status, refunds one-to-many, refund items, goodwill amounts (backend, 0.5 day)
- T-135 Cancellation policy per event (cutoff in hours or non-refundable), shown before purchase (backend, 0.5 day)
- T-136 Customer cancels one ticket in time: invalidate that credential, keep the others (backend, 0.5 day)
- T-137 Refund orchestration: admission refund, commission reversal, Technical Fee retained, pending until the processor confirms (backend, 0.5 day)
- T-138 Club exception refunds and documented partial goodwill refunds with admission kept (backend, 0.5 day; blocked: Italy goodwill treatment (adviser))
- T-139 Who may refund: owner, owner-permissioned organizer, staff forward requests, admin disputes (backend, 0.5 day)
- T-140 Partner cancellation: admission refund, commission reversal, Technical Fee refund flag per market (backend, 0.5 day; blocked: Technical Fee rule on partner cancellation (adviser))
- T-141 Partner debit and recovery: eligible balance, then future settlements, then invoice; never charged twice (backend, 0.5 day)
- T-142 Admin waiver down to the unrecovered Stripe cost, and the admin-only Charge to club action, with audit (backend, 0.5 day)
- T-143 Return eligible capacity on cancellation while sales are open; manual restock without double release (backend, 0.5 day)
- T-144 Date or venue change: notices, 7-day refund window, immediate route for a last-minute change (backend, 0.5 day; blocked: last-minute threshold (Q11))
- T-145 Refund and chargeback reconciliation against bank credits, no double reimbursement (backend, 0.5 day)

Removed from this checkpoint (superseded): T-063, T-064, T-065, T-066.

Additional review items:

- [ ] Q12/Q13: eligible voluntary refunds are automatic; the club decides exceptions; admin handles disputes only. The old admin-approves-everything flow must not ship.
- [ ] Technical Fee retained on customer cancellations; refunded only where law or terms require it; the market flag defaults are confirmed by the client adviser.
- [ ] Migration 17 makes refunds one-to-many: check every `order.refund` use in code was updated.

Additional smoke checks (staging, then the read-only subset on production):

- [ ] Cancel one ticket of three in time: that credential is invalid, the other two scan (T-136).
- [ ] Refund EUR 20 ticket plus EUR 1.50 Technical Fee: EUR 20 refunded (client example).
- [ ] Partner cancellation: customer refund and partner debit recorded separately (T-140, T-141).

Rollback additions: expand-only migration 17: old image ignores the new tables but cannot show per-ticket refunds; refunds already created stay valid.

## 1. Review

- [ ] Migration 13: decision recorded on CONCURRENTLY from the `Order` row count; if the db-migrator cannot run it, the two index statements are applied by hand BEFORE deploy (record who and when).
- [ ] T-064 (only FULL refunds invalidate entry) is in this release, together with or before T-066.
- [ ] Client notice 1 (owner earnings now include tables) is sent to the client before the release (T-060).
- [ ] Q8 and Q9 were answered by the client on 2026-11-22 (per-ticket cancellation; automatic restore of eligible capacity). The refund tasks T-063 to T-066 and T-078 are on hold for redesign; confirm the redesigned scope with the product owner before this release.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 7 (and 13 unless applied by hand). Check `indisvalid` on both indexes.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] `GET /owner/earnings` includes a table purchase; `GET /owner/analytics` and `/owner/events/{id}/analytics` reconcile with a known test set (T-060 to T-062).
- [ ] Owner requests a refund on a test order; admin approves a PARTIAL amount; the ticket can still be scanned once; a FULL refund blocks scanning (T-064 to T-066).
- [ ] Stripe test-mode refund webhook updates `Refund.status` (T-067).
- [ ] `GET /admin/orders`, `/admin/orders/{id}`, `/admin/refunds`, `/admin/refund-requests` respond within the paging cap (T-066, T-068).
- [ ] Cross-account suite green on staging data (T-069).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Previous image runs on the migrated database. WARNING: the old `verify-ticket` rejects ANY order that has a refund. If a PARTIAL refund exists, rolling back to an image older than T-064 blocks entry for that order: list such orders (`Refund.refundType = 'PARTIAL'`) before rolling back and handle them by hand. Refund requests and approvals made on the new version cannot be created or decided on the old one; pending requests stay in the table.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
