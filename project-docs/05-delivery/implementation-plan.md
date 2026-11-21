# Implementation Plan

Scope: **backend first, then admin, then Flutter.** Flutter starts after both are done. Updated 2026-11-21.

Rules for every milestone:
- Backward compatible: the live Flutter app uses current endpoints. No removed or renamed response fields, no changed types. Breaking changes go to versioned endpoints (v2); v1 stays working and is marked deprecated. Per-operation answers are in `04-architecture/api-spec-diff-v2.md`.
- Update `api-spec.yaml`, `data-model.md`, `api-usage-map.md` before or with code. Migrations are forward-only and applied before the code that uses them (`data-model.md` section 9).
- Admin pages: loading, empty, error and success states for every changed page; backend calls only as in `api-spec.yaml`.
- Admin-only check (Flutter gap check skipped): every approved Admin requirement must have the endpoints it needs (see the coverage note below).

| # | Milestone | CRs | Stack | Status | Gate |
|---|---|---|---|---|---|
| M0 | Approvals (done 2026-11-21), contract docs (api-spec, changelog, diff, data model, ADRs: done), client answers Q1 to Q6, Q8, D1 (open) | all | docs | in progress | Product owner |
| M1 | **First task: migration test on a copy (see below).** Security and correctness: S-17 (password hash in `GET /admin/users`), B-24 and tier-on-purchase (migration 5), B-17 admin refresh 401, B-18, B-22, status-code fixes B-15, B-26, B-27, B-16 | CR-17, CR-01 (rest), CR-04 (part) | backend | not started | M0 |
| M2 | Ticket sections, presets, free tickets (opt-in), guest-list duplicate fix, promo role check (migration 4) | CR-03, 06 | backend | not started | M1, Q5 for the guest-list part |
| M3 | Fees and commissions: rules, v2 endpoints, v1 write-through (migration 6). Old `/admin/commission` and `/service-charge` kept | CR-15 | backend | not started | M1, Q2 for the values |
| M4 | Discovery backend: cities, radius, filters and map, interested and views, artists, event page fields, bookings buckets (migrations 3, 10, 11, 12) | CR-09 to CR-14 | backend | not started | M1, Q6 defaults |
| M5 | Organizer profile and collaboration, tables, quotes v2 and extras (migrations 8, 9) | CR-02, CR-07 | backend | not started | M1, Q1, Q3, Q4, Q6 for the deferred parts |
| M6 | Owner analytics, refund requests, admin orders, refund webhook handling (migrations 7, 13) | CR-08, CR-16 | backend | not started | M2, M3, Q8 |
| M7 | Admin app: pages for every new admin endpoint (cities, filter options, artists, organizers, collaboration requests, pricing rules and financials, orders, refund requests, refunds) | CR-02, 09, 10, 12, 15, 16 | admin | not started | M3 to M6 |
| M8 | **Flutter integration only** (all Flutter-side work for the approved CRs, `freeCheckout`, tier ids on event update, new discovery screens) | all | flutter | **not started** | M1 to M7 done |

CR-05 (multi-day passes, scanning) is deferred (Q5) and has no milestone. The CR-01 owner-approval gate is deferred (D1) and has no milestone. Milestone order is a proposal; the owner confirms it.

## Admin endpoint coverage (per approved CR, Admin only)
Existing admin surface: auth (login/check/refresh/logout), profile, change-password, commission, service-charge, dashboard, users (list/suspend/delete/restore), earnings, terms/privacy/about-us, `/admin/club`, `/admin/event`, `/recover/*`, `/media`. Unused by Admin today: `GET /admin/profile`, `PATCH /admin/users/{id}/restore`.
Covered by new endpoints in the spec: cities (CR-09), genre and mood vocabulary (CR-10), artists (CR-12), organizers and collaboration requests (CR-02), pricing rules and financials (CR-15), refund requests, refunds and orders (CR-16).
Still open: Gap 2, a pricing-rule preview endpoint, is deferred.

## M1, first task: migration test on a local copy
Production is never touched by this task. Steps:
1. Restore `backend/bookdianight.dump` into a new local PostgreSQL database (PostGIS enabled).
2. Run all approved migrations (2 to 13; 1 is deferred) on it, in order.
3. Before migration 6, run the "rows that violate the new CHECKs" queries (`Order` money CHECKs and the new `PricingRule` constraints, `data-model.md` 8.5 and migration 6). Expected 0 rows.
4. Run `05-delivery/reports/stock-leak.sql` and the migration 4 review query.
5. Report: restore time, each migration's run time, row counts per backfill, CHECK-violation counts, and anything unexpected. No fixes are applied automatically.
