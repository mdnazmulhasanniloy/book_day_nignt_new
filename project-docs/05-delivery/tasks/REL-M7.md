# REL-M7: Release checkpoint, M7 Admin app

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-070, T-071, T-072, T-073, T-074, T-075, T-076, T-077, T-078, T-079 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-070 to T-079 (admin app only, no migrations). Requires the backend endpoints from REL-M3 to REL-M6 to be live.

## 1. Review

- [ ] Every changed page has loading, empty, error and success states (tests from each task).
- [ ] No page calls an endpoint that is not in `api-spec.yaml`; en and it strings complete.
- [ ] Read `admin/.github/workflows/deploy.yml` before the first admin release to confirm how and where the admin app is deployed (not verified in this plan).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run lint` and `npm run build` green in CI for `admin/`.

## 2. Staging deploy

- [ ] Deploy the admin build to the staging admin against the staging API.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Log in as admin; open every new page: Cities, Filter options, Artists, Organizers, Collaboration requests, Pricing rules, Financials, Orders, Refund requests, Refunds.
- [ ] Create and end-date a pricing rule; approve and reject a refund request on test data; open an order detail.
- [ ] Existing pages still work: Dashboard, Users (no password field in the network response), Earnings, Settings (v1 commission form).
- [ ] Session expiry: a 401 on refresh logs the admin out cleanly (T-010).

## 4. Production deploy

- [ ] Deploy the admin app as `admin/.github/workflows/deploy.yml` does (confirm first), then run the smoke list against production with an admin test account.
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Redeploy the previous admin build (static app). No database or API change is involved. The new pages disappear; data created through them stays.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
