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
| [HF-001](HF-001.md) | Verify S-17 password hash fix (verify tests run + staging check) | backend | none | not started (verify first) |
| [HF-002](HF-002.md) | Stripe webhooks return 400 on missing or bad signature | backend | none | done in code (staging check pending) (verified by file comparison only; tests to be re-run in REL-HF) |
| [HF-003](HF-003.md) | Fix blacklist key mismatch (jwt vs token) in socket and OTP-page token checks | backend | none | done in code (staging check pending) (verified by file comparison only; tests to be re-run in REL-HF) |
| [HF-004](HF-004.md) | Reset password without OTP (verify first, then fix) | backend | none | done in code (verified from code reading; staging check pending) (verified by file comparison only; tests to be re-run in REL-HF) |
| [HF-005](HF-005.md) | Require auth on POST and DELETE /media (S-01, Critical) | backend | none | done in code (staging check pending); NOT in main: the code exists only on the unpushed local branch `fix/merge-hotfix` (merge commit c31c358) |
| [FL-B07](FL-B07.md) | Flutter: handle 401 (clear session, redirect once, 403 is not logout) | flutter | none (design shares one client change with FL-B08; implement together or B-08 first) | investigated, not implemented (no Flutter SDK on the dev machine; cannot run `flutter analyze` or `flutter test`) |
| [FL-B08](FL-B08.md) | Flutter: single-flight token refresh with one retry (backend rotates refresh tokens) | flutter | FL-B07 (same interceptor and logout path) | investigated, not implemented (no Flutter SDK on the dev machine) |
| [FL-P01](FL-P01.md) | Flutter: DOB picker limited to adults, inline validation keeps form data | flutter | none for the picker fix; collecting a missing DOB for social sign-in depends on backend T-009 (not in this task) | investigated, not implemented (no Flutter SDK; the original defect is UNVERIFIED) |
| [REL-HF](REL-HF.md) | Release checkpoint: hotfix track | release | HF-001, HF-002, HF-003, HF-004, HF-005 | merge branch approved; release checkpoint items not run |

## M1 Security and correctness

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-001](T-001.md) | Restore the dump into a local database and run baseline queries | backend (database) | none | done (local restore; no code change) (verified by file comparison only; tests to be re-run in REL-HF) |
| [T-002](T-002.md) | Single-command migration rehearsal script | backend (database, scripts) | T-001 | done (rehearsal verified locally; CI not applicable) (verified by file comparison only; tests to be re-run in REL-HF) |
| [T-003](T-003.md) | Backend test harness (unit and database-backed tests) | backend | T-001 | done (CI job added on ci/backend-tests; first real GitHub run pending) (verified by file comparison only; tests to be re-run in REL-HF) |
| [T-004](T-004.md) | Update event ticket tiers in place (stable ids, soldCount preserved) | backend | T-003 | done in code (tested locally; in main via the dev/backend-queue merge, commits 90dba93 and f88337d; source: git ancestry and `event.tierUpdate.db.test.ts`, work-queue base) |
| [T-005](T-005.md) | Migration 5: tier on purchase (add_tier_on_purchase) | backend (database) | T-002, T-003 | done in code (tested locally) |
| [T-006](T-006.md) | Store the chosen tier on each event purchase | backend | T-005 | done in code (tested locally) |
| [T-007](T-007.md) | Release soldCount when a payment fails or is canceled | backend | T-006 | done in code (tested locally) |
| [T-008](T-008.md) | Release soldCount when an unpaid order expires (new job) | backend (server, worker) | T-007 | done in code (tested locally) |
| [T-009](T-009.md) | Social sign-in: date of birth and profileComplete, retry-safe | backend | T-003 | done in code (tested locally; in main via the dev/backend-queue merge, commit 3a85804; source: git ancestry and `auth.social.db.test.ts`, `profileComplete` in `auth.services.ts`) |
| [T-010](T-010.md) | Admin status codes: refresh 401, suspend 404, page/limit 422 | backend | T-003 | done in code (tested locally) |
| [T-011](T-011.md) | verify-ticket business errors return real status codes | backend | T-003 | done in code (tested locally) |
| [T-012](T-012.md) | Map Prisma not-found and FK errors for club and event routes | backend | T-003 | done in code (tested locally) |
| [T-013](T-013.md) | Event module delete 409 and wishlist 404 | backend | T-012 | done in code (tested locally) |
| [T-014](T-014.md) | Validate request bodies on DELETE routes | backend | T-003 | done in code (tested locally) |
| [REL-M1](REL-M1.md) | Release checkpoint: M1 security and correctness | release | T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-011, T-012, T-013, T-014, T-085, T-086 | not started |

