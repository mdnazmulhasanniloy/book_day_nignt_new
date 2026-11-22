# Change Requests

Source: `01-discovery/new update.md` (client tracker, 6 Nov 2026). Baseline: `04-architecture/*` (as-is) and `known-issues.md`.

Statuses were set by the product owner on 2026-11-21 (see Decision log). The CR grouping itself was drafted by Claude from the tracker. Contract docs are updated only for `Approved` CRs and the approved parts of `Partial` CRs.

- `BUG-xx` tags reuse the IDs in `04-architecture/known-issues.md` (for example `BUG-B24` = known issue B-24, `BUG-S03` = S-03).
- "Tracker IDs" are the client's IDs (P0.1, A2.4, Q1 ...). The Crosswalk section of the tracker is the grouping basis.
- "Blocked by" lists open decisions Q1 to Q6. The tracker says a proposal is not an approved configuration, so a blocked CR can only be approved for the unblocked part.
- Backend facts in "Baseline" come from reading the code on 2026-11-21; "Clients" is an assumption to be checked in the gap analysis.

## Summary

| CR | Title | Tracker IDs | Related BUG | Blocked by | Clients | Breaking risk | Status |
|---|---|---|---|---|---|---|---|
| CR-01 | Auth and test-access reliability | P0.1 to P0.4 | BUG-S03, S04, S19, B07, B08, B21 | D1 (owner gate only) | Flutter, Admin | Medium (role self-select closed) | Partial |
| CR-02 | Organizer role, collaboration, venues | C1 to C4, C6, A2.20 | BUG-S03 | Q3, Q4 | Flutter, Admin | Low (no enum change) | Partial |
| CR-03 | Ticket sections, presets, descriptions, pricing mode | A2.1, A2.5, A2.6, A2.7, A2.15, A2.16 | none | none | Flutter, Admin | Low | Approved |
| CR-04 | Tier inventory, auto progression, starting price, badges | A2.8 to A2.10, A2.17, T1 | BUG-B24 | Q5 | Flutter, Admin | **High** (stock-count exposure, tier persistence) | Partial |
| CR-05 | Multi-day passes, day capacity, entry scanning | A2.4, A2.11, T2, A1.3, A1.4 | BUG-B15, S21 | Q5 | Flutter, Admin | **High** (`verify-ticket`, per-order check-in) | Deferred |
| CR-06 | Free tickets, guest list, access codes | A2.2, A2.3 | BUG-S02, S09, B29 | Q5 | Flutter, Admin | Low | Partial |
| CR-07 | Tables, quotes, extras, Hosts workflow | A2.12 to A2.14, A2.18, A2.19 | BUG-S08, B19, B30 | Q1, Q6 | Flutter, Admin | Medium | Partial |
| CR-08 | Analytics (club and per event) | A1.1 to A1.8 | none | Q5 | Admin (Flutter owner screens, if any) | Low (new endpoints) | Partial |
| CR-09 | City selector, radius, chronological Explore | B1.1 to B1.4, B3.1, B3.2 | BUG-B02, B25, B28 | Q6 | Flutter | Low | Approved |
| CR-10 | Filters, vocabularies, map | B2.1 to B2.6 | BUG-B10 | Q6 | Flutter | Low | Approved |
| CR-11 | Interested, recently/most viewed | D3, B3.3 | BUG-B28 | Q6 | Flutter | Low | Approved |
| CR-12 | Artists discovery and follow | B3.4, B3.5 | none | Q6 | Flutter, Admin | Low | Approved |
| CR-13 | Public event page content | D1, D2, D4, D5, C3 | none | none | Flutter | Low | Approved |
| CR-14 | Customer tickets: future, pending, past | B1.5 | none | none | Flutter | Low | Approved |
| CR-15 | Technical fees and commissions | E2 to E5 | BUG-B20 | Q2 | Flutter, Admin | **High** (`/service-charge`, `/admin/commission`) | Partial |
| CR-16 | Checkout, refunds, payout reconciliation | E1, E6, C5 | BUG-B16, B19 | Q1, Q2, Q3 | Flutter, Admin | Medium | Partial |
| CR-17 | Timezones, errors, permissions (cross-cutting) | T3, T4, T5 | BUG-B15, B17, B18, B22, B26, B27, S17, S18 | none | Flutter, Admin | Medium (HTTP status changes 500 to 404/401) | Approved |

## Details

