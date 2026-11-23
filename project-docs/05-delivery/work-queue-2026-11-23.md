# Work queue (2026-11-23): work that does not wait for client answers

Rule: one task at a time. Each task is implemented, tested, documented and committed on the branch `dev/backend-queue` before the next one starts. A task is "done" only when its tests pass. Status words: `queued`, `in progress`, `done in code (tested locally)`, `blocked`. Nothing is pushed, merged into `main`, tagged or deployed from this queue.

Branch: `dev/backend-queue` (local integration base: `feat/t-004-tier-update` plus `feat/t-002-migration-rehearsal` and `feat/t-009-social-dob`). It is a working branch so later tasks can use earlier ones. It is not a release branch; the release shape is still your decision.

Per task: failing test first, minimal change, `npm test`, `npm run test:db`, `tsc`, the migration rehearsal script for any migration, contract docs in the same commits, task status updated, then the next task.

## Queue

| # | Task | What it fixes | Depends on | Status |
|---|---|---|---|---|
| W-01 | Hotfix release readiness note | Where the hotfix release stands and what blocks it | none | done (docs): `release-hotfix-readiness-2026-11-23.md` |
| 1 | T-005 Migration: tier on purchase | Purchases record which ticket type was bought | T-002, T-003 | done in code (tested locally) |
| 2 | T-006 Store the tier on each purchase | Fills it at checkout | T-005 | done in code (tested locally) |
| 3 | T-007 Release sold count when a payment fails or is cancelled | Stops the "sold" number growing for unpaid checkouts | T-006 | done in code (tested locally) |
| 4 | T-008 Release sold count when an unpaid order expires | Same for abandoned checkouts (15 min, confirmed by client) | T-007 | done in code (tested locally) |
| 5 | T-010 Admin status codes | Clear 401/404/422 instead of 500 | T-003 | done in code (tested locally) |
| 6 | T-011 Ticket scan errors return real status codes | Door scanner gets clear errors | T-003 | done in code (tested locally) |
| 7 | T-012 Map not-found and link errors for clubs and events | 404 instead of 500 | T-003 | done in code (tested locally) |
| 8 | T-013 Event module delete 409 and wishlist 404 | Clear errors | T-012 | done in code (tested locally) |
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
| T-006 | `95a89d1`, `d2700d8`, docs commit | npm test 27/27; test:db 37/37 (10 new: 6 purchase/tier, 4 reconcile guard); tsc clean; no migration so rehearsal not run | `POST /purchase/event` and `GET /bookings/{id}` carry `ticketTierId`/`ticketTierName`. `reconcileEventTicketTiers` now deletes a missing tier only if soldCount = 0 and no purchase references it (trigger left unchanged). Lint and build not run. |
| T-007 | `be6b064`, `dd7ea3d`, `be180b6`, docs commit | npm test 27/27; test:db 48/48 (11 new); tsc clean; no migration so rehearsal not run | Failed or canceled payment releases `soldCount` once for tier-linked orders (guard: conditional PENDING_PAYMENT to PAYMENT_FAILED update, floor 0). Late succeeded after release re-takes stock or is logged MANUAL_REVIEW when the tier is full (no auto refund). `test:db` now `--test-concurrency=1`. Lint and build not run. |
| T-008 | `adf5a5b`, `0cd843d`, docs commit | server npm test 27/27; test:db 49/49 (1 new); worker tests 7/7 (new test script); tsc clean in server and worker; no migration so rehearsal not run | New worker job `expire-event-ticket-hold` (15 min, `EVENT_TICKET_HOLD_MS`) enqueued after `POST /purchase/event` commits. No scheduler sweep (lost delayed job leaks stock; stock-leak.sql detects). Worker boot against real Redis not run. Lint and build not run. |
| T-010 | `afc60ca`, `d558217`, docs commit | server npm test 27/27; test:db 81/81 (32 new); tsc clean; no migration so rehearsal not run | Refresh service throws `statusCode: 401` (was 500), suspend unknown id 404, `GET /admin/users` and `/admin/earnings` page/limit positive integers with limit at most 100 else 422. Admin app unchanged and unaffected. Lint, build and staging check not run. Open: huge page value can still 500 in the DB (no cap invented). |

| T-011 | `3d09d0b`, `15c947b`, `7d8db57`, docs commit | server npm test 27/27; test:db 88/88 (7 new); tsc clean; no migration so rehearsal not run | verify-ticket: unknown or another seller's order 404 TICKET_NOT_FOUND (same body), not PAID or refunded 422 TICKET_NOT_VALID, already used 409 TICKET_ALREADY_USED with usedAt; messages unchanged, never 401/403. Door scanner now shows the server message instead of a generic 500 text. Lint, build and staging check not run. Open: any refund still blocks entry until T-064; an order with no purchase row still 500s. |
| T-012 | `f4980ad`, `54bee9b`, docs commit | server npm test 33/33; test:db 98/98 (10 new); tsc clean; no migration so rehearsal not run | New `mapPrismaError` (P2025 404 NOT_FOUND, P2003 409 FOREIGN_KEY_CONFLICT, rest unchanged, fixed messages). `GET/PUT /club/:id` and `GET/PUT /event/:id`: missing or foreign id is 404 NOT_FOUND with one body (was 500; PUT event foreign id was 403). No client depends on the old statuses (Flutter maps 4xx to a message; admin app does not call these routes). Lint, build and staging check not run. Open: P2003 in updates maps to 409 (source ambiguous); Connect readiness 403 on these routes untouched; api-spec.yaml already fails strict YAML parse at line 3144. |
| T-013 | `ed358c5`, `16e07eb`, docs commit | server npm test 35/35; test:db 104/104 (6 new); worker 7/7; tsc clean; no migration so rehearsal not run | `DELETE /event/:eventId/modules/:id` with purchases returns 409 FOREIGN_KEY_CONFLICT (was 500, module kept); `POST /wishlist` missing target returns 404 NOT_FOUND (was 500, wrong `status` key). No client depends on the old 500. Wrong-key grep found one more (`POST /club` 422, logged as B-34, not fixed). Lint, build and staging check not run. |