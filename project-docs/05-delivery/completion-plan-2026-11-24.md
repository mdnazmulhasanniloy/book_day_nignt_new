# Completion plan (2026-11-24)

Branch `docs/client-answers-02`. Source of the client decisions: `01-discovery/client-answers-02.md` (24 November 2026) and `01-discovery/client-answers-01.md`. Client-facing companion: `scope-and-timeline-2026-11-24.md`. Questions we still owe the client: `client-clarifications-2026-11-24.md` (internal map next to it). Italian ticketing: `siae-decision-memo-2026-11-24.md`. Nothing here is committed, pushed, merged or deployed.

How to read this plan: the **work queue** (section 5) is the one ordered list. A person with no other instruction takes the first task that is not blocked. Planned dates assume the real team: **one developer for backend and admin (working with Claude) and one Flutter developer (working with Claude)**, a 30% allowance on the effort of every task, no work from 24 December to 1 January, and the client answers marked "blocked" arriving by 7 December (High-priority answers are asked for by 4 December). Access received per the product owner: Stripe, Apple and Google, push. Hosting (DigitalOcean) is not confirmed, so the stalled-count run is blocked. The estimate per task is the raw estimate (max half a day); the planned dates already include the allowance.

## 1. Where we are

### Backend (`backend/`)

| State | What |
|---|---|
| Done in `main` | Hotfix HF-001 to HF-004 (verified by file comparison only; tests to be re-run in REL-HF; same for T-001 to T-003). M1 security and correctness (T-001 to T-014). M2 sections, presets, promo, guest list (T-015 to T-021). M4 discovery (T-029 to T-046: cities, radius, grouping, filters, map, Interested, views, artists, event page fields, ticket buckets). Contract sync of `openapi.yaml`, share-page XSS fix, lineup artist protection, root CI workflow, staging plan and checklist, merge plan. All done in code and tested locally. **None of it is deployed.** |
| In progress | `fix/merge-hotfix` (local, `c31c358`): `main` plus HF-005 media authentication. Typecheck clean, 167 of 167 tests pass, database suites not run (no test database). Waiting for approval to push. This docs branch. |
| Remaining | M3 fees and server total (T-022 to T-028 and the new fee tasks), partner approval gate, roles, tables and card holds, settlement and payouts, refund engine, multi-day passes and scanning, venues and areas, chat, languages, purchase limits, time zone backfill, stalled-count report: 122 tasks in the queue. |
| Not built and not planned (new scope, awaiting client approval) | Italian fiscal ticketing, market setups for France, Monaco, Spain and the United States, legal terms drafting, referral, resale and waitlist, attendee messaging. |

### Admin (`admin/`)

| State | What |
|---|---|
| Done | The existing dashboard (accounts, clubs, events, earnings, notifications, settings). No test runner yet. |
| In progress | Nothing. |
| Remaining | M7: test setup, shared states, pages for cities, genres and moods, artists, organizers, pricing rules, financials, orders, refunds, plus new pages for partner approvals, roles and permissions, team accounts, settlements, refund oversight, chat review, venue review, areas, codes, audit, fee preview: 20 tasks. |

### Flutter app (`flutter_app/`)

| State | What |
|---|---|
| Done | The live production app. The early fixes exist only as task files (FL-B07, FL-B08, FL-P01). |
| In progress | Nothing. Flutter integration was held back until backend and admin were done; the backend discovery work is complete, so it starts in Phase 1. |
| Remaining | Phase 1: update gate, pending-approval signup, discovery screens, ticket buckets, tier ids, auth fixes (10 tasks plus the 3 early fixes). Phase 2: server total in checkout, tables, chat, roles, cancellation, passes, scanning, owner settlement screens, venues, areas, languages, age (25 tasks). Phase 3: remaining languages (1). |

## 2. Phases and dates

| Phase | Goal | Planned end |
|---|---|---|
| 1 | A stable build for the client's owner testing: finished work and the hotfixes released after written approval, discovery and sign-in fixes in the app, the approval gate for new partners, the update gate in the app, time zone backfill, purchase limits, read-only report on stalled sold counts | **2026-12-21** (last development task 2026-12-09, then release approvals and store review) |
| 2 | Launch scope of the client answers (Q34 "Launch" list), released in steps with the checkpoints of section 4 | Fees, server total and update gate released **2027-02-10**; all other milestones **2027-03 to 2027-04**; ready for final testing **2027-04-27**; launch candidate **2027-05-07** after owner testing, fixes and store review |
| 3 | Soon after launch: remaining app languages (planned), referral and resale (estimate only, see section 7) | Starts after REL-L; dates after the client decides section 7 |

Mid-December is not a fixed date (decision of the product owner). Early January is not reachable for the Phase 2 scope.

Larger team, in one line: a second backend/admin developer brings Phase 2 to about 2027-02-23; a second Flutter developer as well, to about 2027-02-01. Moving items out of the launch list brings the date forward by about one week for every 5 days removed.

## 3. Totals and critical path

| Stack | Phase 1 (days) | Phase 2 (days) | Phase 3 (days) |
|---|---|---|---|
| Backend | 5.0 | 56.0 | 0 |
| Admin | 0 | 10.0 | 0 |
| Flutter | 5.0 | 11.8 | 0.5 |

Raw task days, tasks only (without the 21 release checkpoints). With the 30% allowance and the checkpoints, about 125 person-days.

**Critical path.** With one developer for backend and admin, the critical path is that single lane: Phase 2 is 56 backend plus 10 admin raw days, about 86 working days with the allowance (about 17 weeks), so it ends 2027-04-27. The Flutter lane has 12 raw days in Phase 2 and waits on backend milestones. The dependency chain itself is short: fee base (T-022) to fee rules and allocation (T-093, T-094), ledger (T-126), scheduled transfers (T-127), holds (T-128), reversals (T-130), demonstration pack (T-133) and the five demonstrations (T-186): about 6.5 days of dependent work. The end date is therefore set by team size and by waiting time, not by dependencies. The real risks on the path are: (1) the Stripe spikes (T-090 to T-092): access is received, but Connect permissions and per-country eligibility (Monaco) are still to be verified before tables, settlement and transfers; (2) the written approval and store review lag of each release (the release chain REL-HF, REL-M1, REL-M2, REL-M4, REL-MG, REL-M8a is 17 working days on its own); (3) the client answers for the blocked tasks (section 6).

## 4. Milestones and release checkpoints

| Milestone | Release checkpoint | Phase | Tasks | Person-days | Done by (planned) |
|---|---|---|---|---|---|
| M2b | REL-M2 | 1 | 2 | 1.0 | 2026-12-01 |
| M8a | REL-M8a | 1 | 13 | 6.5 | 2026-12-10 |
| MG | REL-MG | 1 | 4 | 2.0 | 2026-12-09 |
| M3 | REL-M3 | 1/2 | 15 | 8.0 | 2027-01-27 |
| M14 | REL-M14 | 1/2 | 4 | 2.0 | 2027-04-01 |
| M1b | REL-M1 | 1 | 2 | 1.0 | 2026-12-08 |
| M8b | REL-M8b | 2 | 25 | 12.2 | 2027-04-02 |
| M5 | REL-M5 | 2 | 23 | 11.5 | 2027-03-15 |
| M0s | REL-M5 | 2 | 3 | 1.2 | 2027-04-02 |
| M9 | REL-M9 | 2 | 11 | 5.5 | 2027-03-11 |
| M6 | REL-M6 | 2 | 19 | 9.5 | 2027-03-22 |
| M11 | REL-M11 | 2 | 11 | 5.5 | 2027-03-24 |
| M10 | REL-M10 | 2 | 11 | 5.5 | 2027-03-18 |
| M12 | REL-M12 | 2 | 8 | 4.0 | 2027-03-26 |
| M7 | REL-M7 | 2 | 20 | 10.0 | 2027-04-26 |
| M13 | REL-M13 | 2 | 7 | 3.2 | 2027-04-02 |
| REL-L | REL-L | 2 | 2 | 1.0 | 2027-04-27 |
| M8c | REL-M8c | 3 | 1 | 0.5 | 2027-05-03 |