### CR-01 Auth and test-access reliability
- **Status:** Partial
- **Decision note:** ONLY: social sign-in date of birth (`profileComplete`), admin refresh returns 401 (BUG-B17), retry safety. DEFERRED until the client answers D1: the owner-approval gate (PENDING on signup, `OWNER_NOT_APPROVED`, admin approval endpoints, `ownerApprovalStatus`). Signup and owner endpoints behave as today; BUG-S03 stays open. Changed on 2026-11-21: this replaces the earlier decision "D1 = Option B".
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline (code):** signup requires `dateOfBirth`; OTP is 6 digits in Redis, 5 min expiry, 5 attempts, 60 s resend (email only). `POST /auth/social` creates a user with an empty profile, so no date of birth. `signup` accepts `role: CLUB_OWNER` from any client (BUG-S03). Flutter never calls `POST /auth/refresh` (BUG-B08) and a 401 does nothing (BUG-B07).
- **Proposed:** fix refresh and 401 handling contract; make social sign-up able to collect a missing date of birth; define server-side behaviour on retry (no duplicate account); close self-service `CLUB_OWNER` or gate it (needs owner decision, see CR-02); test accounts per role (P0.4 is process, no API change).
- **Needs owner decision:** does self-signup as club owner stay allowed?

### CR-02 Organizer role, collaboration, venues
- **Status:** Partial
- **Decision note:** ONLY: organizer identity (no new role value; organizer = CLUB_OWNER with an organizer profile), organizer profile and follow, collaboration request (organizer to club, accept/reject). NOT YET: unregistered-venue flow (Q4), payout split (Q3). Owner approval (D1) is deferred and not required by anything here.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `AccountRole` is `USER | ADMIN | CLUB_OWNER`; there is no organizer role (`auth.routes.ts:63` says organizers use `CLUB_OWNER`). Closest existing concepts: `Event.clubHostStatus`, `VipHost`, `HostContact`.
- **Proposed:** `ORGANIZER` role (or organizer profile on `CLUB_OWNER`; ADR needed), organizer profile (name, description, city, website, tags, social links, followers), collaboration request club-to-organizer (PENDING, ACCEPTED, REJECTED), manual unregistered venue with authorization record (text version, account, timestamp, review result), `Event.organizerId`.
- **Blocked by:** Q3 (payout split), Q4 (authorization evidence). Approve only the role, profile and collaboration request now.

### CR-03 Ticket sections, presets, descriptions, pricing mode
- **Status:** Approved
- **Decision note:** Full.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `EventTicketTier` already has `parentId` (self-relation), `groupName`, `tierName`, `description?`, `sortOrder`. Section vs tier semantics are not formal.
- **Proposed:** formalize section (parent) and tier (child); tier type `TICKET | PASS` with preset names plus custom; explicit `pricingMode` on `Event` (SINGLE, TIERED, FREE, MIXED); optional description everywhere.

### CR-04 Tier inventory, progression, starting price, badges
- **Status:** Partial
- **Decision note:** ONLY: stable tier ids on event update (BUG-B24 fix), tier stored on each purchase, stock released when a payment expires or fails. NOT YET: auto progression, starting price, availability badges, checkout hold rules (Q5).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `soldCount` is incremented at order creation, before payment (unknown whether it is decremented on cancel/expiry). `EventPurchase` has no `ticketTierId`: the tier is not persisted, only `pricePerPerson`. `PUT /event/:id` with `ticketTiers` deletes and recreates tiers, resetting `soldCount` (BUG-B24, High).
- **Proposed:** persist `ticketTierId` per purchase and per attendee; hold/release on payment expiry; stable tier IDs on update (upsert); server-computed `startingPrice`, `activeTierId`, `availability` badge (`ALMOST_SOLD_OUT | LAST_TICKETS | SOLD_OUT | null`); exact remaining counts hidden from public responses, kept for owner. Auto progression by `sortOrder` plus `startAt/endAt`.
- **Breaking:** removing public `soldCount` or capacity from existing responses breaks the "never remove fields" rule, so expose a v2 shape and keep v1.

### CR-05 Multi-day passes, day capacity, entry scanning
- **Status:** Deferred
- **Decision note:** Waiting on Q5. Old `POST /owner/verify-ticket` stays as is (only its error codes are fixed under CR-17).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `POST /owner/verify-ticket` takes `orderId`, sets one `Order.checkedInAt`, no day, tier or attendee check; one check-in per order, not per attendee. No event-day or session entity exists.
- **Proposed:** `EventDay` (session) entity, tier-to-day validity, per-attendee entitlement (credential) and `EntryScan` rows (who, when, day), per-day capacity, no-show derivation. New scan endpoint (v2); the old one stays working, deprecated.
- **Blocked by:** Q5 (capacity formula, re-entry rule, no-show finality).

