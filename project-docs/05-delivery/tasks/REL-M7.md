# REL-M7: Release checkpoint, M7 Admin app

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-070, T-071, T-072, T-073, T-074, T-075, T-076, T-077, T-079, T-100, T-175, T-176, T-177, T-178, T-179, T-180, T-181, T-182, T-183, T-184 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-070 to T-079 (admin app only, no migrations). Requires the backend endpoints from REL-M3 to REL-M6 to be live.

## Update 2026-11-24 (client answers 2)

Phase 2. T-078 (refund requests page) is superseded by T-179 (refund oversight, partner debits). New pages: partner approvals, roles and permissions, club teams, settlements, booking chats, venue authorizations, audit log, codes and fee preview.

Tasks added to this checkpoint:

- T-100 Admin page: fee preview calculator (sample orders per market) (admin, 0.5 day)
- T-175 Admin page: partner approvals queue (admin, 0.5 day)
- T-176 Admin page: role permissions (per page and sensitive actions) and platform staff (admin, 0.5 day)
- T-177 Admin page: club team accounts and suspension (admin, 0.5 day)
- T-178 Admin page: settlements, transfers, retries and statements (admin, 0.5 day)
- T-179 Admin page: refund oversight, partner debits, waiver and Charge to club (admin, 0.5 day)
- T-180 Admin page: booking chat review and intervention (admin, 0.5 day)
- T-181 Admin page: venue authorization review and disputes (admin, 0.5 day)
- T-182 Admin: destination areas and activation in the Cities page (admin, 0.5 day)
- T-183 Admin page: audit log for sensitive actions (admin, 0.5 day)
- T-184 Admin and owner screens for access and discount codes (admin, 0.5 day)

Removed from this checkpoint (superseded): T-078.

Additional review items:

- [ ] Every new page hides actions the role cannot use and shows the server 403 message.
- [ ] The audit log page needs a backend endpoint that was not yet specified (`GET /v2/admin/audit-log`): confirm it exists before releasing.

Additional smoke checks (staging, then the read-only subset on production):

- [ ] Sign in as Platform Manager: no waive, Charge to club, role editing or payout actions are visible (T-179).
- [ ] Sign in as Country Manager (Italy): French clubs and chats are not listed (T-177, T-180).

Rollback additions: admin is a static client: re-deploy the previous build; no data change.

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