Order of release: REL-HF, REL-M1, REL-M2, REL-M4, REL-MG, REL-M8a (end of Phase 1); then REL-M3 together with the Flutter fee change and the update gate (they ship together, decision 1 of section 8), REL-M9, REL-M5, REL-M10, REL-M6, REL-M11, REL-M12, REL-M13, REL-M14, REL-M7, REL-M8b, REL-L.

Every checkpoint has its own file in `tasks/` (review, staging deploy, smoke list, production deploy, rollback note). A checkpoint stays blocked until the client gives written release approval.

## 5. Work queue (the exact order)

Rules: one task at a time per person; failing test first; contract docs in the same change; a task is done only when its listed tests pass; migrations pass the rehearsal script; nothing is released or pushed without written approval. Tasks marked BLOCKED wait for the named client item; take the next task meanwhile. Releases are marked "approval". Planned dates are per lane (backend, admin, Flutter work in parallel).

| # | Task | Title | Stack | Phase | Milestone | Depends on | Days | Blocked by client | Planned start | Planned end |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | [REL-HF](tasks/REL-HF.md) | Release checkpoint: hotfix HF-001..HF-005 (incl. merge of fix/merge-hotfix) | backend | 1 | REL | - | 0.50 | approval | 2026-11-30 | 2026-11-30 |
| 2 | [T-084](tasks/T-084.md) | Time zone backfill for existing events from venue and city, with an ambiguous-records report | backend | 1 | M2b | - | 0.50 |  | 2026-11-30 | 2026-12-01 |
| 3 | [FL-103](tasks/FL-103.md) | Flutter: city selector, radius 10-50 km (30 default), cityId on explore | flutter | 1 | M8a | - | 0.50 |  | 2026-11-30 | 2026-11-30 |
| 4 | [FL-104](tasks/FL-104.md) | Flutter: day grouping, date range, filters from /explore/filters, result total | flutter | 1 | M8a | - | 0.50 |  | 2026-11-30 | 2026-12-01 |
| 5 | [T-087](tasks/T-087.md) | Purchase limits: 5 per order, 10 per customer per event (configurable per event), repeat-cancellation flag | backend | 1 | M2b | - | 0.50 |  | 2026-12-01 | 2026-12-01 |
| 6 | [T-080](tasks/T-080.md) | Migration: partner approval status, application table, backfill existing owners as approved | backend | 1 | MG | - | 0.50 |  | 2026-12-01 | 2026-12-02 |
| 7 | [FL-105](tasks/FL-105.md) | Flutter: map view from /explore/map | flutter | 1 | M8a | - | 0.50 |  | 2026-12-01 | 2026-12-01 |
| 8 | [FL-106](tasks/FL-106.md) | Flutter: Interested button and count, recently viewed, most viewed, trending | flutter | 1 | M8a | - | 0.50 |  | 2026-12-01 | 2026-12-02 |
| 9 | [T-081](tasks/T-081.md) | Signup and social sign-in: new club owners and organizers start PENDING; partnerStatus added to auth responses | backend | 1 | MG | T-080 | 0.50 |  | 2026-12-02 | 2026-12-03 |
| 10 | [FL-107](tasks/FL-107.md) | Flutter: event page fields (club, map link, interested count, timezone display) | flutter | 1 | M8a | - | 0.50 |  | 2026-12-02 | 2026-12-03 |
| 11 | [T-082](tasks/T-082.md) | Partner gate middleware: 423 PARTNER_APPROVAL_PENDING (never 401/403) with the club-area home allowed | backend | 1 | MG | T-081 | 0.50 |  | 2026-12-03 | 2026-12-03 |
| 12 | [T-089](tasks/T-089.md) | Version policy endpoint and minimum supported version setting | backend | 1 | M3 | - | 0.50 |  | 2026-12-03 | 2026-12-04 |
| 13 | [FL-102](tasks/FL-102.md) | Flutter: signup change and pending-approval screen driven by partnerStatus and 423 | flutter | 1 | M8a | T-082 | 0.50 |  | 2026-12-03 | 2026-12-03 |
| 14 | [FL-108](tasks/FL-108.md) | Flutter: artist list, profile, follow | flutter | 1 | M8a | - | 0.50 |  | 2026-12-03 | 2026-12-04 |
| 15 | [FL-101](tasks/FL-101.md) | Flutter: version policy check at launch and the update-required screen | flutter | 1 | M8a | T-089 | 0.50 |  | 2026-12-04 | 2026-12-07 |
| 16 | [T-088](tasks/T-088.md) | Language inventory of the Flutter app and backend texts (emails, push, errors) for EN, IT, FR, ES | backend | 1 | M14 | - | 0.50 |  | 2026-12-04 | 2026-12-07 |
| 17 | [T-085](tasks/T-085.md) | Run the stalled-checkout list on live data (read-only) and produce the per-event report | backend | 1 | M1b | - | 0.50 | BLOCKED: hosting or database access (item 04) | 2026-12-07 | 2026-12-07 |
| 18 | [T-086](tasks/T-086.md) | Per-event correction script for sold counts, run only after written approval for each event | backend | 1 | M1b | T-085 | 0.50 | BLOCKED: client written OK per event | 2026-12-07 | 2026-12-08 |
| 19 | [FL-109](tasks/FL-109.md) | Flutter: My tickets buckets (future, pending, past) and booking status | flutter | 1 | M8a | - | 0.50 |  | 2026-12-07 | 2026-12-07 |
| 20 | [FL-110](tasks/FL-110.md) | Flutter: send tier ids on event update, handle new error status codes (404/409/422) | flutter | 1 | M8a | - | 0.50 |  | 2026-12-07 | 2026-12-08 |
| 21 | [REL-M1](tasks/REL-M1.md) | Release checkpoint: M1 security and correctness | backend | 1 | REL | REL-HF, T-085, T-086 | 0.50 | approval | 2026-12-08 | 2026-12-08 |
| 22 | [T-083](tasks/T-083.md) | Admin endpoints: list, approve, reject partner applications, with notification | backend | 1 | MG | T-082 | 0.50 | BLOCKED: D12 (named approvers) | 2026-12-08 | 2026-12-09 |
| 23 | [FL-B07](tasks/FL-B07.md) | Flutter: handle 401 and refresh (existing early task) | flutter | 1 | M8a | - | 0.50 | approval | 2026-12-08 | 2026-12-08 |
| 24 | [REL-M2](tasks/REL-M2.md) | Release checkpoint: M2 ticket sections, presets, promo, guest list | backend | 1 | REL | REL-M1, T-084, T-087 | 0.50 | approval | 2026-12-09 | 2026-12-09 |
| 25 | [FL-B08](tasks/FL-B08.md) | Flutter: call POST /auth/refresh (existing early task) | flutter | 1 | M8a | - | 0.50 | approval | 2026-12-09 | 2026-12-09 |
| 26 | [FL-P01](tasks/FL-P01.md) | Flutter: owner signup and date-of-birth rule fix (existing early task) | flutter | 1 | M8a | - | 0.50 | approval | 2026-12-09 | 2026-12-09 |
| 27 | [REL-M4](tasks/REL-M4.md) | Release checkpoint: M4 discovery backend | backend | 1 | REL | REL-M2 | 0.50 | approval | 2026-12-10 | 2026-12-10 |
| 28 | [REL-MG](tasks/REL-MG.md) | Release checkpoint: partner approval gate | backend | 1 | REL | REL-M4, T-083, T-080, T-081, T-082 | 0.50 | approval | 2026-12-11 | 2026-12-14 |
| 29 | [REL-M8a](tasks/REL-M8.md) | Release checkpoint: M8a Flutter build (Phase 1 build for owner testing) | flutter | 1 | REL | FL-101, FL-102, FL-103, FL-104, FL-105, FL-106, FL-107, F... | 0.50 | approval | 2026-12-15 | 2026-12-15 |
| 30 | [T-022](tasks/T-022.md) | Migration 6: pricing rules, relaxed Order CHECKs, and v1 write-through | backend | 2 | M3 | - | 1.00 |  | 2026-12-10 | 2026-12-11 |
| 31 | [FL-113](tasks/FL-113.md) | Flutter: French and Spanish complete across app flows, language inventory reconciled | flutter | 2 | M8b | T-088 | 0.50 | BLOCKED: translations review | 2026-12-10 | 2026-12-10 |
| 32 | [FL-129](tasks/FL-129.md) | Flutter: purchase limit messages | flutter | 2 | M8b | T-087 | 0.25 |  | 2026-12-10 | 2026-12-10 |
| 33 | [T-093](tasks/T-093.md) | Fee rule: percent plus fixed part, fixed once per order, fixed amount per currency, country and quote scopes | backend | 2 | M3 | T-022 | 0.50 |  | 2026-12-14 | 2026-12-14 |
| 34 | [T-054](tasks/T-054.md) | Migration 8: extras, module pricing type, quote and host contact user links | backend | 2 | M5 | - | 0.50 |  | 2026-12-14 | 2026-12-15 |
| 35 | [T-094](tasks/T-094.md) | Fee allocation per item and rates saved on the order, for partial refunds | backend | 2 | M3 | T-093 | 0.50 |  | 2026-12-15 | 2026-12-16 |
| 36 | [T-058](tasks/T-058.md) | v2 authenticated quotes, and rate limits plus user link on v1 quotes and host contact | backend | 2 | M5 | T-054 | 0.50 |  | 2026-12-16 | 2026-12-16 |
| 37 | [T-090](tasks/T-090.md) | Stripe test-mode spike 1: manual-capture hold, capture, cancel, expiry, unsupported methods | backend | 2 | M0s | - | 0.50 |  | 2026-12-16 | 2026-12-17 |
| 38 | [T-101](tasks/T-101.md) | Migration: club team members, platform staff, permission grants, audit rows (AccountRole untouched) | backend | 2 | M9 | T-080 | 0.50 |  | 2026-12-17 | 2026-12-18 |
| 39 | [T-112](tasks/T-112.md) | Migration: table requests, quotes (expiry, withdrawn), payment plan, policy snapshot | backend | 2 | M5 | T-054 | 0.50 |  | 2026-12-18 | 2026-12-18 |
| 40 | [T-134](tasks/T-134.md) | Migration: per-ticket status, refunds one-to-many, refund items, goodwill amounts | backend | 2 | M6 | - | 0.50 |  | 2026-12-18 | 2026-12-21 |
| 41 | [T-096](tasks/T-096.md) | Server-calculated total: POST /v2/checkout/preview for tickets, tables, extras and baskets | backend | 2 | M3 | T-094 | 0.50 |  | 2026-12-21 | 2026-12-22 |
| 42 | [T-091](tasks/T-091.md) | Stripe spike 2: separate charges and transfers, reversals, available-balance limits, failed transfers | backend | 2 | M0s | T-090 | 0.50 |  | 2026-12-22 | 2026-12-22 |
| 43 | [T-102](tasks/T-102.md) | Permission catalogue and resolver: page view/manage plus sensitive actions | backend | 2 | M9 | T-101 | 0.50 | BLOCKED: default permission matrix (Q24) | 2026-12-22 | 2026-12-23 |
| 44 | [T-113](tasks/T-113.md) | Quote lifecycle: issue, configurable expiry capped by the booking deadline, withdraw, notify | backend | 2 | M5 | T-112, T-058 | 0.50 |  | 2026-12-23 | 2027-01-04 |
| 45 | [T-135](tasks/T-135.md) | Cancellation policy per event (cutoff in hours or non-refundable), shown before purchase | backend | 2 | M6 | T-134 | 0.50 |  | 2027-01-04 | 2027-01-04 |
| 46 | [T-146](tasks/T-146.md) | Migration: event days, pass day entitlements, entry scans | backend | 2 | M11 | - | 0.50 |  | 2027-01-04 | 2027-01-05 |
| 47 | [FL-115](tasks/FL-115.md) | Flutter: table request screen, quote view with time left, withdrawn quote state | flutter | 2 | M8b | T-113 | 0.50 |  | 2027-01-04 | 2027-01-04 |
| 48 | [T-097](tasks/T-097.md) | Display mode per market and category (itemized or included) in the preview response | backend | 2 | M3 | T-096 | 0.50 | BLOCKED: inclusive-display markets (Q2) | 2027-01-05 | 2027-01-06 |
| 49 | [T-047](tasks/T-047.md) | Migration 2: notification types | backend | 2 | M5 | - | 0.50 |  | 2027-01-06 | 2027-01-06 |
| 50 | [T-103](tasks/T-103.md) | Club team: invite, accept, suspend, remove (owner), suspend any (platform) | backend | 2 | M9 | T-102 | 0.50 |  | 2027-01-06 | 2027-01-07 |
| 51 | [FL-111](tasks/FL-111.md) | Flutter: checkout uses the server-calculated total and shows fee lines per display mode | flutter | 2 | M8b | T-097 | 0.50 |  | 2027-01-06 | 2027-01-06 |
| 52 | [FL-112](tasks/FL-112.md) | Flutter: remove the client-side fee calculation, keep one price source for all products | flutter | 2 | M8b | FL-111 | 0.50 |  | 2027-01-06 | 2027-01-07 |
| 53 | [T-114](tasks/T-114.md) | Atomic table reservation on acceptance and no simultaneous sale of one table | backend | 2 | M5 | T-113 | 0.50 |  | 2027-01-07 | 2027-01-07 |
| 54 | [T-123](tasks/T-123.md) | Migration: settlement arrangement, ledger entries, transfers | backend | 2 | M10 | T-091 | 0.50 |  | 2027-01-08 | 2027-01-08 |
| 55 | [T-136](tasks/T-136.md) | Customer cancels one ticket in time: invalidate that credential, keep the others | backend | 2 | M6 | T-135 | 0.50 |  | 2027-01-08 | 2027-01-11 |
| 56 | [T-147](tasks/T-147.md) | Per-day capacity from the venue capacity, offline allocations, floor on commitments | backend | 2 | M11 | T-146 | 0.50 |  | 2027-01-11 | 2027-01-11 |
| 57 | [T-024](tasks/T-024.md) | Apply pricing rules at event ticket checkout | backend | 2 | M3 | - | 0.50 |  | 2027-01-11 | 2027-01-12 |
| 58 | [FL-122](tasks/FL-122.md) | Flutter: cancellation policy on checkout and cancel one ticket with refund preview | flutter | 2 | M8b | T-136 | 0.50 |  | 2027-01-11 | 2027-01-11 |
| 59 | [T-098](tasks/T-098.md) | Keep /service-charge and the old purchase response working for old app versions, with tests | backend | 2 | M3 | T-093 | 0.50 |  | 2027-01-12 | 2027-01-13 |
| 60 | [T-048](tasks/T-048.md) | Migration 9: organizers and collaboration requests | backend | 2 | M5 | T-047 | 0.50 |  | 2027-01-13 | 2027-01-13 |
| 61 | [T-059](tasks/T-059.md) | Migration 13: analytics and admin-order indexes | backend | 2 | M6 | - | 0.50 |  | 2027-01-13 | 2027-01-14 |
| 62 | [T-104](tasks/T-104.md) | Enforce club roles on events, bookings and check-in (assigned events only) | backend | 2 | M9 | T-103 | 0.50 |  | 2027-01-14 | 2027-01-15 |
| 63 | [T-107](tasks/T-107.md) | Platform roles (Manager, Country Manager, Staff) and the country limit on admin endpoints | backend | 2 | M9 | T-102 | 0.50 |  | 2027-01-15 | 2027-01-15 |
| 64 | [T-115](tasks/T-115.md) | Table request with card authorization: request, pending, reject releases the hold | backend | 2 | M5 | T-114, T-090 | 0.50 |  | 2027-01-15 | 2027-01-18 |
| 65 | [T-126](tasks/T-126.md) | Ledger and share states: Pending, then Confirmed - scheduled for transfer with the expected date | backend | 2 | M10 | T-123, T-094 | 0.50 |  | 2027-01-18 | 2027-01-19 |
| 66 | [T-137](tasks/T-137.md) | Refund orchestration: admission refund, commission reversal, Technical Fee retained, pending until the processor confirms | backend | 2 | M6 | T-136, T-094 | 0.50 |  | 2027-01-19 | 2027-01-19 |
| 67 | [T-148](tasks/T-148.md) | One credential per covered day under the same pass; one place reserved per date | backend | 2 | M11 | T-147 | 0.50 |  | 2027-01-19 | 2027-01-20 |
| 68 | [T-023](tasks/T-023.md) | Pricing rule resolver (precedence and effective dates) | backend | 2 | M3 | - | 0.50 |  | 2027-01-20 | 2027-01-21 |
| 69 | [FL-125](tasks/FL-125.md) | Flutter: per-day tickets and QR credential | flutter | 2 | M8b | T-148 | 0.50 |  | 2027-01-20 | 2027-01-20 |
| 70 | [T-025](tasks/T-025.md) | Apply pricing rules at table and club-booking checkout | backend | 2 | M3 | T-024 | 0.50 |  | 2027-01-21 | 2027-01-21 |
| 71 | [T-026](tasks/T-026.md) | Free ticket checkout (price 0, instant confirm) | backend | 2 | M3 | - | 0.50 |  | 2027-01-21 | 2027-01-22 |
| 72 | [T-027](tasks/T-027.md) | v2 admin pricing-rules endpoints and v1 deprecation headers | backend | 2 | M3 | - | 0.50 |  | 2027-01-22 | 2027-01-25 |
| 73 | [T-028](tasks/T-028.md) | v2 financials report endpoint | backend | 2 | M3 | - | 0.50 |  | 2027-01-25 | 2027-01-25 |
| 74 | [T-095](tasks/T-095.md) | Record the actual processor cost per payment and per issued ticket, separate from commission | backend | 2 | M3 | - | 0.50 |  | 2027-01-25 | 2027-01-26 |
| 75 | [T-099](tasks/T-099.md) | Minimum-version enforcement switch: fee model v2 active only when the gate is on | backend | 2 | M3 | T-089, T-098 | 0.50 |  | 2027-01-26 | 2027-01-26 |
| 76 | [T-049](tasks/T-049.md) | Organizer profile: create, update, public view | backend | 2 | M5 | T-048 | 0.50 |  | 2027-01-27 | 2027-01-27 |
| 77 | [T-060](tasks/T-060.md) | Owner earnings: include tables, event-timezone day boundaries | backend | 2 | M6 | T-059 | 0.50 |  | 2027-01-27 | 2027-01-28 |
| 78 | [T-105](tasks/T-105.md) | Enforce club roles on revenue, refunds, payout destination and team changes | backend | 2 | M9 | T-104 | 0.50 |  | 2027-01-28 | 2027-01-28 |
| 79 | [T-108](tasks/T-108.md) | Sensitive actions reserved to Admin: rates, payouts, Technical Fee refunds, club debits, admin management | backend | 2 | M9 | T-107 | 0.50 |  | 2027-01-28 | 2027-01-29 |
| 80 | [T-116](tasks/T-116.md) | Accept, capture before capture_before, capture failure releases the table | backend | 2 | M5 | T-115 | 0.50 |  | 2027-01-29 | 2027-02-01 |
| 81 | [T-127](tasks/T-127.md) | Scheduler job: initiate transfers 3 calendar days after event end | backend | 2 | M10 | T-126 | 0.50 |  | 2027-02-01 | 2027-02-01 |
| 82 | [T-140](tasks/T-140.md) | Partner cancellation: admission refund, commission reversal, Technical Fee refund flag per market | backend | 2 | M6 | T-137 | 0.50 | BLOCKED: Technical Fee rule on partner cancellation (adviser) | 2027-02-01 | 2027-02-02 |
| 83 | [FL-116](tasks/FL-116.md) | Flutter: card hold flow, pending status, release status, payment retry | flutter | 2 | M8b | T-116 | 0.50 |  | 2027-02-01 | 2027-02-01 |
| 84 | [T-149](tasks/T-149.md) | v2 scan endpoint: per day, repeated scan refused, two doors at once, wrong day or event | backend | 2 | M11 | T-148 | 0.50 |  | 2027-02-02 | 2027-02-03 |
| 85 | [T-157](tasks/T-157.md) | Migration: venue authorization record, uploaded evidence, admin decision, public label | backend | 2 | M12 | T-048 | 0.50 | BLOCKED: authorization form wording (item 07) | 2027-02-03 | 2027-02-03 |
| 86 | [REL-M3](tasks/REL-M3.md) | Release checkpoint: M3 fees, server total, gate (backend + Flutter together) | backend | 2 | REL | T-028, T-099, FL-112, REL-M8a, T-089, T-093, T-094, T-095... | 0.50 | approval | 2027-02-03 | 2027-02-04 |
| 87 | [FL-126](tasks/FL-126.md) | Flutter: scanner uses the v2 scan endpoint, per-day and repeat results | flutter | 2 | M8b | T-149 | 0.50 |  | 2027-02-03 | 2027-02-03 |
| 88 | [T-051](tasks/T-051.md) | Collaboration requests: create, list, respond, notify | backend | 2 | M5 | T-048, T-047, T-049 | 0.50 |  | 2027-02-04 | 2027-02-04 |
| 89 | [T-061](tasks/T-061.md) | Owner analytics: GET /owner/analytics | backend | 2 | M6 | T-059, T-060 | 0.50 |  | 2027-02-05 | 2027-02-05 |
| 90 | [T-070](tasks/T-070.md) | Admin scaffolding: test setup, shared data-state components, routes, i18n | admin | 2 | M7 | - | 0.50 |  | 2027-02-05 | 2027-02-08 |
| 91 | [T-106](tasks/T-106.md) | Organizer permissions for quotes, chat and refunds: off by default, granted one by one, history kept | backend | 2 | M9 | T-102, T-049 | 0.50 |  | 2027-02-08 | 2027-02-08 |
| 92 | [T-109](tasks/T-109.md) | Admin endpoints for the editable role-permissions page | backend | 2 | M9 | T-108 | 0.50 |  | 2027-02-08 | 2027-02-09 |
| 93 | [T-117](tasks/T-117.md) | Fresh payment after acceptance when a hold is unsupported or expired | backend | 2 | M5 | T-116 | 0.50 |  | 2027-02-09 | 2027-02-10 |
| 94 | [T-128](tasks/T-128.md) | Hold the amount affected by an open refund or dispute and release the rest | backend | 2 | M10 | T-127 | 0.50 |  | 2027-02-10 | 2027-02-10 |
| 95 | [T-138](tasks/T-138.md) | Club exception refunds and documented partial goodwill refunds with admission kept | backend | 2 | M6 | T-137, T-105 | 0.50 | BLOCKED: Italy goodwill treatment (adviser) | 2027-02-10 | 2027-02-11 |
| 96 | [T-141](tasks/T-141.md) | Partner debit and recovery: eligible balance, then future settlements, then invoice; never charged twice | backend | 2 | M6 | T-140, T-126 | 0.50 |  | 2027-02-11 | 2027-02-12 |
| 97 | [T-150](tasks/T-150.md) | Entry cutoff per day (default event end) and the no-show job per day | backend | 2 | M11 | T-149 | 0.50 |  | 2027-02-12 | 2027-02-12 |
| 98 | [T-158](tasks/T-158.md) | Unregistered venue events: submit form and evidence, sales blocked until approval | backend | 2 | M12 | T-157 | 0.50 |  | 2027-02-12 | 2027-02-15 |
| 99 | [T-162](tasks/T-162.md) | Migration: destination areas (Cote d Azur) independent of the radius, town membership | backend | 2 | M12 | - | 0.50 | BLOCKED: town list or boundary (Q26) | 2027-02-15 | 2027-02-16 |
| 100 | [T-165](tasks/T-165.md) | Migration: booking conversations, messages, flags, retention fields | backend | 2 | M13 | T-112 | 0.50 |  | 2027-02-16 | 2027-02-16 |
| 101 | [T-052](tasks/T-052.md) | Event organizerId and organizer identity on the event page | backend | 2 | M5 | T-049 | 0.50 |  | 2027-02-16 | 2027-02-17 |
| 102 | [T-053](tasks/T-053.md) | Admin organizers and collaboration requests endpoints | backend | 2 | M5 | T-049, T-051 | 0.50 |  | 2027-02-17 | 2027-02-18 |
| 103 | [T-055](tasks/T-055.md) | Event extras: CRUD endpoints | backend | 2 | M5 | T-054 | 0.50 |  | 2027-02-18 | 2027-02-18 |
| 104 | [T-056](tasks/T-056.md) | Table purchase: pricingType, QUOTE_REQUIRED and module idempotency body check | backend | 2 | M5 | T-054 | 0.50 |  | 2027-02-18 | 2027-02-19 |
| 105 | [T-062](tasks/T-062.md) | Owner per-event analytics: GET /owner/events/{eventId}/analytics | backend | 2 | M6 | T-061 | 0.50 |  | 2027-02-19 | 2027-02-22 |
| 106 | [T-067](tasks/T-067.md) | Handle Stripe refund webhook events | backend | 2 | M6 | T-134 | 0.50 |  | 2027-02-22 | 2027-02-22 |
| 107 | [T-068](tasks/T-068.md) | Admin orders, order detail and refunds list | backend | 2 | M6 | T-059, T-134 | 0.50 |  | 2027-02-22 | 2027-02-23 |
| 108 | [T-118](tasks/T-118.md) | Deposit modes: deposit online plus balance at venue, full online, two online payments | backend | 2 | M5 | T-117, T-094 | 0.50 |  | 2027-02-23 | 2027-02-23 |
| 109 | [T-124](tasks/T-124.md) | Settlement setup: admin share, owner proposal, organizer acceptance before sales open | backend | 2 | M10 | T-123, T-106 | 0.50 |  | 2027-02-24 | 2027-02-24 |
| 110 | [T-130](tasks/T-130.md) | Transfer reversals after refunds (full and partial) and the unrecovered amount | backend | 2 | M10 | T-128, T-137 | 0.50 |  | 2027-02-24 | 2027-02-25 |
| 111 | [FL-134](tasks/FL-134.md) | Flutter owner: settlement proposal and organizer acceptance screens | flutter | 2 | M8b | T-124 | 0.50 |  | 2027-02-24 | 2027-02-24 |
| 112 | [T-139](tasks/T-139.md) | Who may refund: owner, owner-permissioned organizer, staff forward requests, admin disputes | backend | 2 | M6 | T-138, T-106 | 0.50 |  | 2027-02-25 | 2027-02-25 |
| 113 | [T-142](tasks/T-142.md) | Admin waiver down to the unrecovered Stripe cost, and the admin-only Charge to club action, with audit | backend | 2 | M6 | T-141, T-108 | 0.50 |  | 2027-02-25 | 2027-02-26 |
| 114 | [T-144](tasks/T-144.md) | Date or venue change: notices, 7-day refund window, immediate route for a last-minute change | backend | 2 | M6 | T-137 | 0.50 | BLOCKED: last-minute threshold (Q11) | 2027-02-26 | 2027-03-01 |
| 115 | [T-151](tasks/T-151.md) | Guest-list approval hold (24 h default, 1-72 h, capped by entry cutoff) and release on expiry | backend | 2 | M11 | T-150 | 0.50 |  | 2027-03-01 | 2027-03-01 |
| 116 | [T-152](tasks/T-152.md) | Tier auto progression on sellout and the startingPrice field (v2 shape) | backend | 2 | M11 | - | 0.50 |  | 2027-03-01 | 2027-03-02 |
| 117 | [FL-123](tasks/FL-123.md) | Flutter: refund status and event change notice with the refund route and deadline | flutter | 2 | M8b | T-144, T-137 | 0.50 |  | 2027-03-01 | 2027-03-01 |
| 118 | [T-159](tasks/T-159.md) | Admin review of venue authorizations with notices | backend | 2 | M12 | T-158 | 0.50 | BLOCKED: D12 (named reviewers) | 2027-03-02 | 2027-03-03 |
| 119 | [FL-124](tasks/FL-124.md) | Flutter: multi-day pass purchase and per-day availability | flutter | 2 | M8b | T-148, T-152 | 0.50 |  | 2027-03-02 | 2027-03-02 |
| 120 | [T-163](tasks/T-163.md) | Explore and map by destination area, per-destination activation, empty-state reasons | backend | 2 | M12 | T-162 | 0.50 |  | 2027-03-03 | 2027-03-03 |
| 121 | [T-166](tasks/T-166.md) | Chat endpoints: owner, authorized staff, authorized organizers, customer; read states | backend | 2 | M13 | T-165, T-106 | 0.50 |  | 2027-03-03 | 2027-03-04 |
| 122 | [FL-132](tasks/FL-132.md) | Flutter: Cote d Azur area, empty-city text and no-result suggestions | flutter | 2 | M8b | T-163 | 0.50 |  | 2027-03-03 | 2027-03-03 |
| 123 | [T-172](tasks/T-172.md) | Backend texts (emails, push, error messages) in EN, IT, FR, ES with per-user language | backend | 2 | M14 | T-088 | 0.50 |  | 2027-03-04 | 2027-03-05 |
| 124 | [FL-119](tasks/FL-119.md) | Flutter: booking chat list and thread, read states | flutter | 2 | M8b | T-166 | 0.50 |  | 2027-03-04 | 2027-03-04 |
| 125 | [T-176](tasks/T-176.md) | Admin page: role permissions (per page and sensitive actions) and platform staff | admin | 2 | M7 | T-070, T-109 | 0.50 |  | 2027-03-05 | 2027-03-05 |
| 126 | [T-050](tasks/T-050.md) | Organizer follow and unfollow | backend | 2 | M5 | T-049 | 0.50 |  | 2027-03-05 | 2027-03-08 |
| 127 | [T-057](tasks/T-057.md) | Purchasable extras on module orders (with stock release and pricing rule) | backend | 2 | M5 | T-055, T-056 | 0.50 |  | 2027-03-08 | 2027-03-09 |
| 128 | [T-069](tasks/T-069.md) | Cross-account access test suite for owner, organizer and admin routes | backend | 2 | M6 | T-062, T-139, T-068, T-053, T-051, T-102, T-104, T-105, T... | 0.50 |  | 2027-03-09 | 2027-03-09 |
| 129 | [T-110](tasks/T-110.md) | Additive staff fields on login and check responses (teamRole, permissions) for the apps | backend | 2 | M9 | T-103 | 0.50 |  | 2027-03-09 | 2027-03-10 |
| 130 | [T-111](tasks/T-111.md) | Labelled test accounts for the ten roles (seed script, test payments only) | backend | 2 | M9 | T-108, T-105 | 0.50 |  | 2027-03-10 | 2027-03-11 |
| 131 | [FL-121](tasks/FL-121.md) | Flutter: role-aware navigation for staff and organizer permissions | flutter | 2 | M8b | T-110 | 0.50 |  | 2027-03-10 | 2027-03-10 |
| 132 | [T-119](tasks/T-119.md) | Second online payment: balance confirmation, deadline, fee only on the amount paid in app | backend | 2 | M5 | T-118 | 0.50 | BLOCKED: second-payment deadline (Q5) | 2027-03-11 | 2027-03-11 |
| 133 | [T-120](tasks/T-120.md) | Deposit and cancellation policy per table, terms accepted by the guest saved with the booking | backend | 2 | M5 | T-118 | 0.50 |  | 2027-03-11 | 2027-03-12 |
| 134 | [FL-117](tasks/FL-117.md) | Flutter: deposit options, balance and settlement terms, second payment | flutter | 2 | M8b | T-119 | 0.50 |  | 2027-03-11 | 2027-03-11 |
| 135 | [T-121](tasks/T-121.md) | Party size and admitted attendees recorded on a table booking, counted once in capacity | backend | 2 | M5 | T-114 | 0.50 |  | 2027-03-12 | 2027-03-12 |
| 136 | [FL-135](tasks/FL-135.md) | Flutter owner: issue, edit and withdraw quotes; table policy settings | flutter | 2 | M8b | T-120, T-104 | 0.50 |  | 2027-03-12 | 2027-03-12 |
| 137 | [T-122](tasks/T-122.md) | Commission shortfall when the online payment is smaller than the commission: partner receivable record | backend | 2 | M5 | T-118, T-126 | 0.50 |  | 2027-03-15 | 2027-03-15 |
| 138 | [T-125](tasks/T-125.md) | Fallback routing to the eligible club and flags for ineligible payees | backend | 2 | M10 | T-124 | 0.50 |  | 2027-03-15 | 2027-03-16 |
| 139 | [FL-118](tasks/FL-118.md) | Flutter: table cancellation policy shown before payment, party size, attendance | flutter | 2 | M8b | T-120, T-121 | 0.50 |  | 2027-03-15 | 2027-03-15 |
| 140 | [T-129](tasks/T-129.md) | Failed transfers: retry up to 3 times in 3 days, immediate notices, idempotency | backend | 2 | M10 | T-127 | 0.50 |  | 2027-03-16 | 2027-03-16 |
| 141 | [T-131](tasks/T-131.md) | Connect webhook events for transfers and payouts into the ledger | backend | 2 | M10 | T-127 | 0.50 |  | 2027-03-16 | 2027-03-17 |
| 142 | [T-132](tasks/T-132.md) | Partner statements and settlement reports (owner and admin) | backend | 2 | M10 | T-126 | 0.50 |  | 2027-03-17 | 2027-03-18 |
| 143 | [T-133](tasks/T-133.md) | Demonstration pack: one partially refunded order and one insufficient partner balance | backend | 2 | M10 | T-130 | 0.50 |  | 2027-03-18 | 2027-03-18 |
| 144 | [T-143](tasks/T-143.md) | Return eligible capacity on cancellation while sales are open; manual restock without double release | backend | 2 | M6 | T-136 | 0.50 |  | 2027-03-18 | 2027-03-19 |
| 145 | [FL-130](tasks/FL-130.md) | Flutter owner screens: settlement states, expected transfer date, statements | flutter | 2 | M8b | T-132 | 0.50 |  | 2027-03-18 | 2027-03-18 |
| 146 | [T-145](tasks/T-145.md) | Refund and chargeback reconciliation against bank credits, no double reimbursement | backend | 2 | M6 | T-142, T-067 | 0.50 |  | 2027-03-19 | 2027-03-22 |
| 147 | [T-153](tasks/T-153.md) | Availability badge LAST_TICKETS at 20% or less, exact counts hidden from public responses | backend | 2 | M11 | T-152 | 0.50 |  | 2027-03-22 | 2027-03-22 |
| 148 | [T-154](tasks/T-154.md) | Venue staff reduce online inventory for offline sales, never below commitments | backend | 2 | M11 | T-147, T-104 | 0.50 |  | 2027-03-22 | 2027-03-23 |
| 149 | [FL-127](tasks/FL-127.md) | Flutter: from-price, Last tickets badge and tier progression on event cards and page | flutter | 2 | M8b | T-153 | 0.50 |  | 2027-03-22 | 2027-03-22 |
| 150 | [T-155](tasks/T-155.md) | Analytics: scans, no-shows and attendance rate (CR-08 remainder) | backend | 2 | M11 | T-150, T-061 | 0.50 |  | 2027-03-23 | 2027-03-24 |
| 151 | [T-156](tasks/T-156.md) | Access codes: purpose, event or list, expiry, use limit; guest-list code requests | backend | 2 | M11 | T-151 | 0.50 | BLOCKED: priority (Q19) | 2027-03-24 | 2027-03-24 |
| 152 | [T-160](tasks/T-160.md) | Venue dispute: suspend sales, tickets stay valid, decision in 2 working days, escalation for imminent events | backend | 2 | M12 | T-159, T-144 | 0.50 | BLOCKED: working-day calendar (Q25) | 2027-03-24 | 2027-03-25 |
| 153 | [FL-128](tasks/FL-128.md) | Flutter: guest-list request, hold time, code entry | flutter | 2 | M8b | T-151, T-156 | 0.50 |  | 2027-03-24 | 2027-03-24 |
| 154 | [FL-136](tasks/FL-136.md) | Flutter owner: code management screen (discount and guest-list codes) | flutter | 2 | M8b | T-156 | 0.50 | BLOCKED: priority (Q19) | 2027-03-24 | 2027-03-25 |
| 155 | [T-161](tasks/T-161.md) | Public label Presented by organizer at venue on the event page | backend | 2 | M12 | T-158, T-052 | 0.50 |  | 2027-03-25 | 2027-03-26 |
| 156 | [T-164](tasks/T-164.md) | Activate the eleven destinations and set time zones; first-party-on-its-way text key | backend | 2 | M12 | T-163 | 0.50 | BLOCKED: activation confirmation per city (Q27) | 2027-03-26 | 2027-03-26 |
| 157 | [T-167](tasks/T-167.md) | Detect and flag attempts to move a booking elsewhere; protection message | backend | 2 | M13 | T-166 | 0.50 |  | 2027-03-26 | 2027-03-29 |
| 158 | [FL-131](tasks/FL-131.md) | Flutter: unregistered venue form and evidence upload, status, Presented-by label | flutter | 2 | M8b | T-158, T-161 | 0.50 |  | 2027-03-26 | 2027-03-26 |
| 159 | [T-168](tasks/T-168.md) | Retention job: delete 30 days after booking closure, or after dispute closure | backend | 2 | M13 | T-166 | 0.50 | BLOCKED: legal check of 30-day deletion (adviser) | 2027-03-29 | 2027-03-30 |
| 160 | [T-170](tasks/T-170.md) | Admin and platform-staff chat review and intervention endpoints | backend | 2 | M13 | T-166, T-107 | 0.50 |  | 2027-03-30 | 2027-03-30 |
| 161 | [T-171](tasks/T-171.md) | Push notifications for chat, quotes, holds, transfers and approvals | backend | 2 | M13 | T-166, T-047 | 0.50 |  | 2027-03-30 | 2027-03-31 |
| 162 | [T-173](tasks/T-173.md) | Legal document versions per language in the admin module | backend | 2 | M14 | T-172 | 0.50 | BLOCKED: final legal texts (item 08) | 2027-03-31 | 2027-03-31 |
| 163 | [T-174](tasks/T-174.md) | Event age rule field and the age warning text key; signup keeps 18+ (no code change to the minimum) | backend | 2 | M14 | - | 0.50 | BLOCKED: adviser written confirmation (Q31) | 2027-04-01 | 2027-04-01 |
| 164 | [T-183](tasks/T-183.md) | Admin page: audit log for sensitive actions | admin | 2 | M7 | T-176 | 0.50 |  | 2027-04-01 | 2027-04-02 |
| 165 | [FL-133](tasks/FL-133.md) | Flutter: age rule on the event page and the 18+ warning before booking | flutter | 2 | M8b | T-174 | 0.50 | BLOCKED: adviser confirmation (Q31) | 2027-04-01 | 2027-04-01 |
| 166 | [T-092](tasks/T-092.md) | Stripe payout eligibility report for Italy, France, Monaco, Spain and the US | backend | 2 | M0s | T-091 | 0.25 |  | 2027-04-02 | 2027-04-02 |
| 167 | [T-169](tasks/T-169.md) | Support link setting: the single Bookdia WhatsApp number and the suggested text | backend | 2 | M13 | T-166 | 0.25 | BLOCKED: WhatsApp number (Q6) | 2027-04-02 | 2027-04-02 |
| 168 | [REL-M10](tasks/REL-M10.md) | Release checkpoint: M10 settlement | backend | 2 | REL | T-092, T-133, T-131, T-129, T-123, T-124, T-125, T-126, T... | 0.50 | approval | 2027-04-02 | 2027-04-05 |
| 169 | [FL-120](tasks/FL-120.md) | Flutter: protection message, WhatsApp support link, push handling | flutter | 2 | M8b | T-169, T-171 | 0.50 |  | 2027-04-02 | 2027-04-02 |
| 170 | [REL-M11](tasks/REL-M11.md) | Release checkpoint: M11 passes and scanning | backend | 2 | REL | T-156, T-155, T-153, T-154, T-146, T-147, T-148, T-149, T... | 0.50 | approval | 2027-04-05 | 2027-04-05 |
| 171 | [REL-M12](tasks/REL-M12.md) | Release checkpoint: M12 venues and areas | backend | 2 | REL | T-160, T-161, T-164, T-157, T-158, T-159, T-162, T-163 | 0.50 | approval | 2027-04-05 | 2027-04-06 |
| 172 | [REL-M13](tasks/REL-M13.md) | Release checkpoint: M13 chat | backend | 2 | REL | T-170, T-168, T-171, T-169, T-167, T-165, T-166 | 0.50 | approval | 2027-04-06 | 2027-04-06 |
| 173 | [REL-M14](tasks/REL-M14.md) | Release checkpoint: M14 languages and age | backend | 2 | REL | T-173, T-174, T-088, T-172 | 0.50 | approval | 2027-04-06 | 2027-04-07 |
| 174 | [REL-M5](tasks/REL-M5.md) | Release checkpoint: M5 tables | backend | 2 | REL | T-092, T-058, T-122, T-120, T-121, T-090, T-091, T-112, T... | 0.50 | approval | 2027-04-07 | 2027-04-07 |
| 175 | [REL-M6](tasks/REL-M6.md) | Release checkpoint: M6 refunds | backend | 2 | REL | T-145, T-143, T-144, T-069, T-134, T-135, T-136, T-137, T... | 0.50 | approval | 2027-04-07 | 2027-04-08 |
| 176 | [REL-M9](tasks/REL-M9.md) | Release checkpoint: M9 roles | backend | 2 | REL | T-111, T-183, T-101, T-102, T-103, T-104, T-105, T-106, T... | 0.50 | approval | 2027-04-08 | 2027-04-08 |
| 177 | [T-071](tasks/T-071.md) | Admin page: Cities | admin | 2 | M7 | T-070 | 0.50 |  | 2027-04-08 | 2027-04-09 |
| 178 | [T-075](tasks/T-075.md) | Admin page: Pricing rules | admin | 2 | M7 | T-070, T-093, T-097 | 0.50 |  | 2027-04-09 | 2027-04-12 |
| 179 | [REL-M8b](tasks/REL-M8.md) | Release checkpoint: M8b Flutter launch build | flutter | 2 | REL | FL-111, FL-112, FL-113, FL-115, FL-116, FL-117, FL-118, F... | 0.50 | approval | 2027-04-12 | 2027-04-12 |
| 180 | [T-072](tasks/T-072.md) | Admin page: Genre and mood options | admin | 2 | M7 | T-070 | 0.50 |  | 2027-04-12 | 2027-04-12 |
| 181 | [T-073](tasks/T-073.md) | Admin page: Artists | admin | 2 | M7 | T-070 | 0.50 |  | 2027-04-12 | 2027-04-13 |
| 182 | [T-074](tasks/T-074.md) | Admin pages: Organizers and Collaboration requests | admin | 2 | M7 | T-070, T-053, T-083 | 0.50 |  | 2027-04-13 | 2027-04-14 |
| 183 | [T-076](tasks/T-076.md) | Admin page: Financials | admin | 2 | M7 | T-070, T-095 | 0.50 |  | 2027-04-14 | 2027-04-14 |
| 184 | [T-077](tasks/T-077.md) | Admin pages: Orders list and detail | admin | 2 | M7 | T-070, T-068, T-134 | 0.50 |  | 2027-04-14 | 2027-04-15 |
| 185 | [T-079](tasks/T-079.md) | Admin page: Refunds list | admin | 2 | M7 | T-070, T-068, T-134 | 0.50 |  | 2027-04-15 | 2027-04-16 |
| 186 | [T-100](tasks/T-100.md) | Admin page: fee preview calculator (sample orders per market) | admin | 2 | M7 | T-096, T-075 | 0.50 |  | 2027-04-16 | 2027-04-16 |
| 187 | [T-175](tasks/T-175.md) | Admin page: partner approvals queue | admin | 2 | M7 | T-070, T-083 | 0.50 |  | 2027-04-16 | 2027-04-19 |
| 188 | [T-177](tasks/T-177.md) | Admin page: club team accounts and suspension | admin | 2 | M7 | T-176, T-103 | 0.50 |  | 2027-04-19 | 2027-04-20 |
| 189 | [T-178](tasks/T-178.md) | Admin page: settlements, transfers, retries and statements | admin | 2 | M7 | T-070, T-132 | 0.50 |  | 2027-04-20 | 2027-04-20 |
| 190 | [T-179](tasks/T-179.md) | Admin page: refund oversight, partner debits, waiver and Charge to club | admin | 2 | M7 | T-070, T-142 | 0.50 |  | 2027-04-20 | 2027-04-21 |
| 191 | [T-180](tasks/T-180.md) | Admin page: booking chat review and intervention | admin | 2 | M7 | T-070, T-170 | 0.50 |  | 2027-04-21 | 2027-04-22 |
| 192 | [T-181](tasks/T-181.md) | Admin page: venue authorization review and disputes | admin | 2 | M7 | T-070, T-160 | 0.50 |  | 2027-04-22 | 2027-04-22 |
| 193 | [T-182](tasks/T-182.md) | Admin: destination areas and activation in the Cities page | admin | 2 | M7 | T-071, T-164 | 0.50 |  | 2027-04-22 | 2027-04-23 |
| 194 | [T-184](tasks/T-184.md) | Admin and owner screens for access and discount codes | admin | 2 | M7 | T-156, T-070 | 0.50 |  | 2027-04-23 | 2027-04-23 |
| 195 | [REL-M7](tasks/REL-M7.md) | Release checkpoint: M7 admin app | admin | 2 | REL | T-079, T-182, T-184, T-181, T-180, T-179, T-178, T-177, T... | 0.50 | approval | 2027-04-26 | 2027-04-26 |
| 196 | [T-185](tasks/T-185.md) | Owner acceptance run on the labelled test accounts, tracker evidence per ID | backend | 2 | REL-L | T-111 | 0.50 | BLOCKED: tester availability (item 05) | 2027-04-26 | 2027-04-27 |
| 197 | [T-186](tasks/T-186.md) | The five end-to-end demonstrations from the client answers (tables, split, passes, refunds, staff roles) | backend | 2 | REL-L | T-133, T-145, T-149, T-111 | 0.50 | BLOCKED: tester availability (item 05) | 2027-04-27 | 2027-04-27 |
| 198 | [REL-L](tasks/REL-L.md) | Launch readiness: acceptance run, five demonstrations, go-live checklist | backend | 2 | REL | FL-111, FL-112, FL-113, FL-115, FL-116, FL-117, FL-118, F... | 0.50 | approval | 2027-04-28 | 2027-04-28 |
| 199 | [FL-114](tasks/FL-114.md) | Flutter: remaining agreed languages already listed in the app (after launch languages) | flutter | 3 | M8c | FL-113, REL-L | 0.50 |  | 2027-05-03 | 2027-05-03 |

