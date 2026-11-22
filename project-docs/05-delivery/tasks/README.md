# Task files

One file per task, written 2026-11-21 (rebuilt after the repo was re-created; contract docs restored from commit `2e80ee3`). Docs only: nothing here has been implemented. Backend first, then admin; **Flutter (M8) is not started and has no task files** (the Flutter path is `flutter_app/`).

## Rules for every task

- At most half a day. If a task grows past that, stop and split it; the exception is T-022 (migration 6 plus the v1 write-through), which must stay one task (see its notes).
- Docs first: update `api-spec.yaml` and `data-model.md` before or with the code (`backend/CLAUDE.md`). v1 changes are additive; breaking changes go to `/api/v2` (ADR-001).
- Each migration task writes its own migration from `data-model.md` section 9 and must pass the rehearsal script from T-002 on the restored dump before merge. Migrations are forward-only; never edit a merged migration; never `migrate reset`.
- Tests are part of the task (harness from T-003; hotfixes may use plain `tsx --test`). A task is Done only when every box in its 'Done when' list is checked.
- Status values: `not started`, `in progress`, `blocked: <reason>`, `done`. Update the Status line in the task file and the table below.
- Hotfix track branches from `main` and ships before M1 (REL-HF). All other tasks branch from the v2 work branch.
- Release checkpoints (REL-*) have five sections: review, staging deploy, smoke list, production deploy, rollback note. Staging deploy mechanics are ⚠️ UNVERIFIED (the old workflows deploy tag-to-production only, and no workflow runs in the monorepo until root workflows are added); REL-HF settles that first.

## Order

Hotfix track, then M1 (restore and rehearsal first, then test harness, then the tier fixes, then status codes), M2, M3, M4, M5, M6, M7. Dependencies are listed per task; every dependency appears earlier in this list.

## Hotfix track (branch from `main`, ship before M1)

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [HF-001](HF-001.md) | Verify S-17 password hash fix (verify tests run + staging check) | backend | none | not started (verify only) |
| [HF-002](HF-002.md) | Stripe webhooks return 400 on missing or bad signature | backend | none | done in code (staging check pending) |
| [HF-003](HF-003.md) | Fix blacklist key mismatch (jwt vs token) in socket and OTP-page token checks | backend | none | done in code (staging check pending) |
| [HF-004](HF-004.md) | Reset password without OTP (verify first, then fix) | backend | none | done in code (staging check pending) |
| [HF-005](HF-005.md) | Require auth on POST and DELETE /media (S-01, Critical) | backend | none | done in code (staging check pending) |
| [FL-B07](FL-B07.md) | Flutter: handle 401 (clear session, redirect once, 403 is not logout) | flutter | none | investigated, blocked on Flutter SDK |
| [FL-B08](FL-B08.md) | Flutter: single-flight token refresh with one retry (backend rotates refresh tokens) | flutter | FL-B07 | investigated, blocked on Flutter SDK |
| [FL-P01](FL-P01.md) | Flutter: DOB picker limited to adults, inline validation keeps form data | flutter | none | investigated, blocked on Flutter SDK |
| [REL-HF](REL-HF.md) | Release checkpoint: hotfix track | release | HF-001, HF-002, HF-003, HF-004, HF-005 | not started |

## M1 Security and correctness

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-001](T-001.md) | Restore the dump into a local database and run baseline queries | backend (database) | none | done |
| [T-002](T-002.md) | Single-command migration rehearsal script | backend (database, scripts) | T-001 | not started |
| [T-003](T-003.md) | Backend test harness (unit and database-backed tests) | backend | T-001 | not started |
| [T-004](T-004.md) | Update event ticket tiers in place (stable ids, soldCount preserved) | backend | T-003 | not started |
| [T-005](T-005.md) | Migration 5: tier on purchase (add_tier_on_purchase) | backend (database) | T-002, T-003 | not started |
| [T-006](T-006.md) | Store the chosen tier on each event purchase | backend | T-005 | not started |
| [T-007](T-007.md) | Release soldCount when a payment fails or is canceled | backend | T-006 | not started |
| [T-008](T-008.md) | Release soldCount when an unpaid order expires (new job) | backend (server, worker) | T-007 | not started |
| [T-009](T-009.md) | Social sign-in: date of birth and profileComplete, retry-safe | backend | T-003 | not started |
| [T-010](T-010.md) | Admin status codes: refresh 401, suspend 404, page/limit 422 | backend | T-003 | not started |
| [T-011](T-011.md) | verify-ticket business errors return real status codes | backend | T-003 | not started |
| [T-012](T-012.md) | Map Prisma not-found and FK errors for club and event routes | backend | T-003 | not started |
| [T-013](T-013.md) | Event module delete 409 and wishlist 404 | backend | T-012 | not started |
| [T-014](T-014.md) | Validate request bodies on DELETE routes | backend | T-003 | not started |
| [REL-M1](REL-M1.md) | Release checkpoint: M1 security and correctness | release | T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-011, T-012, T-013, T-014 | not started |

