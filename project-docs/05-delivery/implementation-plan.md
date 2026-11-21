# Implementation Plan

Scope: **backend + admin only.** Flutter starts after both are done.

Rules for every milestone:
- Backward compatible: the live Flutter app uses current endpoints. No removed or renamed response fields, no changed types. Breaking changes go to versioned endpoints (v2); v1 stays working and is marked deprecated.
- Update `api-spec.yaml`, `data-model.md`, `api-usage-map.md` before/with code. Migrations are forward-only.
- Admin pages: loading, empty, error and success states for every changed page; backend calls only as in `api-spec.yaml`.
- Admin-only check (Flutter gap check skipped): every approved Admin requirement must have the endpoints it needs.

| # | Milestone | CRs | Stack | Status | Gate |
|---|---|---|---|---|---|
| M0 | Approve CRs (done 2026-11-21), answer Q1 to Q6 (open), contract docs (api-spec + changelog done; data-model and ADRs next) | all | docs | in progress | Product owner |
| M1 | Security and correctness fixes: S-17 (password hash in `GET /admin/users`), S-03, B-24 first | CR-17, CR-01 | backend, admin | not started | M0 |
| M2 | Auth reliability, admin refresh 401 (B-17), suspend 404 (B-18), page/limit NaN (B-22) | CR-01, CR-17 | backend, admin | not started | M0 |
| M3 | Ticket sections, tiers, free tickets, guest list, promo role checks | CR-03, 04, 06 | backend, admin | not started | M0, Q5 |
| M4 | Fees and commissions (old `/admin/commission`, `/service-charge` kept) | CR-15 | backend, admin | not started | M0, Q2 |
| M5 | Multi-day passes, scanning (v2 scan endpoint; `verify-ticket` kept) | CR-05 | backend, admin | not started | M3, Q5 |
| M6 | Analytics, refunds and payouts | CR-08, 16 | backend, admin | not started | M5, Q1-Q3 |
| M7 | Organizer role, tables/quotes/hosts, artists admin | CR-02, 07, 12 | backend, admin | not started | M0, Q3, Q4, Q6 |
| M8 | **Flutter handoff** (CR-09..14 and Flutter side of the rest) | CR-09 to 14 | flutter | not started | M1 to M7 done |

Milestone order is a proposal; the owner confirms it with M0.

## Admin endpoint coverage (coarse, from `api-usage-map.md`; per-CR check pending approval)
Existing admin surface: auth (login/check/refresh/logout), profile, change-password, commission, service-charge, dashboard, users (list/suspend/delete/restore), earnings, terms/privacy/about-us, `/admin/club`, `/admin/event`, `/recover/*`, `/media`. Unused by Admin today: `GET /admin/profile`, `PATCH /admin/users/{id}/restore`.
Likely gaps once approved: refund endpoint (CR-16), organizer/collaboration moderation (CR-02), fee/commission rules (CR-15), per-event analytics (CR-08), artist management (CR-12).
