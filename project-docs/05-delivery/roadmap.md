# Development Roadmap

Prepared 2026-11-22 from the client tracker of 6 Nov 2026 (`01-discovery/new update.md`), the change requests (`02-product/change-requests.md`), `known-issues.md`, the task files in `tasks/` and the restored database baseline (`reports/baseline-2026-11-22.md`). This file is the single overview; the task files stay the unit of work. Where it disagrees with a task file, the task file is newer.

Labels: **Root cause** is "confirmed" only where the code was read; otherwise "UNVERIFIED" (reproduce first, per each task's step 1). Nothing marked "done" is verified in production.

## 1. Where we are (2026-11-22)

| Area | State |
|---|---|
| Client decisions Q1 to Q6, Q8, Q9, D1 | Sent to the client; **no answers yet**. Work that depends on them stays pending (section 3, group E) |
| Hotfix track HF-002, HF-003, HF-004 | Coded and unit-tested on branch `hotfix/security`; **staging check pending** |
| HF-001 (S-17 password hash) | Fix already in the baseline code; the 4 tests run green locally; **staging check pending** |
| T-001 restore and baseline | Done locally. Dump was 11 migrations behind, now up to date (25 migrations). Finding: 2 `PromoCode` rows break the "exactly one of eventId/clubId" rule |
| M1 (rest) to M7 | Not started |
| Flutter (M8) | Not started; now allowed to change. Independent Flutter fixes can start before M7 (section 5) |
| Production / staging | Nothing deployed; no access yet |

## 2. Priority order and dependencies

| Group | What | Start when |
|---|---|---|
| A. Critical / security | HF-001 to HF-004 (coded); **HF-005 S-01 unauthenticated `/media` upload and delete (coded, branch `hotfix/media-auth`)**; S-02 promo permissions (T-018); S-09 promo rate limit (T-019); B-24 tier reset on event update (T-004) | Now |
| B. High | M1: T-002, T-003, T-005 to T-014 (tier on purchase, stock release, social sign-in DOB, status codes); then M2 | After the HF staging check; T-002/T-003 can start now |
| C. Medium | M3 fees (code only; rule values wait for Q2), M4 discovery (defaults from Q6 are safe), M6 analytics (approved part) | After M1 |
| D. Low | M5 organizer profile and collaboration, M7 admin pages, hygiene items in section 4 | After M3/M4 |
| E. Client decision required | Table payment and quotes (Q1), fees and commission values (Q2), organizer payout split (Q3), unregistered venues (Q4), capacity, passes, scanning, no-show, badges, progression, access codes (Q5), partial refunds and stock release on refund (Q8, Q9), owner approval gate (D1), content lists C1 to C3 | Only after the written answer. Nothing is built on a guess |

Hard dependencies: T-001 then T-002 and T-003; T-003 before every test-bearing task; migration tasks need the T-002 rehearsal script; T-005 then T-006, T-007, T-008; T-015 before T-016/T-017; T-022 (migration 6 plus the v1 write-through, one task) before T-023 to T-028; M3 and M2 before M6; M3 to M6 before M7; admin pages need their endpoints.

## 3. Issue-by-issue roadmap (client tracker)

Columns: **Root cause / baseline** | **Apps**: B backend, A admin, F Flutter | **Fix** | **DB/API** | **Tasks** | **Priority** | **Status**. Acceptance for every row = the "Demonstrate" line of that ID in the tracker, plus the tests named in its task file, run on the delivery build and recorded with order/event ids. "Pending" = not started.

### P0 Access and test readiness

| ID | Root cause / baseline | Apps | Fix | DB/API | Tasks | Priority | Status |
|---|---|---|---|---|---|---|---|
| P0.1 Registration, DOB picker | Social sign-in creates a user with an empty profile, so no DOB (confirmed, CR-01). Date picker defect in the app UNVERIFIED | B, F | Backend: collect missing DOB and `profileComplete`, retry-safe. Flutter: fix picker and validation, keep entered data on error | API: additive fields (v1 compatible) | T-009; Flutter in M8-early | B (High) | Pending |
| P0.2 Google and Apple sign-in | Backend identity migration exists (`oauth_identity`). Failure cause UNVERIFIED: app logic, provider configuration or TestFlight environment | B, F | Reproduce per provider; check client IDs/authorized parties env (optional vars, not `getEnv`); fix; report which cause it was | none expected | T-009 (backend part); provider setup needs client accounts (C5) | High | Blocked on access |
| P0.3 OTP and session recovery | OTP expiry unit bug is already covered by `otpPolicy` tests. Remaining confirmed: reset works without OTP (S-19), blacklist key mismatch (S-04), Flutter never refreshes the token and ignores 401 (B-07, B-08), validation runs before token checks (B-21) | B, F | HF-003, HF-004 done in code; T-021 check order; Flutter: refresh and 401 handling | none | HF-003, HF-004, T-021; Flutter M8-early | Critical | Backend coded, staging pending |
| P0.4 Role test access | Process, not code. No test accounts supplied | B | Create accounts per role privately; cross-account access tests | none | T-069 (test), process step in REL checkpoints | High | Needs server access (promised later) |

### A1 Analytics (all backend plus admin; only the approved part is built before Q5)

| ID | Root cause / baseline | Fix | DB/API | Tasks | Status |
|---|---|---|---|---|---|
| A1.1 Booking chart | Only a revenue chart exists | Bookings over time, separate from revenue; count only confirmed | New owner analytics endpoint; indexes (migration 13) | T-059, T-061 | Pending (M6) |
| A1.2 Temporal filters | None | Today, Yesterday, Last Week, Month in the event/venue timezone | Timezone util | T-060, T-061 | Pending |
| A1.3 Scanned and used tickets | Only `Order.checkedInAt`; per-day scans not modelled | **Needs Q5.** Not built | Needs scan model | CR-05 deferred | Client decision |
| A1.4 No-shows | Not modelled | **Needs Q5** | - | CR-05 deferred | Client decision |
| A1.5, A1.6 Free/paid, tables/extras filters | Not visible | Filters on the analytics endpoints (free guest list needs Q5 for attendance) | additive | T-061, T-062 | Pending (revenue part) |
| A1.7 Per-event analytics | Dashboard is club-wide only | Event analytics endpoint with the same definitions | additive | T-062 | Pending |
| A1.8 Attendance rates, reconciliation | Depends on A1.3/A1.4 | Fees, refunds, commission shown separately once M3 lands | - | T-028 (financials); rates after Q5 | Partly client decision |

### A2 Tickets, passes, tables, extras

| ID | Root cause / baseline | Apps | Fix | Tasks | Status |
|---|---|---|---|---|---|
| A2.1 Multiple ticket types | Present; purchase end to end unverified | B, F, A | Verify through V2 scenario after M1/M2 | T-004, T-017 | Pending |
| A2.2 Free tickets / guest list | Zero-price tier rejected; guest-list management exists, free bookable list unclear | B, F | Free checkout after migration 6 allows fee 0; duplicate join blocked. Approval/instant-confirm modes and cutoffs: Q5 | T-020, T-026 | Part pending, rest Q5 |
| A2.3 Promo and guest-list codes | Any logged-in user can create/edit promos (S-02); validate has no rate limit (S-09). Access-code flow needs Q5 | B, F | Role and ownership checks; 404 for unknown target; rate limit | T-018, T-019 | Pending; codes Q5 |
| A2.4 Multi-day passes | Not modelled | all | **Q5; CR-05 deferred** | none | Client decision |
| A2.5, A2.6, A2.7 Sections, names, presets | Parent/child tiers exist (`parentId`, `groupName`); semantics not formal | B, F, A | `tierType` TICKET/PASS, presets endpoint, helper text | T-015, T-016, T-017 | Pending (M2) |
| A2.8 Price/quantity per tier | Present; **updating an event recreates tiers and resets `soldCount` (B-24, confirmed in CR-04)**; tier not stored on purchase | B | Stable tier ids on update; `ticketTierId` on purchase (migration 5) | T-004, T-005, T-006 | Pending (M1) |
| A2.9 Auto progression | Not built | B | **Q5** | none | Client decision |
| A2.10 Starting price | Event page shows "from", sticky button does not | B, F | Server-computed `startingPrice` (v2 shape; v1 unchanged) | part of CR-04, not approved yet | Client decision (Q5) |
| A2.11 Residual capacity | Not modelled | B | **Q5** | none | Client decision |
| A2.12 Fixed-price tables | VIP modules expose fields; purchase unverified | B, F | Payment approach per Q1 | T-056 (module purchase) | Q1 |
| A2.13 Starting-price tables, quotes | Quote-to-booking unclear; public quote route unthrottled (S-08) | B, F, A | Tracked quote flow v2 | T-058 | Q1 |
| A2.14 Extras | Descriptive text only | B, F, A | `EventExtra` with price, stock; purchase | T-054, T-057 | Pending (M5), commission per Q2 |
| A2.15 Descriptions | Module descriptions exist; optional for tickets | B | Optional description everywhere | T-017 | Pending |
| A2.16 Pricing mode | Event price and tiers coexist ambiguously | B, F, A | Explicit `pricingMode` (SINGLE, TIERED, FREE, MIXED) | T-015, T-017 | Pending |
| A2.17 Availability badges | Public stock counts shown | B, F | **Q5**; removing public counts breaks v1, so v2 only | none | Client decision |
| A2.18, A2.19 Modules, Hosts, Quotes | Screens exist, roles unclear; hosts contact not linked to the user (B-30, S-08) | B, F, A | Document purposes, fix actions | T-055, T-058 | Pending; roles per Q6f |
| A2.20 Club association | Message inconsistency between form and account state | F, B | Validation and messages | T-050 to T-053 (organizer) | Pending |

### B1 to B3 Discovery

| ID | Root cause / baseline | Fix | DB/API | Tasks | Status |
|---|---|---|---|---|---|
| B1.1 City selector | Events carry free-text locations; no city list | City table, seed from client list C3, selector in Flutter | migrations 3, 10; `/cities` | T-029 to T-033, T-071, F | Pending; seed waits for C3 |
| B1.2 Radius | `lat/lng` accepted and ignored; `geog` filled only on some paths (B-02, B-25, B-28) | Backfill `geog`, radius filter (steps from Q6a default) | migration 3 | T-029, T-030, T-034 | Pending (M4) |
| B1.3 Empty states | Not verified | Flutter states; API returns empty vs error | none | F | Pending |
| B1.4 Chronological Explore | Not grouped | Grouping by event-local date | additive | T-035, T-036 | Pending |
| B1.5 Future/Pending/Past | Reported in principle | Bookings buckets | additive | T-046 | Pending |
| B2.1 to B2.5 Filters, vocab, map chips | Mood free text; filters not mode-aware; route kind bug in Flutter (B-10) | Fixed genre/mood vocab (lists C1, C2), filter options endpoint, results count | migration 10 | T-031, T-032, T-037, T-038, T-072, F | Pending; seed waits for C1/C2 |
| B2.6 Recenter / distance | Distant-result report UNVERIFIED | Investigate with real data; Flutter recenter | none | T-034, F | Pending |
| B3.1, B3.2 City homepage, trending | Trending sort ignored (B-28) | Real ranking (Q6c default) | additive | T-034, T-041, T-042 | Pending |
| B3.3 Recently/most viewed | `viewCount` increments on every call (B-28) | View tracking, flush job | migration 11 | T-039 to T-042 | Pending |
| B3.4, B3.5 Artists, follow | Lineup names only | Artist profile fields, follow | migration 12 | T-043, T-044, T-073 | Pending; artist login not now (Q6e) |

### C Organizers, D Event page, E Checkout, T Technical

| ID | Root cause / baseline | Fix | Tasks | Status |
|---|---|---|---|---|
| C1, C2, C3 Organizer, collaboration, profile | No organizer concept; organizer = CLUB_OWNER with a profile (ADR-002) | Organizer profile and follow, collaboration request, "Organized by" | T-047 to T-053, T-074 | Pending (M5) |
| C4 Unregistered venues | Proof rule undecided | **Q4** | none | Client decision |
| C5 Payout modes | Provider arrangement undecided. Stripe Connect split can be created (confirmed by the product owner) | **Q3** decides modes and timing | none yet | Client decision |
| C6 Inquiry statuses | Request types share screens | Document and permission-check each type | T-055, T-058 | Pending |
| D1, D4 Event page content, location | Fields partly missing | Add organizer, address, Google Maps link fields | T-045, T-052, F | Pending |
| D2 Share and favorites | Behaviour untested; share-preview HTML escapes nothing (S-23, UNVERIFIED) | Test; escape output | none yet (see section 4) | Pending |
| D3 Interested counter | Not visible | Real user actions, no inflation; no names (Q6d default) | T-039, T-041 | Pending |
| D5 Ticket button | No starting price | With A2.10 | - | Client decision (Q5) |
| E1 Checkout | Login blocked testing; hold and failure rules | Verify per product after M1/M3 | T-007, T-008, T-026, REL smoke lists | Pending |
| E2 to E5 Fees and commissions | Flat fee and two percentages; cannot vary by product (B-20 superseded) | Pricing rules with effective dates, order keeps applied rule; v1 `PATCH` writes through | T-022 to T-028, T-070, T-075, T-076 | Code pending; **values need Q2** |
| E6 Refunds, notifications | Whole-order refund once; webhook 500 on bad signature | HF-002 done in code; refund requests, refund webhook handling | T-063 to T-068 | Pending; partial/stock rules need Q8, Q9 |
| T1 Inventory and concurrency | `soldCount` never released on failure or expiry (CR-04) | Release on failure and on a new expiry job | T-005 to T-008 | Pending (M1) |
| T2 Entry scanning | Not modelled; verify-ticket errors are 500s (B-15) | Status codes only now; scanning needs Q5 | T-011 | Part pending, rest Q5 |
| T3 Permissions, T4 timezone, T5 evidence | Cross-account tests missing; no event timezone | Cross-account tests, `timezone` field, REL smoke lists | T-069, T-015, T-017, T-060, REL-* | Pending |

## 4. Gaps: confirmed issues that have no task yet

Found while checking `known-issues.md` against the task list. None is fixed.

| ID | Issue | Proposal | Needs |
|---|---|---|---|
| **S-01** | `POST /media` and `DELETE /media` have no auth middleware (route read: confirmed). Anyone can upload to or delete from the storage bucket | **Add as HF-005 (Critical).** Both clients already send credentials (Flutter bearer token when stored, admin cookie), so requiring auth should be safe. Check signup avatar upload and the shared-link flows first | Approved 2026-11-22; implemented as HF-005 |
| S-06 | Dump files: not tracked by git now and not in history (checked); `.gitignore` covers `*.dump` and `dump.rdb` | Mark resolved in `known-issues.md` after the second check below | Nothing |
| S-20, S-23, S-07, S-08 | Public export file URL, unescaped share page, shared JWT secret, public quotes/contact | Verify each (all UNVERIFIED except S-07), then add small tasks | Reproduction |
| S-05, S-10 to S-13 | Flutter accepts any TLS certificate, stores tokens plainly, logs tokens, bundles `.env`, committed Firebase keys | Flutter hardening task group in M8-early (S-05 first) | Your go-ahead; release build impact |
| B-01, B-03, B-04, B-12, B-31, B-32 | Waiting-list unique key, missing trigger, `btree_gist`, scheduler lock, owner checks | Triage into M1/M5 after T-003 | Reproduction |
| P0.4 process, CR-17 T4 reschedule/cancel effects, T3 rename tests | Listed as flags in `implementation-plan.md` | Decision, then CR update | Product decision |
| New: 2 `PromoCode` rows with neither or both of eventId/clubId (from the T-001 baseline) | Rule assumed by T-018 does not hold in the data | Inspect the 2 rows before T-018 | Local data check |

## 5. Execution plan: milestones, outputs, tests, status

| Milestone | Tasks | Expected output | Tests required | Status |
|---|---|---|---|---|
| HF | HF-001 to HF-004, REL-HF, **HF-005 (proposed)** | Security hotfixes shipped | Unit tests (done), staging checks for each, smoke list | Coded, staging pending |
| M1 | T-001 to T-014, REL-M1 | Rehearsal script, test harness, stable tiers, stock release, status codes | Harness tests, migration rehearsal on the restored dump, each task's tests | T-001 done; rest pending |
| M2 | T-015 to T-021 | Sections, presets, pricing mode, promo fixes | Unit and DB tests, API tests, rehearsal | Pending |
| M3 | T-022 to T-028 | Pricing rules, free checkout, financials | Resolver tests, write-through tests, rehearsal, money reconciliation sample | Pending; Q2 for values |
| M4 | T-029 to T-046 | Discovery backend | Geo and grouping tests, backfill SQL checks | Pending; C1 to C3 for seed |
| M5 | T-047 to T-058 | Organizer, tables, quotes, extras | Permission tests, quote lifecycle tests | Pending; Q1, Q3, Q4 for parts |
| M6 | T-059 to T-069 | Analytics, refunds, orders, cross-account tests | Reconciliation against sample orders | Pending; Q8, Q9 |
| M7 | T-070 to T-079 | Admin pages for every new endpoint (adds Vitest) | Component tests, manual admin walkthrough | Pending |
| M8-early (proposed) | Flutter fixes that need no backend change: B-07 and B-08 (401 and refresh), S-05, B-10, DOB picker (P0.1), error/empty states | Stable login and session in the app | `flutter test`, `flutter analyze`, manual device run | Task files written (FL-B07, FL-B08, FL-P01); implementation blocked until a Flutter SDK is available on the dev machine |
| M8 | Flutter integration for every approved CR | Screens for new endpoints | Flutter tests plus V1 to V10 scenarios | Not started |

After every milestone: report done, remaining, next step; update the task Status line and the table in `tasks/README.md`.

## 6. Testing strategy

- Unit tests with `tsx --test` for helpers and services (harness from T-003 adds database-backed tests).
- API tests through the real route chain (auth, validation, status codes); every error fix proves the new status and `errorType`.
- Database validation: the T-002 rehearsal script on the restored dump (restore, migrate, CHECK-violation and backfill counts, stock-leak report) before any migration merges.
- Admin: Vitest component tests (T-070) plus a manual walkthrough of each changed page (loading, empty, error, success).
- Flutter: `flutter analyze`, `flutter test test/backend_update_test.dart` and a device run for each changed flow.
- End to end: the tracker scenarios V1 to V10 on a staging build with labelled test data, results linked to requirement ids.
- Regression: v1 responses never lose or rename fields; the full `npm test` and build run before each commit; REL smoke lists cover the old flows.

## 7. Tracking rules

- A task is `done` only when every "Done when" box is checked, including staging checks. Coded-and-unit-tested is written as "done in code (staging check pending)".
- `known-issues.md` entries are removed only after the fix is confirmed in production (a request there shows it).
- Contract docs (`api-spec.yaml`, `data-model.md`, `api-usage-map.md`) change in the same commit as the code that needs them.
- No assumption on an unanswered client question: the task is marked `blocked: Qn` and skipped.
- Branches: the hotfix track branches from `main` and ships first; the rest follows `client-update-v2` as the plan says. Production configuration, secrets and deploys need your explicit approval.