## M2 Ticket sections, presets, promo, guest list

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-015](T-015.md) | Migration 4: event timezone, pricing mode, tier type | backend (database) | T-002, T-003 | not started |
| [T-016](T-016.md) | Ticket tier presets endpoint and tierType on tiers | backend | T-015, T-004 | not started |
| [T-017](T-017.md) | Event create and update: timezone, pricingMode, optional descriptions | backend | T-015, T-004 | not started |
| [T-018](T-018.md) | Promo management: role and ownership checks, 404 for unknown target | backend | T-003, T-012 | not started |
| [T-019](T-019.md) | Rate limit POST /promo/validate | backend | T-003 | not started |
| [T-020](T-020.md) | Block duplicate guest-list join | backend | T-003 | not started |
| [T-021](T-021.md) | Auth cleanup: check order on login, recover and token routes | backend | T-003, HF-004 | not started |
| [REL-M2](REL-M2.md) | Release checkpoint: M2 ticket sections, presets, promo, guest list | release | T-015, T-016, T-017, T-018, T-019, T-020, T-021 | not started |

## M3 Fees and commissions

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-022](T-022.md) | Migration 6: pricing rules, relaxed Order CHECKs, and v1 write-through | backend (database, admin module) | T-002, T-003 | not started |
| [T-023](T-023.md) | Pricing rule resolver (precedence and effective dates) | backend | T-022 | not started |
| [T-024](T-024.md) | Apply pricing rules at event ticket checkout | backend | T-023, T-006 | not started |
| [T-025](T-025.md) | Apply pricing rules at table and club-booking checkout | backend | T-024 | not started |
| [T-026](T-026.md) | Free ticket checkout (price 0, instant confirm) | backend | T-024 | not started |
| [T-027](T-027.md) | v2 admin pricing-rules endpoints and v1 deprecation headers | backend | T-023 | not started |
| [T-028](T-028.md) | v2 financials report endpoint | backend | T-024, T-025 | not started |
| [REL-M3](REL-M3.md) | Release checkpoint: M3 fees and commissions | release | T-022, T-023, T-024, T-025, T-026, T-027, T-028 | not started |

## M4 Discovery backend

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-029](T-029.md) | Migration 3: backfill geog on events and clubs | backend (database) | T-002 | not started |
| [T-030](T-030.md) | Keep geog in sync on event and club create, update and duplicate | backend | T-029, T-003 | not started |
| [T-031](T-031.md) | Migration 10: cities and filter options (with backfill from existing values) | backend (database) | T-002, T-003 | not started |
| [T-032](T-032.md) | Seed starter genre/mood lists and city list (needs client content) | backend (scripts) | T-031 | not started (client lists received) |
| [T-033](T-033.md) | Cities: GET /cities and admin cities endpoints | backend | T-031 | not started |
| [T-034](T-034.md) | Explore: radiusKm, cityId and distanceKm | backend | T-030, T-033 | not started |
| [T-035](T-035.md) | Explore: day grouping, date range, this_week, result total | backend | T-034, T-017 | not started |
| [T-036](T-036.md) | Explore feed honours city, cityId and radius | backend | T-034 | not started |
| [T-037](T-037.md) | Filter vocabulary: GET /explore/filters and admin filter-options | backend | T-031 | not started |
| [T-038](T-038.md) | GET /explore/map with the same filters as /explore | backend | T-034, T-037 | not started |
| [T-039](T-039.md) | Migration 11: interested, recent views and daily view counts | backend (database) | T-002, T-003 | not started |
| [T-040](T-040.md) | Interested: POST/DELETE /events/{id}/interested and interestedCount | backend | T-039 | not started |
| [T-041](T-041.md) | View tracking: Redis counters, flush job, recent views, viewCount dedupe | backend (server, scheduler) | T-039 | not started |
| [T-042](T-042.md) | Recently viewed, most viewed and sort=trending | backend | T-040, T-041, T-034 | not started |
| [T-043](T-043.md) | Migration 12: artist bio and social links | backend (database) | T-002 | not started |
| [T-044](T-044.md) | Artists: list, profile, owner edit, admin endpoints, lineup artistId | backend | T-043, T-017 | not started |
| [T-045](T-045.md) | Public event page fields on GET /explore/{id} | backend | T-040, T-041, T-017 | not started |
| [T-046](T-046.md) | Customer tickets: bucket filter and bookingStatus | backend | T-003 | not started |
| [REL-M4](REL-M4.md) | Release checkpoint: M4 discovery backend | release | T-029, T-030, T-031, T-032, T-033, T-034, T-035, T-036, T-037, T-038, T-039, T-040, T-041, T-042, T-043, T-044, T-045, T-046 | not started |

