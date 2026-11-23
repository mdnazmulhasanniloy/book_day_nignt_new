# Work queue (2026-11-23): work that does not wait for client answers

Rule: one task at a time. Each task is implemented, tested, documented and committed on the branch `dev/backend-queue` before the next one starts. A task is "done" only when its tests pass. Status words: `queued`, `in progress`, `done in code (tested locally)`, `blocked`. Nothing is pushed, merged into `main`, tagged or deployed from this queue.

Branch: `dev/backend-queue` (local integration base: `feat/t-004-tier-update` plus `feat/t-002-migration-rehearsal` and `feat/t-009-social-dob`). It is a working branch so later tasks can use earlier ones. It is not a release branch; the release shape is still your decision.

Per task: failing test first, minimal change, `npm test`, `npm run test:db`, `tsc`, the migration rehearsal script for any migration, contract docs in the same commits, task status updated, then the next task.

## Queue

| # | Task | What it fixes | Depends on | Status |
|---|---|---|---|---|
| W-01 | Hotfix release readiness note | Where the hotfix release stands and what blocks it | none | done (docs): `release-hotfix-readiness-2026-11-23.md` |
| 1 | T-005 Migration: tier on purchase | Purchases record which ticket type was bought | T-002, T-003 | done in code (tested locally) |
| 2 | T-006 Store the tier on each purchase | Fills it at checkout | T-005 | queued |
| 3 | T-007 Release sold count when a payment fails or is cancelled | Stops the "sold" number growing for unpaid checkouts | T-006 | queued |
| 4 | T-008 Release sold count when an unpaid order expires | Same for abandoned checkouts (15 min, confirmed by client) | T-007 | queued |
| 5 | T-010 Admin status codes | Clear 401/404/422 instead of 500 | T-003 | queued |
| 6 | T-011 Ticket scan errors return real status codes | Door scanner gets clear errors | T-003 | queued |
| 7 | T-012 Map not-found and link errors for clubs and events | 404 instead of 500 | T-003 | queued |
| 8 | T-013 Event module delete 409 and wishlist 404 | Clear errors | T-012 | queued |
| 9 | T-014 Validate bodies on DELETE routes | Bad requests rejected cleanly | T-003 | queued |
| 10 | T-015 Migration: event time zone, pricing mode, ticket type | Foundation for sections and presets | T-002, T-003 | queued |
| 11 | T-016 Ticket type presets | Preset names and Custom | T-015, T-004 | queued |
| 12 | T-017 Event create/update: time zone, pricing mode, optional descriptions | Event form fields | T-015, T-004 | queued |
| 13 | T-018 Promo management checks | Only owners manage their promos | T-003, T-012 | queued |
| 14 | T-019 Rate limit on promo validate | Stops code guessing | T-003 | queued |
| 15 | T-020 Block duplicate guest-list join | One request per guest | T-003 | queued |
| 16 | T-021 Auth cleanup: check order | Cleaner login and recovery errors | T-003, HF-004 | queued |
| 17 | T-029 Migration: location backfill | Radius search foundation | T-002 | queued (discovery) |
| 18 | T-030 to T-038 | Cities, 30 km radius, filters, map | T-029 onward | queued (discovery) |
| 19 | T-039 to T-046 | Interested, views, trending, artists, event page, customer tickets | T-039 onward | queued (discovery) |

Discovery tasks start after item 16. The genre, mood and city lists they need were received from the client on 2026-11-22; the radius is 30 km initially.

## Not started: needs your input or an environment

| Item | Why it waits |
|---|---|
| Stripe card-hold and split-payment prototype | Needs a Stripe test-mode key that you provide; the client's own account comes later |
| ADR drafts (pricing amendment, team permissions, refund engine) | Docs only; can start any time you say, marked "draft, awaiting client" |
| Tracker with status, date and evidence per ID | Docs only; can start any time you say |
| Staging stage and root-level CI workflows | Environment decision (see `release-hotfix-readiness-2026-11-23.md`) |
| Everything marked pending in `client-clarifications-2026-11-22.md` | Waiting for the client |

## Progress log

Each finished task is added here with its commit hashes and test results.

| Task | Commits | Tests | Notes |
|---|---|---|---|
| T-005 | `dd40300`, `c3b5be2`, docs commit | npm test 27/27; test:db 27/27 (4 new); tsc clean; rehearsal RESULT: PASS | Migration `20261123120000_add_tier_on_purchase`. Tier delete on a referenced tier is refused by the trigger (open decision, data-model 8.6 item 8). Old-image check not run. |