### CR-06 Free tickets, guest list, access codes
- **Status:** Partial
- **Decision note:** ONLY: free tier checkout (price 0), role/ownership checks on promo management (BUG-S02), rate limit on promo validate (BUG-S09), duplicate guest-list join blocked (BUG-B29). NOT YET: guest-list access codes and pending-hold rule (Q5).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** zero-price tier is rejected; `EventGuestList` and entries exist (`PENDING..` statuses); promo create/update/delete lack role checks (BUG-S02); `POST /promo/validate` is public and unthrottled (BUG-S09); duplicate guest-list join not prevented (BUG-B29).
- **Proposed:** allow price 0 as an explicit free tier (instant confirm) vs guest-list request (approval); guest-list access code type on `PromoCode`; server-side limits; role checks on promo management.

### CR-07 Tables, quotes, extras, Hosts workflow
- **Status:** Partial
- **Decision note:** ONLY: fixed vs starting-from tables, authenticated quote submission (v2; v1 stays public but rate-limited), purchasable extras. NOT YET: quote-to-payment conversion (Q1), Hosts/Quotes role text (Q6).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `EventModule` (VIP table) with `startingPrice`, `deposit`, `minSpend`, `includedExtras[]`, `optionalExtras[]` (text only, not purchasable); `Quote` (`QuoteStatus`) is a public request; `POST /quotes` and `/hosts/:id/contact` are public (BUG-S08) and the contact is not linked to a user (BUG-B30).
- **Proposed:** fixed-price vs starting-from module (`pricingType`), quote lifecycle with `offeredPrice`, accept to booking, purchasable extras (`EventExtra` with price and stock, linked to a purchase), authenticated quote/contact.
- **Blocked by:** Q1 (payment approach), Q6 (Hosts and Quotes roles).

### CR-08 Analytics
- **Status:** Partial
- **Decision note:** ONLY: confirmed-bookings series, revenue, time filters, free/paid and category filters, per-event view. NOT YET: scans, no-shows, attendance rate (need CR-05 / Q5).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `GET /owner/dashboard`, `/owner/earnings`, `/owner/payments`; admin `/admin/dashboard`, `/admin/earnings`. No per-event, per-tier, per-day, scan, no-show or attendance-rate analytics. `/owner/earnings` omits `eventModulePurchase` in its where clause.
- **Proposed:** `GET /owner/analytics` (club) and `GET /owner/events/{id}/analytics` with `range`, `timezone`, `payType (ALL|FREE|PAID)`, `category (ALL|TICKETS|TABLES|EXTRAS)`; response separates orders, admissions, tables, extras and fees, commission, proceeds. Depends on CR-05 for scans and no-shows.

### CR-09 City selector, radius, chronological Explore
- **Status:** Approved
- **Decision note:** Full. Q6a answered 2026-11-22: radius steps 10, 20, 30, 40, 50 km, initially 30 km (the earlier default was 20 km). ; Flutter work is milestone M8. Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `/explore` has no radius param (fixed 20 km `ST_DWithin` when `lat` and `lng` are sent); `city` is `ILIKE` on a location string; no `City` entity; `sort=trending` ignored (BUG-B28); duplicated events miss `geog` (BUG-B25); `geog` filled only by specific raw SQL (BUG-B02).
- **Proposed:** `radiusKm` param (default 20 so current clients are unchanged), returned `distanceKm`, `City` lookup (`GET /cities`, search, launched flag), explore grouping (`group=day`: Today, Tomorrow, This Weekend, Upcoming), feed honours `city` and `radiusKm`, fix `geog` on duplicate and update.

### CR-10 Filters, vocabularies, map
- **Status:** Approved
- **Decision note:** Full. Q6b default: starter genre/mood lists editable by admin. Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `/explore/genres` exists; `mood` is a free CSV; no results-count endpoint; `categoryType` for events.
- **Proposed:** `GET /explore/filters?type=` (categories, genres, moods per type), `total` count in list meta, date range (`from`, `to`), map endpoint or `view=map` with same params, fix Flutter route kind (BUG-B10).