## M2 Ticket sections, presets, promo, guest list

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-015](T-015.md) | Migration 4: event timezone, pricing mode, tier type | backend (database) | T-002, T-003 | done in code (tested locally) |
| [T-016](T-016.md) | Ticket tier presets endpoint and tierType on tiers | backend | T-015, T-004 | done in code (tested locally) |
| [T-017](T-017.md) | Event create and update: timezone, pricingMode, optional descriptions | backend | T-015, T-004 | done in code (tested locally) |
| [T-018](T-018.md) | Promo management: role and ownership checks, 404 for unknown target | backend | T-003, T-012 | done in code (tested locally) |
| [T-019](T-019.md) | Rate limit POST /promo/validate | backend | T-003 | done in code (tested locally) |
| [T-020](T-020.md) | Block duplicate guest-list join | backend | T-003 | done in code (tested locally) |
| [T-021](T-021.md) | Auth cleanup: check order on login, recover and token routes | backend | T-003, HF-004 | done in code (tested locally) |
| [REL-M2](REL-M2.md) | Release checkpoint: M2 ticket sections, presets, promo, guest list | release | T-015, T-016, T-017, T-018, T-019, T-020, T-021, T-084, T-087 | all tasks done in code; release checkpoint items not run |

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
| [REL-M3](REL-M3.md) | Release checkpoint: M3 fees and commissions | release | T-022, T-023, T-024, T-025, T-026, T-027, T-028, T-089, T-093, T-094, T-095, T-096, T-097, T-098, T-099 | not started (rebuilt for the client rates, 2026-11-24) |

## M4 Discovery backend

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-029](T-029.md) | Migration 3: backfill geog on events and clubs | backend (database) | T-002 | done in code (tested locally) |
| [T-030](T-030.md) | Keep geog in sync on event and club create, update and duplicate | backend | T-029, T-003 | done in code (tested locally) |
| [T-031](T-031.md) | Migration 10: cities and filter options (with backfill from existing values) | backend (database) | T-002, T-003 | done in code (tested locally) |
| [T-032](T-032.md) | Seed starter genre/mood lists and city list (needs client content) | backend (scripts) | T-031 | done in code (tested locally) |
| [T-033](T-033.md) | Cities: GET /cities and admin cities endpoints | backend | T-031 | done in code (tested locally) |
| [T-034](T-034.md) | Explore: radiusKm, cityId and distanceKm | backend | T-030, T-033 | done in code (tested locally) |
| [T-035](T-035.md) | Explore: day grouping, date range, this_week, result total | backend | T-034, T-017 | done in code (tested locally) |
| [T-036](T-036.md) | Explore feed honours city, cityId and radius | backend | T-034 | done in code (tested locally) |
| [T-037](T-037.md) | Filter vocabulary: GET /explore/filters and admin filter-options | backend | T-031 | done in code (tested locally) |
| [T-038](T-038.md) | GET /explore/map with the same filters as /explore | backend | T-034, T-037 | done in code (tested locally) |
| [T-039](T-039.md) | Migration 11: interested, recent views and daily view counts | backend (database) | T-002, T-003 | done in code (tested locally) |
| [T-040](T-040.md) | Interested: POST/DELETE /events/{id}/interested and interestedCount | backend | T-039 | done in code (tested locally, not deployed) |
| [T-041](T-041.md) | View tracking: Redis counters, flush job, recent views, viewCount dedupe | backend (server, worker, scheduler) | T-039 | done in code (tested locally, not deployed) |
| [T-042](T-042.md) | Recently viewed, most viewed and sort=trending | backend | T-040, T-041, T-034 | done in code (tested locally, not deployed) |
| [T-043](T-043.md) | Migration 12: artist bio and social links | backend (database) | T-002 | done in code (tested locally, not deployed) |
| [T-044](T-044.md) | Artists: list, profile, owner edit, admin endpoints, lineup artistId | backend | T-043, T-017 | done in code (tested locally, not deployed) |
| [T-045](T-045.md) | Public event page fields on GET /explore/{id} | backend | T-040, T-041, T-017 | done in code (tested locally, not deployed) |
| [T-046](T-046.md) | Customer tickets: bucket filter and bookingStatus | backend | T-003 | done in code (tested locally, not deployed) |
| [REL-M4](REL-M4.md) | Release checkpoint: M4 discovery backend | release | T-029, T-030, T-031, T-032, T-033, T-034, T-035, T-036, T-037, T-038, T-039, T-040, T-041, T-042, T-043, T-044, T-045, T-046 | not started. All M4 backend tasks T-029 to T-046 are done in code (tested locally, not deployed); release checkpoint items not run. No boxes ticked |

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
| [REL-M5](REL-M5.md) | Release checkpoint: M5 organizers, tables, quotes, extras | release | T-047, T-048, T-049, T-050, T-051, T-052, T-053, T-054, T-055, T-056, T-057, T-058, T-090, T-091, T-092, T-112, T-113, T-114, T-115, T-116, T-117, T-118, T-119, T-120, T-121, T-122 | not started |