## 6. Blocked by the client

| Task | Title | Waiting for | Planned start (after it arrives) |
|---|---|---|---|
| FL-113 | Flutter: French and Spanish complete across app flows, language inventory reconciled | translations review | 2026-12-10 |
| FL-133 | Flutter: age rule on the event page and the 18+ warning before booking | adviser confirmation (Q31) | 2027-04-01 |
| FL-136 | Flutter owner: code management screen (discount and guest-list codes) | priority (Q19) | 2027-03-24 |
| T-083 | Admin endpoints: list, approve, reject partner applications, with notification | D12 (named approvers) | 2026-12-08 |
| T-085 | Run the stalled-checkout list on live data (read-only) and produce the per-event report | hosting or database access (item 04) | 2026-12-07 |
| T-086 | Per-event correction script for sold counts, run only after written approval for each event | client written OK per event | 2026-12-07 |
| T-097 | Display mode per market and category (itemized or included) in the preview response | inclusive-display markets (Q2) | 2027-01-05 |
| T-102 | Permission catalogue and resolver: page view/manage plus sensitive actions | default permission matrix (Q24) | 2026-12-22 |
| T-119 | Second online payment: balance confirmation, deadline, fee only on the amount paid in app | second-payment deadline (Q5) | 2027-03-11 |
| T-138 | Club exception refunds and documented partial goodwill refunds with admission kept | Italy goodwill treatment (adviser) | 2027-02-10 |
| T-140 | Partner cancellation: admission refund, commission reversal, Technical Fee refund flag per market | Technical Fee rule on partner cancellation (adviser) | 2027-02-01 |
| T-144 | Date or venue change: notices, 7-day refund window, immediate route for a last-minute change | last-minute threshold (Q11) | 2027-02-26 |
| T-156 | Access codes: purpose, event or list, expiry, use limit; guest-list code requests | priority (Q19) | 2027-03-24 |
| T-157 | Migration: venue authorization record, uploaded evidence, admin decision, public label | authorization form wording (item 07) | 2027-02-03 |
| T-159 | Admin review of venue authorizations with notices | D12 (named reviewers) | 2027-03-02 |
| T-160 | Venue dispute: suspend sales, tickets stay valid, decision in 2 working days, escalation for imminent events | working-day calendar (Q25) | 2027-03-24 |
| T-162 | Migration: destination areas (Cote d Azur) independent of the radius, town membership | town list or boundary (Q26) | 2027-02-15 |
| T-164 | Activate the eleven destinations and set time zones; first-party-on-its-way text key | activation confirmation per city (Q27) | 2027-03-26 |
| T-168 | Retention job: delete 30 days after booking closure, or after dispute closure | legal check of 30-day deletion (adviser) | 2027-03-29 |
| T-169 | Support link setting: the single Bookdia WhatsApp number and the suggested text | WhatsApp number (Q6) | 2027-04-02 |
| T-173 | Legal document versions per language in the admin module | final legal texts (item 08) | 2027-03-31 |
| T-174 | Event age rule field and the age warning text key; signup keeps 18+ (no code change to the minimum) | adviser written confirmation (Q31) | 2027-04-01 |
| T-185 | Owner acceptance run on the labelled test accounts, tracker evidence per ID | tester availability (item 05) | 2027-04-26 |
| T-186 | The five end-to-end demonstrations from the client answers (tables, split, passes, refunds, staff roles) | tester availability (item 05) | 2027-04-27 |

