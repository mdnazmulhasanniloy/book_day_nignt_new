# REL-M6: Release checkpoint, M6 Analytics, refunds, admin orders

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-059, T-060, T-061, T-062, T-063, T-064, T-065, T-066, T-067, T-068, T-069 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-059 to T-069. Migrations 13 and 7. Suggested bump: MINOR.

## 1. Review

- [ ] Migration 13: decision recorded on CONCURRENTLY from the `Order` row count; if the db-migrator cannot run it, the two index statements are applied by hand BEFORE deploy (record who and when).
- [ ] T-064 (only FULL refunds invalidate entry) is in this release, together with or before T-066.
- [ ] Client notice 1 (owner earnings now include tables) is sent to the client before the release (T-060).
- [ ] Q8 (partial refunds) and Q9 (inventory on refund) answers, or the written defaults (B and no), are confirmed by the product owner.
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