## M6 Analytics, refunds, admin orders

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-059](T-059.md) | Migration 13: analytics and admin-order indexes | backend (database) | T-001, T-002 | not started |
| [T-060](T-060.md) | Owner earnings: include tables, event-timezone day boundaries | backend | T-015, T-059 | not started |
| [T-061](T-061.md) | Owner analytics: GET /owner/analytics | backend | T-059, T-060, T-025 | not started |
| [T-062](T-062.md) | Owner per-event analytics: GET /owner/events/{eventId}/analytics | backend | T-061 | not started |
| [T-063](T-063.md) | Migration 7: refund requests | backend (database) | T-002, T-047 | superseded by T-134 |
| [T-064](T-064.md) | Only a FULL refund invalidates entry (verify-ticket and owner dashboard) | backend | T-063, T-011 | superseded by T-136, T-149 |
| [T-065](T-065.md) | Owner refund request: POST /owner/orders/{orderId}/refund-requests | backend | T-063, T-064, T-047 | superseded by T-138, T-139, T-143 |
| [T-066](T-066.md) | Admin refund requests: list and approve or reject | backend | T-065 | superseded by T-139, T-142 |
| [T-067](T-067.md) | Handle Stripe refund webhook events | backend | T-134, HF-002 | not started |
| [T-068](T-068.md) | Admin orders, order detail and refunds list | backend | T-059, T-134 | not started |
| [T-069](T-069.md) | Cross-account access test suite for owner, organizer and admin routes | backend | T-062, T-139, T-068, T-053, T-051, T-102, T-104, T-105, T-106, T-107, T-108 | not started |
| [REL-M6](REL-M6.md) | Release checkpoint: M6 analytics, refunds, admin orders | release | T-059, T-060, T-061, T-062, T-067, T-068, T-069, T-134, T-135, T-136, T-137, T-138, T-139, T-140, T-141, T-142, T-143, T-144, T-145 | not started |

## M7 Admin app

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [T-070](T-070.md) | Admin scaffolding: test setup, shared data-state components, routes, i18n | admin | none (scaffolding has no backend dependency; the first pages need REL-M3) | not started |
| [T-071](T-071.md) | Admin page: Cities | admin | T-070, T-033 | not started |
| [T-072](T-072.md) | Admin page: Genre and mood options | admin | T-070, T-037 | not started |
| [T-073](T-073.md) | Admin page: Artists | admin | T-070, T-044 | not started |
| [T-074](T-074.md) | Admin pages: Organizers and Collaboration requests | admin | T-070, T-053, T-083 | not started |
| [T-075](T-075.md) | Admin page: Pricing rules | admin | T-070, T-027, T-093, T-097 | not started |
| [T-076](T-076.md) | Admin page: Financials | admin | T-070, T-028, T-095 | not started |
| [T-077](T-077.md) | Admin pages: Orders list and detail | admin | T-070, T-068, T-134 | not started |
| [T-078](T-078.md) | Admin page: Refund requests (approve or reject) | admin | T-070, T-066 | superseded by T-179 (Refunds oversight). The client answers of 2026-11-24 give refund decisions to the club and take admin approval out of the normal flow, so there are no admin refund requests to approve |
| [T-079](T-079.md) | Admin page: Refunds list | admin | T-070, T-068, T-134 | not started |
| [REL-M7](REL-M7.md) | Release checkpoint: M7 admin app | release | T-070, T-071, T-072, T-073, T-074, T-075, T-076, T-077, T-079, T-100, T-175, T-176, T-177, T-178, T-179, T-180, T-181, T-182, T-183, T-184 | not started |

## Follow-ups (not scheduled)

| ID | Title | Stack | Depends on | Status |
|---|---|---|---|---|
| [FU-001](FU-001.md) | Move the share page inline script to a file and add a Content-Security-Policy | backend | none | not started (follow-up, do not do before the owner schedules it) |
| [FU-002](FU-002.md) | Make lint run again (typescript-eslint and TypeScript 7) | backend | none | not started |

Totals: 83 work tasks (4 hotfix, 69 backend and database, 10 admin) and 8 release checkpoints.

## Added by the plan revision of 2026-11-24 (client answers 02)

Source: `05-delivery/completion-plan-2026-11-24.md` (work queue, dates, milestones). IDs T-080 and up are backend and admin, FL-101 and up are Flutter. Phase 1 = stable build, Phase 2 = launch scope, Phase 3 = soon after launch. T-063, T-064, T-065, T-066 and T-078 are superseded.