Client items behind these: hosting or database access (item 04; Stripe, Apple/Google and push are received), named administrators (item 12), authorization form wording (item 07), second-payment deadline, Cote d'Azur town list, destination activation, working-day calendar, legal check of the 30-day chat deletion, adviser confirmation on under-18, Technical Fee refund on partner cancellation, last-minute threshold, default permission matrix, access-code priority. All are in `client-clarifications-2026-11-24.md` and the checklist at its end.

## 7. New scope: estimate only, no tasks

| Item | Estimate (days) | Trigger for creating tasks |
|---|---|---|
| Italian fiscal ticketing (all day ranges in this table are our rough estimates, not facts) | 15 to 30 (partner) or 80 to 150+ (own system); rough estimate, to be confirmed with the provider | Client decision after `siae-decision-memo-2026-11-24.md`, then provider sandbox and quote |
| Market setup FR, MC, ES, US (incl. Nevada tax) | 15 to 25 | Client approval of scope and cost, adviser input per market |
| Legal terms drafting | 3 to 5 (publishing and versioning only) | Client approval; legal text from the client's adviser |
| Referral programme (soon after) | 10 to 15 | Priority confirmed, holiday calendar and fee rules received |
| Resale and waitlist (soon after) | 20 to 30 | Priority confirmed, detailed questions answered |
| Attendee messaging, Interested avatars (later) | 15 to 25 | Estimate on request |

