# REL-M5: Release checkpoint, M5 Organizer, tables, quotes, extras

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-047, T-048, T-049, T-050, T-051, T-052, T-053, T-054, T-055, T-056, T-057, T-058, T-090, T-091, T-092, T-112, T-113, T-114, T-115, T-116, T-117, T-118, T-119, T-120, T-121, T-122 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-047 to T-058. Migrations 2, 9, 8 (apply in that order). Suggested bump: MINOR.

## Update 2026-11-24 (client answers 2)

Phase 2. M5 now includes the full table payment flow (ADR-005): quotes with expiry and withdrawal, card hold with manual capture, fresh payment fallback and deposit modes. The Stripe spikes come first and need the client's Stripe test keys (not confirmed received). T-056 `QUOTE_REQUIRED` stays until the hold flow ships.

Tasks added to this checkpoint:

- T-090 Stripe test-mode spike 1: manual-capture hold, capture, cancel, expiry, unsupported methods (backend, 0.5 day; blocked: Stripe test keys (item 01))
- T-091 Stripe spike 2: separate charges and transfers, reversals, available-balance limits, failed transfers (backend, 0.5 day; blocked: Stripe test keys with Connect (item 01))
- T-092 Stripe payout eligibility report for Italy, France, Monaco, Spain and the US (backend, 0.25 day; blocked: Stripe account access (item 01))
- T-112 Migration: table requests, quotes (expiry, withdrawn), payment plan, policy snapshot (backend, 0.5 day)
- T-113 Quote lifecycle: issue, configurable expiry capped by the booking deadline, withdraw, notify (backend, 0.5 day)
- T-114 Atomic table reservation on acceptance and no simultaneous sale of one table (backend, 0.5 day)
- T-115 Table request with card authorization: request, pending, reject releases the hold (backend, 0.5 day; blocked: Stripe (spike))
- T-116 Accept, capture before capture_before, capture failure releases the table (backend, 0.5 day; blocked: Stripe (spike))
- T-117 Fresh payment after acceptance when a hold is unsupported or expired (backend, 0.5 day)
- T-118 Deposit modes: deposit online plus balance at venue, full online, two online payments (backend, 0.5 day)
- T-119 Second online payment: balance confirmation, deadline, fee only on the amount paid in app (backend, 0.5 day; blocked: second-payment deadline (Q5))
- T-120 Deposit and cancellation policy per table, terms accepted by the guest saved with the booking (backend, 0.5 day)
- T-121 Party size and admitted attendees recorded on a table booking, counted once in capacity (backend, 0.5 day)
- T-122 Commission shortfall when the online payment is smaller than the commission: partner receivable record (backend, 0.5 day)

Additional review items:

- [ ] The spikes prove manual capture and Connect transfers on the client's own account; report exactly what is missing if not (checklist item 01).
- [ ] A rejected request charges the customer zero including the Technical Fee (client Q3).
- [ ] `feature switch` for table payments is off in production until the Flutter screens (REL-M8) are released.

Additional smoke checks (staging, then the read-only subset on production):

- [ ] Table request, reject: the authorization is cancelled and no charge exists; accept: capture happens before `capture_before` (T-115, T-116).
- [ ] Two customers try the same table: only one succeeds (T-114).
- [ ] Deposit EUR 500 on a EUR 1,000 table: EUR 525.50 online and EUR 500 at the venue shown; full payment EUR 1,050.50 (T-118).

Rollback additions: old table purchase and v1 quotes keep working; new tables and the v2 endpoints are unused by old code. A captured payment is never rolled back by an image rollback: refund through the refund engine.

## 1. Review

- [ ] Migration 2 adds enum values and cannot be undone: confirm the four names with the product owner before applying.
- [ ] Q1, Q3, Q4 and Q6f were answered by the client on 2026-11-22 as directions, but this release still ships no quote-to-payment, no payout split and no unregistered venues (they need the Stripe spike and new tasks). Say so in the release note.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migrations 2, 9, 8.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Create an organizer profile, follow it, view it as an anonymous user (T-049, T-050).
- [ ] Create a collaboration request to a club; accept it as the club owner; both notifications arrive (T-051).
- [ ] Create an event with `organizerId`; the event page shows the organizer (T-052).
- [ ] Create an extra, buy a table with the extra in Stripe test mode, let one order expire: extras stock is released (T-055 to T-057).
- [ ] `POST /purchase/module` on a STARTING_FROM module: 409 `QUOTE_REQUIRED` (T-056).
- [ ] `POST /v2/quotes` without a token: 401; with a token: stored with `userId`; v1 `POST /quotes` still works and is rate limited (T-058).
- [ ] Admin lists organizers and collaboration requests (T-053).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Previous image works (new tables and columns unused by old code). The four new `NotificationType` values stay (cannot be dropped); old code ignores notifications of those types only if its rendering does not break on unknown values: T-047 checks that, so verify on staging with the old image before relying on this. Rolling back hides organizer data and extras from the app but deletes nothing.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
