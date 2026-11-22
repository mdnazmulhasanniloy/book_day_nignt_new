# Implementation Plan

Scope: **backend first, then admin, then Flutter.** Flutter starts after both are done. Updated 2026-11-21 (task files, hotfix track and release checkpoints rebuilt after the repo was re-created).

Rules for every milestone:
- Backward compatible: the live Flutter app uses current endpoints. No removed or renamed response fields, no changed types. Breaking changes go to versioned endpoints (v2); v1 stays working and is marked deprecated. Per-operation answers are in `04-architecture/api-spec-diff-v2.md`.
- Update `api-spec.yaml`, `data-model.md`, `api-usage-map.md` before or with code. Migrations are forward-only and applied before the code that uses them (`data-model.md` section 9).
- Admin pages: loading, empty, error and success states for every changed page; backend calls only as in `api-spec.yaml`.
- Admin-only check (Flutter gap check skipped): every approved Admin requirement must have the endpoints it needs (see the coverage note below).
- Every milestone ends with a release checkpoint (`05-delivery/tasks/REL-*.md`: review, staging deploy, smoke list, production deploy, rollback note). Every migration task passes the rehearsal script (T-002) on the restored dump.

| # | Milestone | CRs | Stack | Status | Gate | Tasks | Release |
|---|---|---|---|---|---|---|---|
| M0 | Approvals (done 2026-11-21), contract docs (done), client answers Q1 to Q6, Q8, Q9, D1 (open) | all | docs | in progress | Product owner | - | - |
| HF | **Hotfix track** (branch from `main`, ship before M1): S-17 verify, B-16, S-04, S-19 | CR-01, CR-16, CR-17 | backend | not started | none | HF-001 to HF-004 | REL-HF |
| M1 | Restore and rehearsal first (T-001, T-002), test harness (T-003), then B-24, tier on purchase (migration 5), stock release on failure and expiry, social sign-in DOB, status-code fixes (B-17, B-18, B-22, B-15, B-26, B-27, S-18) | CR-17, CR-01 (rest), CR-04 (part) | backend | not started | HF shipped | T-001 to T-014 | REL-M1 |
| M2 | Ticket sections, presets, timezone and pricing mode (migration 4), promo role check, promo rate limit, guest-list duplicate fix, auth cleanup (B-21, later) | CR-03, 06, 17, 01 (B-21) | backend | not started | M1; Q5 only for the deferred guest-list parts | T-015 to T-021 | REL-M2 |
| M3 | Fees and commissions: migration 6 with the v1 write-through, rule resolver, checkout integration, free tickets (moved here from M2, see Deviations), v2 pricing-rules and financials. Old `/admin/commission` and `/service-charge` kept and deprecated | CR-15, CR-06 (free tickets) | backend | not started | M1; Q2 for the values | T-022 to T-028 | REL-M3 |
| M4 | Discovery backend: migrations 3, 10, 11, 12; cities, radius, grouping, filters, map, interested, views, artists, event page fields, bookings buckets | CR-09 to CR-14 | backend | not started | M1; Q6 defaults; client content for the seed (T-032) | T-029 to T-046 | REL-M4 |
| M5 | Organizer profile and collaboration, tables, quotes v2 and extras (migrations 2, 9, 8) | CR-02, CR-07 | backend | not started | M1; Q1, Q3, Q4, Q6 only for the deferred parts | T-047 to T-058 | REL-M5 |
| M6 | Owner analytics, refund requests, admin orders, refund webhooks (migrations 13, 7) | CR-08, CR-16, CR-17 | backend | not started | M2, M3, Q8, Q9 (defaults B and no) | T-059 to T-069 | REL-M6 |
| M7 | Admin app: pages for every new admin endpoint (cities, filter options, artists, organizers, collaboration requests, pricing rules and financials, orders, refund requests, refunds) | CR-02, 09, 10, 12, 15, 16 | admin | not started | M3 to M6 | T-070 to T-079 | REL-M7 |
| M8 | **Flutter integration only** (all Flutter-side work for the approved CRs, `freeCheckout`, tier ids on event update, new discovery screens, B-07, B-08, B-10). No task files yet by decision; app path `flutter_app/` | all | flutter | **not started** | M1 to M7 done | none | not planned |