Real Italian admission sales stay off until an approved route exists; development in test mode only. The under-18 rule stays at 18+ in code until the client's adviser confirms in writing.

## 8. Rules recorded from the product owner (2026-11-24)

1. Fees: a server-calculated total endpoint, the Flutter change to use it and the force-update gate ship together; `/service-charge` and old purchase responses keep working for old versions (ADR-012).
2. Staff and platform roles are in separate tables with an additive field; `AccountRole` gets no new values (ADR-008).
3. A pending partner never gets 401 or 403: HTTP 423 `PARTNER_APPROVAL_PENDING` plus an additive `partnerStatus` (ADR-010).
4. Access received from the client (product owner, 2026-11-24): Stripe yes, Apple and Google yes, push yes; hosting (DigitalOcean) still not stated (the later message left the field blank), so it is treated as not received and T-085 stays blocked. Received means we have access; what is still missing is reported by the spike tasks.
5. Admin scaffolding (T-070) no longer waits for REL-M6; each admin page waits only for its own backend task.
6. T-063, T-064, T-065, T-066 and T-078 are superseded by the refund-engine tasks (ADR-007, CR-22).
7. Statuses of T-001 to T-003 and HF-001 to HF-004 were verified by file comparison only; their tests are to be re-run in REL-HF.
8. The effort figures are estimates by task, not commitments to the client; Phase 2 dates depend on the client confirming the added scope (see `scope-and-timeline-2026-11-24.md`).

