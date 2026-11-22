# REL-M1: Release checkpoint, M1 Security and correctness

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-011, T-012, T-013, T-014 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-001 to T-014. Migration 5 (add_tier_on_purchase). New worker job `expireEventTicketHold`. Suggested bump: MINOR.

## 1. Review

- [ ] All tasks T-001 to T-014 merged; rehearsal report for migration 5 attached (restore time, migration time, soldCount totals before and after equal).
- [ ] Run `reports/stock-leak.sql` on a restored COPY of production data (by someone with access) and give the summary to the product owner: this fills 'Client notices' item 3 in `blockers.md`. Nothing is corrected automatically.
- [ ] Review the status-code changes against `api-spec-diff-v2.md` (no 401/403 on business failures).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 5. Confirm `EventTicketTier.soldCount` sums are unchanged (query before and after).
- [ ] Confirm the worker registered `EXPIRE_EVENT_TICKET_HOLD` (queue list).
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] `PUT /event/{id}` on a test event with sold tickets (with and without tier ids): `soldCount` and tier ids unchanged (T-004).
- [ ] Buy a ticket (Stripe test card): purchase has `ticketTierId`; `GET /bookings/{id}` returns it (T-006).
- [ ] Start a purchase and let it expire (or use a failing test card): `soldCount` returns to the earlier value once (T-007, T-008).
- [ ] `POST /auth/social` with a test token lacking DOB returns `profileComplete: false` (T-009).
- [ ] Status codes: admin refresh with a bad token 401; suspend unknown user 404; `GET /club/{random}` 404; `verify-ticket` unknown order 404 (T-010 to T-013).
- [ ] Owner scans a valid test ticket: 200; scans it again: 409 (T-011).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Previous image works on the migrated database (migration 5 only adds nullable columns and indexes). Rolling back loses the stock release and the in-place tier update (B-24 returns). Delayed `expireEventTicketHold` jobs already in Redis will be unknown to the old worker: clear them from the queue or let them fail and discard them. Purchases made on the new version keep their `ticketTierId`, which the old code ignores.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