CR-05 (multi-day passes, scanning) is deferred (Q5) and has no milestone. The CR-01 owner-approval gate is deferred (D1) and has no milestone. Milestone order is a proposal; the owner confirms it.

## Milestone to task map

- **Hotfix track (branch from `main`, ship before M1):** HF-001, HF-002, HF-003, HF-004, REL-HF
- **M1 Security and correctness:** T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-011, T-012, T-013, T-014, REL-M1
- **M2 Ticket sections, presets, promo, guest list:** T-015, T-016, T-017, T-018, T-019, T-020, T-021, REL-M2
- **M3 Fees and commissions:** T-022, T-023, T-024, T-025, T-026, T-027, T-028, REL-M3
- **M4 Discovery backend:** T-029, T-030, T-031, T-032, T-033, T-034, T-035, T-036, T-037, T-038, T-039, T-040, T-041, T-042, T-043, T-044, T-045, T-046, REL-M4
- **M5 Organizer, tables, quotes, extras:** T-047, T-048, T-049, T-050, T-051, T-052, T-053, T-054, T-055, T-056, T-057, T-058, REL-M5
- **M6 Analytics, refunds, admin orders:** T-059, T-060, T-061, T-062, T-063, T-064, T-065, T-066, T-067, T-068, T-069, REL-M6
- **M7 Admin app:** T-070, T-071, T-072, T-073, T-074, T-075, T-076, T-077, T-078, T-079, REL-M7

Full table with titles, stack and dependencies: `05-delivery/tasks/README.md`.

## Migration to task map

| # | Migration | Task | Milestone |
|---|---|---|---|
| 1 | owner approval | deferred (D1) | - |
| 2 | notification types | T-047 | M5 |
| 3 | backfill geog | T-029 | M4 |
| 4 | timezone, pricing mode, tier type | T-015 | M2 |
| 5 | tier on purchase | T-005 | M1 |
| 6 | pricing rules + v1 write-through | T-022 | M3 |
| 7 | refund requests | T-063 | M6 |
| 8 | extras, module pricing, quote user | T-054 | M5 |
| 9 | organizers, collaboration | T-048 | M5 |
| 10 | cities, filter options | T-031 | M4 |
| 11 | engagement tracking | T-039 | M4 |
| 12 | artist profile fields | T-043 | M4 |
| 13 | analytics indexes | T-059 | M6 |

Order inside a milestone follows `data-model.md` section 9 (M5 applies migration 2 before 9 and 8). Migration 6 ships with the v1 write-through (T-022). Migration 13 uses `CREATE INDEX CONCURRENTLY` if `Order` is large (decision in T-059 from the T-001 row count).

## Traceability: CR to tasks to tests

Task ids are from `05-delivery/tasks/`. 'Tests' are the planned test files named in each task.