| Task | Title | Stack | Phase | Depends on | Status |
|---|---|---|---|---|---|
| [FL-101](FL-101.md) | Flutter: version policy check at launch and the update-required screen | flutter | 1 | T-089 | not started |
| [FL-102](FL-102.md) | Flutter: signup change and pending-approval screen driven by partnerStatus and 423 | flutter | 1 | T-082 | not started |
| [FL-103](FL-103.md) | Flutter: city selector, radius 10-50 km (30 default), cityId on explore | flutter | 1 | T-034 | not started |
| [FL-104](FL-104.md) | Flutter: day grouping, date range, filters from /explore/filters, result total | flutter | 1 | T-035, T-037 | not started |
| [FL-105](FL-105.md) | Flutter: map view from /explore/map | flutter | 1 | T-038 | not started |
| [FL-106](FL-106.md) | Flutter: Interested button and count, recently viewed, most viewed, trending | flutter | 1 | T-040, T-042 | not started |
| [FL-107](FL-107.md) | Flutter: event page fields (club, map link, interested count, timezone display) | flutter | 1 | T-045 | not started |
| [FL-108](FL-108.md) | Flutter: artist list, profile, follow | flutter | 1 | T-044 | not started |
| [FL-109](FL-109.md) | Flutter: My tickets buckets (future, pending, past) and booking status | flutter | 1 | T-046 | not started |
| [FL-110](FL-110.md) | Flutter: send tier ids on event update, handle new error status codes (404/409/422) | flutter | 1 | T-004 | not started |
| [FL-111](FL-111.md) | Flutter: checkout uses the server-calculated total and shows fee lines per display mode | flutter | 2 | T-097 | not started |
| [FL-112](FL-112.md) | Flutter: remove the client-side fee calculation, keep one price source for all products | flutter | 2 | FL-111 | not started |
| [FL-113](FL-113.md) | Flutter: French and Spanish complete across app flows, language inventory reconciled | flutter | 2 | T-088 | blocked by client: translations review |
| [FL-114](FL-114.md) | Flutter: remaining agreed languages already listed in the app (after launch languages) | flutter | 3 | FL-113 | not started |
| [FL-115](FL-115.md) | Flutter: table request screen, quote view with time left, withdrawn quote state | flutter | 2 | T-113 | not started |
| [FL-116](FL-116.md) | Flutter: card hold flow, pending status, release status, payment retry | flutter | 2 | T-116 | not started |
| [FL-117](FL-117.md) | Flutter: deposit options, balance and settlement terms, second payment | flutter | 2 | T-119 | not started |
| [FL-118](FL-118.md) | Flutter: table cancellation policy shown before payment, party size, attendance | flutter | 2 | T-120, T-121 | not started |
| [FL-119](FL-119.md) | Flutter: booking chat list and thread, read states | flutter | 2 | T-166 | not started |
| [FL-120](FL-120.md) | Flutter: protection message, WhatsApp support link, push handling | flutter | 2 | T-169, T-171 | not started |
| [FL-121](FL-121.md) | Flutter: role-aware navigation for staff and organizer permissions | flutter | 2 | T-110 | not started |
| [FL-122](FL-122.md) | Flutter: cancellation policy on checkout and cancel one ticket with refund preview | flutter | 2 | T-136 | not started |
| [FL-123](FL-123.md) | Flutter: refund status and event change notice with the refund route and deadline | flutter | 2 | T-144, T-137 | not started |
| [FL-124](FL-124.md) | Flutter: multi-day pass purchase and per-day availability | flutter | 2 | T-148, T-152 | not started |
| [FL-125](FL-125.md) | Flutter: per-day tickets and QR credential | flutter | 2 | T-148 | not started |
| [FL-126](FL-126.md) | Flutter: scanner uses the v2 scan endpoint, per-day and repeat results | flutter | 2 | T-149 | not started |
| [FL-127](FL-127.md) | Flutter: from-price, Last tickets badge and tier progression on event cards and page | flutter | 2 | T-153 | not started |
| [FL-128](FL-128.md) | Flutter: guest-list request, hold time, code entry | flutter | 2 | T-151, T-156 | not started |
| [FL-129](FL-129.md) | Flutter: purchase limit messages | flutter | 2 | T-087 | not started |
| [FL-130](FL-130.md) | Flutter owner screens: settlement states, expected transfer date, statements | flutter | 2 | T-132 | not started |
| [FL-131](FL-131.md) | Flutter: unregistered venue form and evidence upload, status, Presented-by label | flutter | 2 | T-158, T-161 | not started |
| [FL-132](FL-132.md) | Flutter: Cote d Azur area, empty-city text and no-result suggestions | flutter | 2 | T-163 | not started |
| [FL-133](FL-133.md) | Flutter: age rule on the event page and the 18+ warning before booking | flutter | 2 | T-174 | blocked by client: adviser confirmation (Q31) |
| [FL-134](FL-134.md) | Flutter owner: settlement proposal and organizer acceptance screens | flutter | 2 | T-124 | not started |
| [FL-135](FL-135.md) | Flutter owner: issue, edit and withdraw quotes; table policy settings | flutter | 2 | T-120, T-104 | not started |
| [FL-136](FL-136.md) | Flutter owner: code management screen (discount and guest-list codes) | flutter | 2 | T-156 | not started (code priority is open with the client: Q16 of the 2026-11-24 clarification list) |
| [REL-L](REL-L.md) | Release checkpoint, L Launch readiness | release | 2 | T-185, T-186, REL-HF, REL-M1, REL-M2, REL-M3, REL-M4, REL-M5, REL-M6, REL-M7, REL-M8, REL-M9, REL-M10, REL-M11, REL-M12, REL-M13, REL-M14, REL-MG | not started |
| [REL-M10](REL-M10.md) | Release checkpoint, M10 Settlement, payouts and ledger | release | 2 | T-123, T-124, T-125, T-126, T-127, T-128, T-129, T-130, T-131, T-132, T-133 | not started |
| [REL-M11](REL-M11.md) | Release checkpoint, M11 Multi-day passes, scanning, no-show | release | 2 | T-146, T-147, T-148, T-149, T-150, T-151, T-152, T-153, T-154, T-155, T-156 | not started |
| [REL-M12](REL-M12.md) | Release checkpoint, M12 Venue authorization, disputes and destination areas | release | 2 | T-157, T-158, T-159, T-160, T-161, T-162, T-163, T-164 | not started |
| [REL-M13](REL-M13.md) | Release checkpoint, M13 Booking chat | release | 2 | T-165, T-166, T-167, T-168, T-169, T-170, T-171 | not started |
| [REL-M14](REL-M14.md) | Release checkpoint, M14 Languages and age rules | release | 2 | T-088, T-172, T-173, T-174 | not started |
| [REL-M8](REL-M8.md) | Release checkpoint, M8 Flutter integration (M8a Phase 1, M8b Phase 2, M8c Phase 3) | release | 1-3 | FL-101, FL-102, FL-103, FL-104, FL-105, FL-106, FL-107, FL-108, FL-109, FL-110, FL-111, FL-112, FL-113, FL-114, FL-115, FL-116, FL-117, FL-118, FL-119, FL-120, FL-121, FL-122, FL-123, FL-124, FL-125, FL-126, FL-127, FL-128, FL-129, FL-130, FL-131, FL-132, FL-133, FL-134, FL-135, FL-B07, FL-B08, FL-P01 | not started |
| [REL-M9](REL-M9.md) | Release checkpoint, M9 Team roles and permissions | release | 2 | T-101, T-102, T-103, T-104, T-105, T-106, T-107, T-108, T-109, T-110, T-111 | not started |
| [REL-MG](REL-MG.md) | Release checkpoint, MG Partner approval gate (migration 1) | release | 1 | T-080, T-081, T-082, T-083 | not started |
| [T-080](T-080.md) | Migration: partner approval status, application table, backfill existing owners as approved | backend | 1 | T-002, T-003 | not started |
| [T-081](T-081.md) | Signup and social sign-in: new club owners and organizers start PENDING; partnerStatus added to auth responses | backend | 1 | T-080 | not started |
| [T-082](T-082.md) | Partner gate middleware: 423 PARTNER_APPROVAL_PENDING (never 401/403) with the club-area home allowed | backend | 1 | T-081 | not started |
| [T-083](T-083.md) | Admin endpoints: list, approve, reject partner applications, with notification | backend | 1 | T-082 | blocked by client: D12 (named approvers) |
| [T-084](T-084.md) | Time zone backfill for existing events from venue and city, with an ambiguous-records report | backend | 1 | T-017, T-033 | not started |
| [T-085](T-085.md) | Run the stalled-checkout list on live data (read-only) and produce the per-event report | backend | 1 | T-007 | blocked by client: hosting or database access (item 04) |
| [T-086](T-086.md) | Per-event correction script for sold counts, run only after written approval for each event | backend | 1 | T-085 | blocked by client: client written OK per event |
| [T-087](T-087.md) | Purchase limits: 5 per order, 10 per customer per event (configurable per event), repeat-cancellation flag | backend | 1 | T-006 | not started |
| [T-088](T-088.md) | Language inventory of the Flutter app and backend texts (emails, push, errors) for EN, IT, FR, ES | backend | 1 | none | not started |
| [T-089](T-089.md) | Version policy endpoint and minimum supported version setting | backend | 1 | T-003 | not started |
| [T-090](T-090.md) | Stripe test-mode spike 1: manual-capture hold, capture, cancel, expiry, unsupported methods | backend | 2 | none | not started (Stripe access received; the spike reports which Connect permissions are missing) |
| [T-091](T-091.md) | Stripe spike 2: separate charges and transfers, reversals, available-balance limits, failed transfers | backend | 2 | T-090 | not started (Stripe access received; needs Connect enabled, verified by this spike) |
| [T-092](T-092.md) | Stripe payout eligibility report for Italy, France, Monaco, Spain and the US | backend | 2 | T-091 | not started (Stripe access received; eligibility per country is what this task reports) |
| [T-093](T-093.md) | Fee rule: percent plus fixed part, fixed once per order, fixed amount per currency, country and quote scopes | backend | 2 | T-022 | not started |
| [T-094](T-094.md) | Fee allocation per item and rates saved on the order, for partial refunds | backend | 2 | T-093, T-024 | not started |
| [T-095](T-095.md) | Record the actual processor cost per payment and per issued ticket, separate from commission | backend | 2 | T-024 | not started |
| [T-096](T-096.md) | Server-calculated total: POST /v2/checkout/preview for tickets, tables, extras and baskets | backend | 2 | T-094 | not started |
| [T-097](T-097.md) | Display mode per market and category (itemized or included) in the preview response | backend | 2 | T-096 | blocked by client: inclusive-display markets (Q2) |
| [T-098](T-098.md) | Keep /service-charge and the old purchase response working for old app versions, with tests | backend | 2 | T-093 | not started |
| [T-099](T-099.md) | Minimum-version enforcement switch: fee model v2 active only when the gate is on | backend | 2 | T-089, T-098 | not started |
| [T-100](T-100.md) | Admin page: fee preview calculator (sample orders per market) | admin | 2 | T-096, T-075 | not started |
| [T-101](T-101.md) | Migration: club team members, platform staff, permission grants, audit rows (AccountRole untouched) | backend | 2 | T-080 | not started |
| [T-102](T-102.md) | Permission catalogue and resolver: page view/manage plus sensitive actions | backend | 2 | T-101 | blocked by client: default permission matrix (Q24) |
| [T-103](T-103.md) | Club team: invite, accept, suspend, remove (owner), suspend any (platform) | backend | 2 | T-102 | not started |
| [T-104](T-104.md) | Enforce club roles on events, bookings and check-in (assigned events only) | backend | 2 | T-103 | not started |
| [T-105](T-105.md) | Enforce club roles on revenue, refunds, payout destination and team changes | backend | 2 | T-104 | not started |
| [T-106](T-106.md) | Organizer permissions for quotes, chat and refunds: off by default, granted one by one, history kept | backend | 2 | T-102, T-049 | not started |
| [T-107](T-107.md) | Platform roles (Manager, Country Manager, Staff) and the country limit on admin endpoints | backend | 2 | T-102 | not started |
| [T-108](T-108.md) | Sensitive actions reserved to Admin: rates, payouts, Technical Fee refunds, club debits, admin management | backend | 2 | T-107 | not started |
| [T-109](T-109.md) | Admin endpoints for the editable role-permissions page | backend | 2 | T-108 | not started |
| [T-110](T-110.md) | Additive staff fields on login and check responses (teamRole, permissions) for the apps | backend | 2 | T-103 | not started |
| [T-111](T-111.md) | Labelled test accounts for the ten roles (seed script, test payments only) | backend | 2 | T-108, T-105 | not started |
| [T-112](T-112.md) | Migration: table requests, quotes (expiry, withdrawn), payment plan, policy snapshot | backend | 2 | T-054 | not started |
| [T-113](T-113.md) | Quote lifecycle: issue, configurable expiry capped by the booking deadline, withdraw, notify | backend | 2 | T-112, T-058 | not started |
| [T-114](T-114.md) | Atomic table reservation on acceptance and no simultaneous sale of one table | backend | 2 | T-113 | not started |
| [T-115](T-115.md) | Table request with card authorization: request, pending, reject releases the hold | backend | 2 | T-114, T-090 | not started (follows the Stripe spike T-090) |
| [T-116](T-116.md) | Accept, capture before capture_before, capture failure releases the table | backend | 2 | T-115 | not started (follows the Stripe spike T-090) |
| [T-117](T-117.md) | Fresh payment after acceptance when a hold is unsupported or expired | backend | 2 | T-116 | not started |
| [T-118](T-118.md) | Deposit modes: deposit online plus balance at venue, full online, two online payments | backend | 2 | T-117, T-094 | not started |
| [T-119](T-119.md) | Second online payment: balance confirmation, deadline, fee only on the amount paid in app | backend | 2 | T-118 | blocked by client: second-payment deadline (Q5) |
| [T-120](T-120.md) | Deposit and cancellation policy per table, terms accepted by the guest saved with the booking | backend | 2 | T-118 | not started |
| [T-121](T-121.md) | Party size and admitted attendees recorded on a table booking, counted once in capacity | backend | 2 | T-114 | not started |
| [T-122](T-122.md) | Commission shortfall when the online payment is smaller than the commission: partner receivable record | backend | 2 | T-118, T-126 | not started |
| [T-123](T-123.md) | Migration: settlement arrangement, ledger entries, transfers | backend | 2 | T-091, T-022 | not started |
| [T-124](T-124.md) | Settlement setup: admin share, owner proposal, organizer acceptance before sales open | backend | 2 | T-123, T-106 | not started |
| [T-125](T-125.md) | Fallback routing to the eligible club and flags for ineligible payees | backend | 2 | T-124 | not started |
| [T-126](T-126.md) | Ledger and share states: Pending, then Confirmed - scheduled for transfer with the expected date | backend | 2 | T-123, T-094 | not started |
| [T-127](T-127.md) | Scheduler job: initiate transfers 3 calendar days after event end | backend | 2 | T-126 | not started |
| [T-128](T-128.md) | Hold the amount affected by an open refund or dispute and release the rest | backend | 2 | T-127 | not started |
| [T-129](T-129.md) | Failed transfers: retry up to 3 times in 3 days, immediate notices, idempotency | backend | 2 | T-127 | not started |
| [T-130](T-130.md) | Transfer reversals after refunds (full and partial) and the unrecovered amount | backend | 2 | T-128, T-137 | not started |
| [T-131](T-131.md) | Connect webhook events for transfers and payouts into the ledger | backend | 2 | T-127 | not started |
| [T-132](T-132.md) | Partner statements and settlement reports (owner and admin) | backend | 2 | T-126 | not started |
| [T-133](T-133.md) | Demonstration pack: one partially refunded order and one insufficient partner balance | backend | 2 | T-130 | not started |
| [T-134](T-134.md) | Migration: per-ticket status, refunds one-to-many, refund items, goodwill amounts | backend | 2 | T-005 | not started |
| [T-135](T-135.md) | Cancellation policy per event (cutoff in hours or non-refundable), shown before purchase | backend | 2 | T-134 | not started |
| [T-136](T-136.md) | Customer cancels one ticket in time: invalidate that credential, keep the others | backend | 2 | T-135 | not started |
| [T-137](T-137.md) | Refund orchestration: admission refund, commission reversal, Technical Fee retained, pending until the processor confirms | backend | 2 | T-136, T-094 | not started |
| [T-138](T-138.md) | Club exception refunds and documented partial goodwill refunds with admission kept | backend | 2 | T-137, T-105 | blocked by client: Italy goodwill treatment (adviser) |
| [T-139](T-139.md) | Who may refund: owner, owner-permissioned organizer, staff forward requests, admin disputes | backend | 2 | T-138, T-106 | not started |
| [T-140](T-140.md) | Partner cancellation: admission refund, commission reversal, Technical Fee refund flag per market | backend | 2 | T-137 | blocked by client: Technical Fee rule on partner cancellation (adviser) |
| [T-141](T-141.md) | Partner debit and recovery: eligible balance, then future settlements, then invoice; never charged twice | backend | 2 | T-140, T-126 | not started |
| [T-142](T-142.md) | Admin waiver down to the unrecovered Stripe cost, and the admin-only Charge to club action, with audit | backend | 2 | T-141, T-108 | not started |
| [T-143](T-143.md) | Return eligible capacity on cancellation while sales are open; manual restock without double release | backend | 2 | T-136 | not started |
| [T-144](T-144.md) | Date or venue change: notices, 7-day refund window, immediate route for a last-minute change | backend | 2 | T-137, T-017 | blocked by client: last-minute threshold (Q11) |
| [T-145](T-145.md) | Refund and chargeback reconciliation against bank credits, no double reimbursement | backend | 2 | T-142, T-067 | not started |
| [T-146](T-146.md) | Migration: event days, pass day entitlements, entry scans | backend | 2 | T-015 | not started |
| [T-147](T-147.md) | Per-day capacity from the venue capacity, offline allocations, floor on commitments | backend | 2 | T-146, T-004 | not started |
| [T-148](T-148.md) | One credential per covered day under the same pass; one place reserved per date | backend | 2 | T-147 | not started |
| [T-149](T-149.md) | v2 scan endpoint: per day, repeated scan refused, two doors at once, wrong day or event | backend | 2 | T-148, T-011 | not started |
| [T-150](T-150.md) | Entry cutoff per day (default event end) and the no-show job per day | backend | 2 | T-149 | not started |
| [T-151](T-151.md) | Guest-list approval hold (24 h default, 1-72 h, capped by entry cutoff) and release on expiry | backend | 2 | T-150, T-020 | not started |
| [T-152](T-152.md) | Tier auto progression on sellout and the startingPrice field (v2 shape) | backend | 2 | T-016 | not started |
| [T-153](T-153.md) | Availability badge LAST_TICKETS at 20% or less, exact counts hidden from public responses | backend | 2 | T-152 | not started |
| [T-154](T-154.md) | Venue staff reduce online inventory for offline sales, never below commitments | backend | 2 | T-147, T-104 | not started |
| [T-155](T-155.md) | Analytics: scans, no-shows and attendance rate (CR-08 remainder) | backend | 2 | T-150, T-061 | not started |
| [T-156](T-156.md) | Access codes: purpose, event or list, expiry, use limit; guest-list code requests | backend | 2 | T-018, T-151 | blocked by client: priority (Q19) |
| [T-157](T-157.md) | Migration: venue authorization record, uploaded evidence, admin decision, public label | backend | 2 | T-048 | blocked by client: authorization form wording (item 07) |
| [T-158](T-158.md) | Unregistered venue events: submit form and evidence, sales blocked until approval | backend | 2 | T-157 | not started |
| [T-159](T-159.md) | Admin review of venue authorizations with notices | backend | 2 | T-158 | blocked by client: D12 (named reviewers) |
| [T-160](T-160.md) | Venue dispute: suspend sales, tickets stay valid, decision in 2 working days, escalation for imminent events | backend | 2 | T-159, T-144 | blocked by client: working-day calendar (Q25) |
| [T-161](T-161.md) | Public label Presented by organizer at venue on the event page | backend | 2 | T-158, T-052 | not started |
| [T-162](T-162.md) | Migration: destination areas (Cote d Azur) independent of the radius, town membership | backend | 2 | T-031 | blocked by client: town list or boundary (Q26) |
| [T-163](T-163.md) | Explore and map by destination area, per-destination activation, empty-state reasons | backend | 2 | T-162, T-034 | not started |
| [T-164](T-164.md) | Activate the eleven destinations and set time zones; first-party-on-its-way text key | backend | 2 | T-163, T-032 | blocked by client: activation confirmation per city (Q27) |
| [T-165](T-165.md) | Migration: booking conversations, messages, flags, retention fields | backend | 2 | T-112 | not started |
| [T-166](T-166.md) | Chat endpoints: owner, authorized staff, authorized organizers, customer; read states | backend | 2 | T-165, T-106 | not started |
| [T-167](T-167.md) | Detect and flag attempts to move a booking elsewhere; protection message | backend | 2 | T-166 | not started |
| [T-168](T-168.md) | Retention job: delete 30 days after booking closure, or after dispute closure | backend | 2 | T-166 | blocked by client: legal check of 30-day deletion (adviser) |
| [T-169](T-169.md) | Support link setting: the single Bookdia WhatsApp number and the suggested text | backend | 2 | T-166 | blocked by client: WhatsApp number (Q6) |
| [T-170](T-170.md) | Admin and platform-staff chat review and intervention endpoints | backend | 2 | T-166, T-107 | not started |
| [T-171](T-171.md) | Push notifications for chat, quotes, holds, transfers and approvals | backend | 2 | T-166, T-047 | not started (push access received; confirm platform and permissions with the product owner) |
| [T-172](T-172.md) | Backend texts (emails, push, error messages) in EN, IT, FR, ES with per-user language | backend | 2 | T-088 | not started |
| [T-173](T-173.md) | Legal document versions per language in the admin module | backend | 2 | T-172 | blocked by client: final legal texts (item 08) |
| [T-174](T-174.md) | Event age rule field and the age warning text key; signup keeps 18+ (no code change to the minimum) | backend | 2 | T-017 | blocked by client: adviser written confirmation (Q31) |
| [T-175](T-175.md) | Admin page: partner approvals queue | admin | 2 | T-070, T-083 | not started |
| [T-176](T-176.md) | Admin page: role permissions (per page and sensitive actions) and platform staff | admin | 2 | T-070, T-109 | not started |
| [T-177](T-177.md) | Admin page: club team accounts and suspension | admin | 2 | T-176, T-103 | not started |
| [T-178](T-178.md) | Admin page: settlements, transfers, retries and statements | admin | 2 | T-070, T-132 | not started |
| [T-179](T-179.md) | Admin page: refund oversight, partner debits, waiver and Charge to club | admin | 2 | T-070, T-142 | not started |
| [T-180](T-180.md) | Admin page: booking chat review and intervention | admin | 2 | T-070, T-170 | not started |
| [T-181](T-181.md) | Admin page: venue authorization review and disputes | admin | 2 | T-070, T-160 | not started |
| [T-182](T-182.md) | Admin: destination areas and activation in the Cities page | admin | 2 | T-071, T-164 | not started |
| [T-183](T-183.md) | Admin page: audit log for sensitive actions | admin | 2 | T-176 | not started |
| [T-184](T-184.md) | Admin and owner screens for access and discount codes | admin | 2 | T-156, T-070 | not started |
| [T-185](T-185.md) | Owner acceptance run on the labelled test accounts, tracker evidence per ID | backend | 2 | T-111 | blocked by client: tester availability (item 05) |
| [T-186](T-186.md) | The five end-to-end demonstrations from the client answers (tables, split, passes, refunds, staff roles) | backend | 2 | T-133, T-145, T-149, T-111 | not started (needs the product owner available for the demonstrations) |