## M5 Organizer, tables, quotes, extras

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-047](T-047.md) | Migration 2: notification types | backend (database) | T-002 | not started |
| [T-048](T-048.md) | Migration 9: organizers and collaboration requests | backend (database) | T-047, T-002, T-003 | not started |
| [T-049](T-049.md) | Organizer profile: create, update, public view | backend | T-048 | not started |
| [T-050](T-050.md) | Organizer follow and unfollow | backend | T-049 | not started |
| [T-051](T-051.md) | Collaboration requests: create, list, respond, notify | backend | T-048, T-047, T-049 | not started |
| [T-052](T-052.md) | Event organizerId and organizer identity on the event page | backend | T-049, T-045, T-017 | not started |
| [T-053](T-053.md) | Admin organizers and collaboration requests endpoints | backend | T-049, T-051 | not started |
| [T-054](T-054.md) | Migration 8: extras, module pricing type, quote and host contact user links | backend (database) | T-002, T-003 | not started |
| [T-055](T-055.md) | Event extras: CRUD endpoints | backend | T-054 | not started |
| [T-056](T-056.md) | Table purchase: pricingType, QUOTE_REQUIRED and module idempotency body check | backend | T-054, T-025 | not started |
| [T-057](T-057.md) | Purchasable extras on module orders (with stock release and pricing rule) | backend | T-055, T-056 | not started |
| [T-058](T-058.md) | v2 authenticated quotes, and rate limits plus user link on v1 quotes and host contact | backend | T-054, T-019, T-027 | not started |
| [REL-M5](REL-M5.md) | Release checkpoint: M5 organizers, tables, quotes, extras | release | T-047, T-048, T-049, T-050, T-051, T-052, T-053, T-054, T-055, T-056, T-057, T-058 | not started |

## M6 Analytics, refunds, admin orders

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-059](T-059.md) | Migration 13: analytics and admin-order indexes | backend (database) | T-001, T-002 | not started |
| [T-060](T-060.md) | Owner earnings: include tables, event-timezone day boundaries | backend | T-015, T-059 | not started |
| [T-061](T-061.md) | Owner analytics: GET /owner/analytics | backend | T-059, T-060, T-025 | not started |
| [T-062](T-062.md) | Owner per-event analytics: GET /owner/events/{eventId}/analytics | backend | T-061 | not started |
| [T-063](T-063.md) | Migration 7: refund requests | backend (database) | T-002, T-047 | on hold (client answers Q8, Q9) |
| [T-064](T-064.md) | Only a FULL refund invalidates entry (verify-ticket and owner dashboard) | backend | T-063, T-011 | on hold (client answers Q8, Q9) |
| [T-065](T-065.md) | Owner refund request: POST /owner/orders/{orderId}/refund-requests | backend | T-063, T-064, T-047 | on hold (client answers Q8, Q9) |
| [T-066](T-066.md) | Admin refund requests: list and approve or reject | backend | T-065 | on hold (client answers Q8, Q9) |
| [T-067](T-067.md) | Handle Stripe refund webhook events | backend | T-063, HF-002 | not started |
| [T-068](T-068.md) | Admin orders, order detail and refunds list | backend | T-059, T-063 | not started |
| [T-069](T-069.md) | Cross-account access test suite for owner, organizer and admin routes | backend | T-062, T-066, T-068, T-053, T-051 | not started |
| [REL-M6](REL-M6.md) | Release checkpoint: M6 analytics, refunds, admin orders | release | T-059, T-060, T-061, T-062, T-063, T-064, T-065, T-066, T-067, T-068, T-069 | not started |

## M7 Admin app

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-070](T-070.md) | Admin scaffolding: test setup, shared data-state components, routes, i18n | admin | REL-M6 | not started |
| [T-071](T-071.md) | Admin page: Cities | admin | T-070, T-033 | not started |
| [T-072](T-072.md) | Admin page: Genre and mood options | admin | T-070, T-037 | not started |
| [T-073](T-073.md) | Admin page: Artists | admin | T-070, T-044 | not started |
| [T-074](T-074.md) | Admin pages: Organizers and Collaboration requests | admin | T-070, T-053 | not started |
| [T-075](T-075.md) | Admin page: Pricing rules | admin | T-070, T-027 | not started |
| [T-076](T-076.md) | Admin page: Financials | admin | T-070, T-028 | not started |
| [T-077](T-077.md) | Admin pages: Orders list and detail | admin | T-070, T-068 | not started |
| [T-078](T-078.md) | Admin page: Refund requests (approve or reject) | admin | T-070, T-066 | on hold (client answers Q8, Q9) |
| [T-079](T-079.md) | Admin page: Refunds list | admin | T-070, T-068 | not started |
| [REL-M7](REL-M7.md) | Release checkpoint: M7 admin app | release | T-070, T-071, T-072, T-073, T-074, T-075, T-076, T-077, T-078, T-079 | not started |

Totals: 83 work tasks (4 hotfix, 69 backend and database, 10 admin) and 8 release checkpoints.