| CR | Title | Tasks | Tests |
|---|---|---|---|
| CR-01 | Auth and test-access reliability | HF-003, HF-004, T-009, T-010, T-021, T-069 | blacklist.keys.test.ts, recover.otpRequired.test.ts, auth.social.test.ts, admin.statusCodes.test.ts, auth.checkOrder.test.ts, crossAccount.test.ts |
| CR-02 | Organizer role, collaboration, venues | T-047, T-048, T-049, T-050, T-051, T-052, T-053, T-070, T-074 | notification.types.test.ts, collaboration_unique.sql, organizer.profile.test.ts, organizer.follow.test.ts, collaboration.test.ts, event.organizer.test.ts, admin.organizers.test.ts, DataState.test.tsx, Organizers.test.tsx |
| CR-03 | Ticket sections, presets, descriptions, pricing mode | T-015, T-016, T-017 | event_pricing_mode.sql, event.tierType.test.ts, ticketTierPresets.test.ts, event.pricingMode.test.ts, event.timezone.test.ts |
| CR-04 | Tier inventory (approved part) | T-001, T-002, T-004, T-005, T-006, T-007, T-008 | shellcheck, event.tierUpdate.test.ts, tier_on_purchase.sql, purchase.tierOnPurchase.test.ts, webhook.stockRelease.test.ts, expireEventTicketHold.job.test.ts, purchase.holdEnqueue.test.ts |
| CR-05 | Multi-day passes and scanning (deferred) | none (deferred) | - |
| CR-06 | Free tickets, guest list (approved part) | T-018, T-019, T-020, T-022, T-026 | promo.permissions.test.ts, rateLimit.test.ts, guestList.duplicate.test.ts, pricing_rules_checks.sql, admin.writeThrough.test.ts, purchase.freeCheckout.test.ts |
| CR-07 | Tables, quotes, extras | T-054, T-055, T-056, T-057, T-058 | extras_checks.sql, eventExtra.test.ts, purchase.module.test.ts, purchase.extras.test.ts, quotes.v2.test.ts, hosts.contact.test.ts |
| CR-08 | Analytics (approved part) | T-059, T-060, T-061, T-062 | order_indexes.sql, owner.earnings.test.ts, time.utils.test.ts, owner.analytics.test.ts, owner.eventAnalytics.test.ts |
| CR-09 | City selector, radius, chronological Explore | T-029, T-030, T-031, T-032, T-033, T-034, T-035, T-036, T-070, T-071 | geog_backfill.sql, event.geog.test.ts, club.geog.test.ts, filter_options_backfill.sql, seed-discovery.test.ts, city.test.ts, explore.radius.test.ts, explore.grouping.test.ts, explore.feed.test.ts, DataState.test.tsx, Cities.test.tsx |
| CR-10 | Filters, vocabularies, map | T-031, T-032, T-035, T-037, T-038, T-070, T-072 | filter_options_backfill.sql, seed-discovery.test.ts, explore.grouping.test.ts, explore.filters.test.ts, filterOption.admin.test.ts, explore.map.test.ts, DataState.test.tsx, FilterOptions.test.tsx |
| CR-11 | Interested, recently/most viewed | T-039, T-040, T-041, T-042, T-045 | engagement_constraints.sql, interest.test.ts, explore.viewTracking.test.ts, flushEventViews.job.test.ts, explore.trending.test.ts, explore.eventDetail.test.ts |
| CR-12 | Artists discovery and follow | T-043, T-044, T-070, T-073 | artists.profile.test.ts, admin.artists.test.ts, DataState.test.tsx, Artists.test.tsx |
| CR-13 | Public event page content | T-045, T-052 | explore.eventDetail.test.ts, event.organizer.test.ts |
| CR-14 | Customer tickets: future, pending, past | T-046 | bookings.bucket.test.ts |
| CR-15 | Technical fees and commissions (approved part) | T-002, T-022, T-023, T-024, T-025, T-026, T-027, T-028, T-057, T-070, T-075, T-076 | shellcheck, pricing_rules_checks.sql, admin.writeThrough.test.ts, pricing.resolver.test.ts, pricing.loader.test.ts, purchase.pricingRules.test.ts, purchase.pricingRules.module.test.ts, .club.test.ts, purchase.freeCheckout.test.ts, pricingRules.v2.test.ts, deprecation.headers.test.ts, financials.test.ts, purchase.extras.test.ts, DataState.test.tsx, PricingRules.test.tsx, Financials.test.tsx |
| CR-16 | Checkout, refunds (approved part) | HF-002, T-047, T-059, T-063, T-064, T-065, T-066, T-067, T-068, T-070, T-077, T-078, T-079 | webhook.signature.test.ts, connect.webhook.signature.test.ts, notification.types.test.ts, order_indexes.sql, refund_request_unique.sql, owner.refundType.test.ts, refundRequest.create.test.ts, refundRequest.admin.test.ts, webhook.refund.test.ts, admin.orders.test.ts, DataState.test.tsx, Orders.test.tsx, RefundRequests.test.tsx, Refunds.test.tsx |
| CR-17 | Timezones, errors, permissions | HF-001, T-003, T-010, T-011, T-012, T-013, T-014, T-015, T-017, T-018, T-060, T-064, T-069 | admin.helpers.test.ts, , admin.statusCodes.test.ts, owner.verifyTicket.test.ts, prismaError.test.ts, club.notFound.test.ts, event.notFound.test.ts, eventModule.delete.test.ts, wishlist.notFound.test.ts, validateReqBody.delete.test.ts, event_pricing_mode.sql, event.pricingMode.test.ts, event.timezone.test.ts, promo.permissions.test.ts, owner.earnings.test.ts, time.utils.test.ts, owner.refundType.test.ts, crossAccount.test.ts |

## Traceability: BUG to tasks to tests