## 9. Option C: reduced launch (proposal, not the plan of record)

Plan of record stays option A until the client chooses in writing (client document, section 5A). Option C was scheduled with the same scheduler, team (1 backend+admin, 1 Flutter), 30% allowance and calendar as section 2; only the Phase 2 task set was reduced. Phase 1 is unchanged. Not re-run for option B beyond the earlier figures.

**Dates (option C):** stable build 2026-12-21; REL-M3 (fees, server total, gate) 2027-01-13; refunds basics REL-M6 2027-01-20; ready for final testing 2027-02-02 (last task T-186); REL-L ready 2027-02-05; launch candidate about 2027-02-09 (same 7-day owner-testing and store-review gap as option A). About 51 person-days including checkpoints (A: about 125). Critical path: still the single backend/admin lane (17 raw backend days plus 5 admin days in Phase 2); the release chain REL-HF to REL-M8a to REL-M3 sets the early dates. After launch the moved items need about 66 person-days; they follow in the milestone order of section 4 and finish about the same time as option A or a few weeks later, depending on launch support.

**In (Phase 2 tasks kept):**
- Fees (all of M3): T-022 to T-028, T-093 to T-099; Flutter FL-111, FL-112 (server total and removal of client calculation); update gate and checkpoint REL-M3 together.
- Refund basics (M6 subset): T-134, T-135, T-136, T-137, T-140, T-143, T-144, T-067, T-068; Flutter FL-122, FL-123; cross-account suite T-069 (reduced to owner and admin routes); REL-M6.
- Owner analytics and earnings: T-059 to T-062.
- Admin (REL-M7 reduced): T-070 to T-073, T-075 to T-077, T-079, T-100, T-175.
- Tiers and badge: T-152, T-153, FL-127; age rule: T-174, FL-133; purchase limit messages FL-129.
- Acceptance: T-185, T-186 (demonstrations reduced to tickets, fees, refunds and approval); REL-L.