### CR-11 Interested, recently/most viewed
- **Status:** Approved
- **Decision note:** Full. Q6c default: trending = views + interested, 7 days; most viewed = 30 days. Q6d default: count only, no names. Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** only `Event.viewCount`, incremented on each detail read (not per user). No interested or recently-viewed concept.
- **Proposed:** `EventInterest (userId, eventId)` unique, `POST/DELETE /events/{id}/interested`, `interestedCount` on event responses; `EventView` per user for recently viewed; city-scoped most viewed; trending signal documented.
- **Blocked by:** Q6 (whether an interested-users list is visible, to whom).

### CR-12 Artists discovery and follow
- **Status:** Approved
- **Decision note:** Full. Q6e default: artist profiles maintained by club/organizer or admin; no artist logins. Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `Artist`, `ArtistFollower`, `EventLineup` and an `artists` module exist; backend support is probably present for follow. To be confirmed in gap analysis against the spec and the Flutter code.
- **Proposed:** artist list and profile with upcoming events, photo on lineup, follow state in responses, ownership rule (manager-maintained for now).

### CR-13 Public event page content
- **Status:** Approved
- **Decision note:** Full, limited to fields that do not depend on deferred CRs (no per-ticket valid days, no starting price). Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Proposed:** `organizer` and `club` identities, full address, start and end dates, per-ticket valid days, `mapUrl` or coordinates, mood tags, `startingPrice`, `availability` (from CR-04), `interestedCount` (CR-11). All additive.

### CR-14 Customer tickets: future, pending, past
- **Status:** Approved
- **Decision note:** Full. Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `bookings` module lists the user's bookings and tickets. Pending guest-list requests and in-flight payments are not distinguished.
- **Proposed:** `bucket=FUTURE|PENDING|PAST` filter plus status type (`CONFIRMED`, `GUEST_LIST_PENDING`, `PAYMENT_PROCESSING`); multi-day passes stay in FUTURE while valid.

### CR-15 Technical fees and commissions
- **Status:** Partial
- **Decision note:** ONLY: rule table with effective dates and precedence, v2 admin endpoints, separate fee/commission reporting. Rule VALUES wait for Q2. Old `/admin/commission` and `/service-charge` stay and are marked deprecated.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `ServiceCharge` is one global flat amount (`id="GLOBAL"`, not multiplied by person count); `ApplicationCharge` is one percentage per `Service` (CLUB, EVENT); order stores snapshots of all amounts. `GET /admin/commission` returns `{ EVENT, CLUB }` while `PATCH` returns `{ commission }` (BUG-B20).
- **Proposed:** `FeeRule` and `CommissionRule` (product category TICKET, TABLE, EXTRA; scope global, client, event; percent or fixed; `effectiveFrom`, `effectiveTo`, precedence), applied-rule reference stored on `Order`. Old endpoints keep working from the global rules and are deprecated.
- **Blocked by:** Q2 (policy matrix). Schema can be approved, rule values cannot.

### CR-16 Checkout, refunds, payout reconciliation
- **Status:** Partial
- **Decision note:** ONLY: refund request by owner, admin approval (full/partial), refund webhook handling, bad-signature 400 fix (BUG-B16). NOT YET: payout mode (Q3), table payment rules (Q1). Added 2026-11-21: admin order list and detail (`GET /admin/orders`, `GET /admin/orders/{orderId}`). One refund per order for now (kept on purpose). Per-attendee refunds are NOT built: open question Q8 (the tracker says "full/partial refunds" in E6 and V9 but never mentions a single attendee). Impact if Q8 = C: a refund state per ticket, ticket-level entry invalidation and stock return, a new table or column (see `data-model.md` 8.6.7), and `verify-ticket` changes. Until then a partial refund is a money amount, allowed once per order, and entry is invalidated only by a FULL refund.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** refunds are created only on formal event cancellation (full gross, service charge kept, executed by `processRefund` job); no user-initiated or partial refund endpoint; unverified whether refund webhooks are handled; Stripe signature errors return 500 (BUG-B16); module purchase has no idempotency body check (BUG-B19).
- **Proposed:** admin/owner refund request endpoint (full, partial), inventory release and entry invalidation on refund, refund webhook handling, payout-mode field (SPLIT or CLUB_ONLY) once Q3 is decided.
- **Blocked by:** Q1, Q2, Q3.