| BUG | Used by | Tasks | Tests / note |
|---|---|---|---|
| BUG-B02 | CR-09 | T-004, T-029, T-030 | event.tierUpdate.test.ts, geog_backfill.sql, event.geog.test.ts, club.geog.test.ts |
| BUG-B07 | CR-01 | none | Flutter only: M8 (not started). |
| BUG-B08 | CR-01 | none | Flutter only: M8 (not started). |
| BUG-B10 | CR-10 | none | Flutter only (route kind in `club_community_section.dart`): M8 (not started). |
| BUG-B15 | CR-05, CR-17 | T-011 | (CR-05 also lists it) error codes only; scanning stays deferred. owner.verifyTicket.test.ts |
| BUG-B16 | CR-16 | HF-002, T-067 | webhook.signature.test.ts, connect.webhook.signature.test.ts, webhook.refund.test.ts |
| BUG-B17 | CR-17 | T-010 | admin.statusCodes.test.ts |
| BUG-B18 | CR-17 | T-010 | admin.statusCodes.test.ts |
| BUG-B19 | CR-07, CR-16 | T-056 | purchase.module.test.ts |
| BUG-B20 | CR-15 | none | Skipped: superseded by the v2 pricing rules (CR-15). |
| BUG-B21 | CR-01 | T-021 | auth.checkOrder.test.ts |
| BUG-B22 | CR-17 | T-010 | admin.statusCodes.test.ts |
| BUG-B24 | CR-04 | T-002, T-004, T-005, T-007 | shellcheck, event.tierUpdate.test.ts, tier_on_purchase.sql, webhook.stockRelease.test.ts |
| BUG-B25 | CR-09 | T-029, T-030 | geog_backfill.sql, event.geog.test.ts, club.geog.test.ts |
| BUG-B26 | CR-17 | T-012, T-013, T-018 | prismaError.test.ts, club.notFound.test.ts, event.notFound.test.ts, eventModule.delete.test.ts, wishlist.notFound.test.ts, promo.permissions.test.ts |
| BUG-B27 | CR-17 | T-013 | eventModule.delete.test.ts, wishlist.notFound.test.ts |
| BUG-B28 | CR-09, CR-11 | T-034, T-036, T-041, T-042, T-045 | explore.radius.test.ts, explore.feed.test.ts, explore.viewTracking.test.ts, flushEventViews.job.test.ts, explore.trending.test.ts, explore.eventDetail.test.ts |
| BUG-B29 | CR-06 | T-020 | guestList.duplicate.test.ts |
| BUG-B30 | CR-07 | T-054, T-058 | extras_checks.sql, quotes.v2.test.ts, hosts.contact.test.ts |
| BUG-S02 | CR-06 | T-018 | promo.permissions.test.ts |
| BUG-S03 | CR-01, CR-02 | none | Stays OPEN: self-signup as CLUB_OWNER is deferred with D1 (no task by decision). |
| BUG-S04 | CR-01 | HF-003 | blacklist.keys.test.ts |
| BUG-S08 | CR-07 | T-054, T-058 | extras_checks.sql, quotes.v2.test.ts, hosts.contact.test.ts |
| BUG-S09 | CR-06 | T-019 | rateLimit.test.ts |
| BUG-S17 | CR-17 | HF-001 | admin.helpers.test.ts |
| BUG-S18 | CR-17 | T-014 | validateReqBody.delete.test.ts |
| BUG-S19 | CR-01 | HF-004 | recover.otpRequired.test.ts |
| BUG-S21 | CR-05 | none | Belongs to CR-05, which is deferred (Q5): no task. |

Other BUG/S/B items that already have a home: S-17 = HF-001; S-04 = HF-003; S-19 = HF-004; B-16 = HF-002 (webhook refund events: T-067); B-19 = T-056 (not a separate task); B-20 skipped; B-21 = T-021 (later).

## Flags: approved requirements with no task

These are in scope by an approval (or an approved part) but have no task file. Each needs a decision or is covered outside this plan.