**Out (moved to after launch):** table requests, quotes, card holds, deposits (M5 and T-090 to T-092 spikes, but T-025 stays for existing table checkout); roles (M9, T-101 to T-111, FL-121, T-176, T-177, T-183); settlement and payouts (M10, T-123 to T-133, FL-130, FL-134, T-178); chat (M13, FL-119, FL-120, T-180); per-day passes, scanner v2, codes (M11 except T-152, T-153; FL-124 to FL-126, FL-128, FL-136, T-184); venues and areas (M12, FL-131, FL-132, T-181, T-182); languages beyond today's and legal versions (M14 except T-174; FL-113, FL-114, T-172, T-173); organizer, collaboration, extras, quotes (M5 original: T-047 to T-058, T-074; FL-135); partner debits, waiver, goodwill refunds, who-may-refund matrix, reconciliation (T-138, T-139, T-141, T-142, T-145, T-179).

**Consequences to confirm with the client:** payouts stay on the existing Connect behaviour (data-model migration 16 is not applied); club cost recovery after partner cancellation is by invoice outside the system; unregistered-venue events are not offered until M12; organizer items from the first tracker are moved after launch (needs explicit agreement); only the existing owner and admin access exists at launch (no team roles); chat and the WhatsApp link are not available. The migration set for option C (at least 6, 17 and the one of the approval gate; 22 for purchase limits and age) must be re-derived from the kept tasks when option C is chosen; some migrations (for example 17 and 18, which share the per-ticket status) may need splitting. Dependency check by script (task files read for every kept task; kept set = Phase 1, the Phase 2 list above, checkpoints; allowed outside the set: done in main, superseded): exactly three kept tasks depend on moved tasks. Resolution for option C (task files stay at option A until C is chosen):
- T-069 depends on T-139, T-053, T-051, T-102, T-104 to T-108: in option C the suite covers owner and admin routes only; the organizer, team-role and permission cases come with their milestones after launch. No date effect.
- T-185 depends on T-111 (ten labelled role accounts): in option C a small seed of labelled accounts for customer, club owner and administrator is part of T-185, which grows from 0.5 to 0.75 raw days.
- T-186 depends on T-133, T-145, T-149, T-111: in option C the demonstrations are reduced to tickets with fees, refunds and approval, so those four dependencies drop.
After these changes the schedule was re-run: no date moves (REL-M3 2027-01-13, REL-M6 2027-01-20, final testing 2027-02-02, REL-L 2027-02-05, launch candidate about 2027-02-09); person-days 51.65. Every dependency in the re-run schedule is itself in the option C set.