### CR-17 Timezones, errors, permissions
- **Status:** Approved
- **Decision note:** Full. Status-code corrections confirmed non-breaking for Flutter; `verify-ticket` errors use 404/409/422, never 401/403 (Flutter treats 403 like 401).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** owner earnings use CST boundaries; several handlers return 500 for not-found (BUG-B15, B17, B18, B26, B27); `GET /admin/users` leaks the password hash (BUG-S17, High); `validateReqBody` skips DELETE (BUG-S18).
- **Proposed:** event `timezone` field used for all day logic; standard error codes; fix S17 immediately. Status-code fixes are technically behaviour changes, so they are listed for explicit approval.

## Decisions the owner needs to make before approval

1. Q1 to Q6 in the tracker (CR-02, 04, 05, 06, 07, 11, 15, 16 depend on them).
2. Self-service `CLUB_OWNER` signup: keep, remove, or gate behind approval (CR-01, CR-02).
3. Whether BUG items should be approved as part of their CR or as a separate fix batch. Recommended: separate, with S-17, S-03, B-24 first.
4. Whether `500` to `404/401` status corrections (CR-17) count as breaking for Flutter.

## Client answers (2026-11-22)

Source: `01-discovery/client-answers-01.md`. Full review: `05-delivery/client-answers-review-2026-11-22.md`. **No CR status was changed**: statuses are the product owner's decision. The table shows what the answers settle and what the product owner may now want to re-evaluate.

| CR | Answers received | Still open | Product owner may now |
|---|---|---|---|
| CR-01 | D1: admin approval required before partner access; invitations verified | Confirm account stays a customer until approved; grandfathering of existing owners | Lift the deferral of the owner-approval gate |
| CR-02 | Q3 (automatic split, fallbacks), Q4 (venue authorization), D1 | Payout timing; form wording | Extend scope to unregistered venues and settlement after the Stripe spike |
| CR-04 | Q5 (capacity ceiling, holds, offline allocations) | Auto progression, starting price, badges not covered | Approve capacity and hold parts |
| CR-05 | Q5 (multi-day credential per day, one scan, no-show) | No-show timing for multi-day; entry-window time | Lift the deferral |
| CR-06 | Q5 (guest-list hold 24 h configurable) | Access codes not covered | Approve the hold rule |
| CR-07 | Q1 direction, Q6f | Stripe demonstration; messaging channel; quote duration | Approve table payments after the demonstration |
| CR-08 | Q5 (scans, no-shows) | Multi-day no-show timing | Approve scan and no-show analytics |
| CR-09 to CR-12 | Q6a to Q6e, C1 to C3 | Cote d'Azur coverage; activation per destination; optional avatar preview | Already approved; defaults updated (30 km) |
| CR-15 | Q2 structure (all products, zero by admin, venue scope, display mode) | **Values**; per-market validation | Approve structure with the ADR-003 amendments; values stay pending |
| CR-16 | Q1, Q2, Q3, Q8, Q9 | Venue-cancelled events; payout timing; admin role in refunds | Replace the refund scope (per-ticket, automatic in-time refunds, restore) |

## Decision log

| Date | Decision | By |
|---|---|---|
| 2026-11-21 | Approved: CR-01 (now Partial, see below), 03, 09, 10, 11, 12, 13, 14, 17. | Product owner |
| 2026-11-21 | Partial: CR-02, 04, 06, 07, 08, 15, 16 (only the parts named in each Decision note). | Product owner |
| 2026-11-21 | Deferred: CR-05 (waiting on Q5). Rejected: none. | Product owner |
| 2026-11-21 | D1 (club-owner self-signup) first recorded as Option B (admin approval). | Product owner |
| 2026-11-21 | D1 decision REVERSED: owner-approval gate deferred until the client answers D1. Removed from the spec and the data model. CR-01 is now Partial. BUG-S03 stays open. | Product owner |
| 2026-11-21 | Q1 to Q6 are still unanswered by the client. The Q6 defaults (6a to 6f) are used as working defaults; Q1 to Q5 values are not assumed. | Product owner |
| 2026-11-21 | Scope for now: backend + admin only. Flutter work starts later (milestone M8, not started). | Product owner |
| 2026-11-21 | Live Flutter app must keep working: additive changes in v1; breaking changes only in `/api/v2` with the v1 endpoint kept and marked deprecated. | Product owner |
| 2026-11-21 | Gap check covers Admin requirements only. | Product owner |
| 2026-11-21 | Recording note: these decisions were taken as Claude's recommended approval sheet, accepted by the product owner in chat, not typed in per CR. | Claude |
| 2026-11-22 | Client answers received in `01-discovery/client-answers-01.md` (review `05-delivery/client-answers-review-2026-11-22.md`). No CR status changed; recommendations are in the review. | Claude (documentation) |