| # | Requirement | Why there is no task | Needed |
|---|---|---|---|
| 1 | CR-01 P0.4 test accounts and demo data per role (customer, owner, organizer, admin) | Process, not code; no API change | Someone on the team creates and shares them privately before each REL smoke run. Add to REL-HF if wanted |
| 2 | CR-01 P0.2 Google and Apple sign-in (provider configuration, TestFlight) and P0.1/P0.3 app-side fixes | Provider and app work; backend side is T-009 only | Flutter side is M8; provider configuration is an environment task for the client's accounts |
| 3 | CR-17 T4 reschedule, cancel and venue-change effects on sold tickets, notices and counters | The CR approves the timezone field and error codes only; no design exists for reschedule/venue change | Product decision, then a CR update |
| 4 | CR-17 T5 'recoverable error states' in the Flutter app | Flutter work | M8. Admin side is covered by T-070 (`DataState`) |
| 5 | CR-17 T3 'changing a display name does not break tickets or history' | Only tested for the organizer name (T-052); other entities are not covered | Add one rename test per entity when the owning task is built, or accept |
| 6 | CR-16 C5 payout reconciliation and E1 'customer total vs internal records' | Payout mode is not approved (Q3). The totals comparison is only partly covered by T-028 (financials) | Wait for Q3; E1 check is a manual step in REL-M3 |
| 7 | CR-09 to CR-14 Flutter integration | M8 is not started and has no task files | Write M8 tasks when M7 is done |
| 8 | CR-10 BUG-B10 (Flutter route kind) | Flutter only | M8 |
| 9 | CR-13 `organizer` field on the event page | Needs migration 9, so it is built in T-052 (M5), not T-045 (M4) | None; noted so M4 is not mistaken for complete |
| 10 | Content for the seed (genre/mood list, city list) | Client content, not engineering | See `blockers.md` 'Content we need from you'; T-032 is blocked until it arrives |

No approved requirement is silently dropped other than the rows above. CR-05 (deferred), the CR-01 owner gate (D1), CR-02 unregistered venues and payout split (Q3, Q4), CR-04 progression and badges (Q5), CR-06 access codes (Q5), CR-07 quote-to-payment (Q1), CR-15 rule values (Q2) and per-attendee refunds (Q8) are not approved and therefore not flagged.

## Deviations from the earlier plan (decisions to confirm)

1. **Free-ticket checkout moved from M2 to M3 (T-026).** A free order needs `Order.serviceChargeAmount >= 0`, which is changed by migration 6 (M3). Building it in M2 would force a non-zero fee on free orders.
2. **B-16 moved from M1 to the hotfix track (HF-002).** The M1 row of the earlier plan listed it; the hotfix ships it earlier.
3. **Timezone** (CR-17 T4) is split: the field in M2 (T-015, T-017), explore grouping in M4 (T-035), earnings and analytics in M6 (T-060).
4. **Status-code fixes** (B-15, B-17, B-18, B-22, B-26, B-27, S-18) are the tail of M1 (T-010 to T-014), as in the earlier M1 row.
5. **B-21** is placed in M2 as the last task (T-021) because it is marked 'later' and has no dependents; it can slip without effect.
6. **Admin tests:** the admin app has no test runner today; T-070 adds Vitest.

## Admin endpoint coverage (per approved CR, Admin only)
Existing admin surface: auth (login/check/refresh/logout), profile, change-password, commission, service-charge, dashboard, users (list/suspend/delete/restore), earnings, terms/privacy/about-us, `/admin/club`, `/admin/event`, `/recover/*`, `/media`. Unused by Admin today: `GET /admin/profile`, `PATCH /admin/users/{id}/restore`.
Covered by new endpoints in the spec and now by tasks: cities (CR-09: T-033, page T-071), genre and mood vocabulary (CR-10: T-037, T-072), artists (CR-12: T-044, T-073), organizers and collaboration requests (CR-02: T-053, T-074), pricing rules and financials (CR-15: T-027, T-028, pages T-075, T-076), refund requests, refunds and orders (CR-16: T-066, T-068, pages T-077 to T-079).
Still open: Gap 2, a pricing-rule preview endpoint, is deferred.

## First tasks of M1 (details in the task files)
T-001 restores `backend/bookdianight.dump` into a LOCAL database and runs read-only baseline queries; T-002 turns the rehearsal into one command (restore, `migrate deploy`, CHECK-violation queries, `stock-leak.sql`, migration 4 review query, summary); T-003 adds the backend test harness. Production is never touched by these tasks. Every later migration task must pass the T-002 script. Nothing is fixed automatically; the report lists anything unexpected.
