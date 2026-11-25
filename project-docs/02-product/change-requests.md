# Change Requests

Source: `01-discovery/new update.md` (client tracker, 6 Nov 2026). Baseline: `04-architecture/*` (as-is) and `known-issues.md`.

Statuses were set by the product owner on 2026-11-21 (see Decision log). On 2026-11-24 the client answered the clarification document (`01-discovery/client-answers-02.md`); the status changes and CR-18 to CR-34 below were recorded by Claude from that source and need product owner confirmation (see Decision log). The CR grouping itself was drafted by Claude from the tracker. Contract docs are updated only for `Approved` CRs and the approved parts of `Partial` CRs.

- `BUG-xx` tags reuse the IDs in `04-architecture/known-issues.md` (for example `BUG-B24` = known issue B-24, `BUG-S03` = S-03).
- "Tracker IDs" are the client's IDs (P0.1, A2.4, Q1 ...). The Crosswalk section of the tracker is the grouping basis.
- "Blocked by" lists open decisions. Q1 to Q6 of the tracker are answered (`client-answers-01.md`); `Qn` in CR-18 onward means question n of `05-delivery/client-clarifications-2026-11-22.md`, answered in `client-answers-02.md`. The tracker says a proposal is not an approved configuration, so a blocked CR can only be approved for the unblocked part.
- Backend facts in "Baseline" come from reading the code on 2026-11-21; "Clients" is an assumption to be checked in the gap analysis.

## Terminology (client, 2026-11-24)

**Technical Fee** = the customer booking fee. **Service Fee** = the partner commission included in the base price. Earlier text in this file and in older docs used "service fee" for the customer fee and "commission" for the partner share; where that wording still appears, read it with the client's meaning. API and database names (`serviceChargeAmount`, `/service-charge`, `ApplicationCharge`) are not renamed because the live Flutter app uses them (ADR-003 amendment).

## Summary

| CR | Title | Tracker IDs | Related BUG | Blocked by | Clients | Breaking risk | Status |
|---|---|---|---|---|---|---|---|
| CR-01 | Auth and test-access reliability | P0.1 to P0.4 | BUG-S03, S04, S19, B07, B08, B21 | none (D1 answered) | Flutter, Admin | Medium (role self-select closed) | Partial (gate moved to CR-18) |
| CR-02 | Organizer role, collaboration, venues | C1 to C4, C6, A2.20 | BUG-S03 | none (Q3, Q4 answered; see CR-21, CR-23) | Flutter, Admin | Low (no enum change) | Partial |
| CR-03 | Ticket sections, presets, descriptions, pricing mode | A2.1, A2.5, A2.6, A2.7, A2.15, A2.16 | none | none | Flutter, Admin | Low | Approved |
| CR-04 | Tier inventory, auto progression, starting price, badges | A2.8 to A2.10, A2.17, T1 | BUG-B24 | none | Flutter, Admin | **High** (stock-count exposure, tier persistence) | Approved (client answers 2026-11-24) |
| CR-05 | Multi-day passes, day capacity, entry scanning | A2.4, A2.11, T2, A1.3, A1.4 | BUG-B15, S21 | none | Flutter, Admin | **High** (`verify-ticket`, per-order check-in) | Approved (deferral lifted 2026-11-24) |
| CR-06 | Free tickets, guest list, access codes | A2.2, A2.3 | BUG-S02, S09, B29 | priority of access codes | Flutter, Admin | Low | Approved (client answers 2026-11-24) |
| CR-07 | Tables, quotes, extras, Hosts workflow | A2.12 to A2.14, A2.18, A2.19 | BUG-S08, B19, B30 | Stripe test keys | Flutter, Admin | Medium | Approved (design in ADR-005; payment part waits for the Stripe spike) |
| CR-08 | Analytics (club and per event) | A1.1 to A1.8 | none | none | Admin (Flutter owner screens, if any) | Low (new endpoints) | Approved (scans and no-shows unblocked) |
| CR-09 | City selector, radius, chronological Explore | B1.1 to B1.4, B3.1, B3.2 | BUG-B02, B25, B28 | Q6 | Flutter | Low | Approved |
| CR-10 | Filters, vocabularies, map | B2.1 to B2.6 | BUG-B10 | Q6 | Flutter | Low | Approved |
| CR-11 | Interested, recently/most viewed | D3, B3.3 | BUG-B28 | Q6 | Flutter | Low | Approved |
| CR-12 | Artists discovery and follow | B3.4, B3.5 | none | Q6 | Flutter, Admin | Low | Approved |
| CR-13 | Public event page content | D1, D2, D4, D5, C3 | none | none | Flutter | Low | Approved |
| CR-14 | Customer tickets: future, pending, past | B1.5 | none | none | Flutter | Low | Approved |
| CR-15 | Technical fees and commissions | E2 to E5 | BUG-B20 | fixed fee per currency, inclusive-display markets | Flutter, Admin | **High** (`/service-charge`, `/admin/commission`) | Approved (values received 2026-11-24) |
| CR-16 | Checkout, refunds, payout reconciliation | E1, E6, C5 | BUG-B16, B19 | none | Flutter, Admin | Medium | Partial (refund parts superseded by CR-22 and CR-21) |
| CR-17 | Timezones, errors, permissions (cross-cutting) | T3, T4, T5 | BUG-B15, B17, B18, B22, B26, B27, S17, S18 | none | Flutter, Admin | Medium (HTTP status changes 500 to 404/401) | Approved |
| CR-18 | Partner approval gate and pending status | D1, Q22, Q23 | BUG-S03 | none | Flutter, Admin | Medium (pending status must not be 401/403) | Approved (client answers 2026-11-24) |
| CR-19 | Team roles and permissions (club and platform) | Q24, D1 matrix | none | default permission matrix | Flutter, Admin | Medium (additive session fields; AccountRole untouched) | Approved (client answers 2026-11-24) |
| CR-20 | Booking chat and support link | Q6 | none | WhatsApp number, 30-day retention legal check | Flutter, Admin | Low (new v2 endpoints) | Approved (client answers 2026-11-24) |
| CR-21 | Settlement: splits, payouts, ledger | Q7, Q8, Q9 | none | Stripe spike, Monaco eligibility | Flutter (owner), Admin | Low (new v2 endpoints, v1 earnings unchanged) | Approved (client answers 2026-11-24) |
| CR-22 | Refund engine v2: per ticket, club authority, partner cost recovery, restock | Q10, Q12 to Q15 | BUG-B16 | Technical Fee default on partner cancellation | Flutter, Admin | **High** (refund model, `verify-ticket` rule) | Approved (client answers 2026-11-24) |
| CR-23 | Event change, unregistered venues, venue dispute | Q11, Q25 | none | authorization form wording, last-minute threshold | Flutter, Admin | Low | Approved (client answers 2026-11-24) |
| CR-24 | Destination areas and activation | Q26, Q27 | none | Cote d Azur town list | Flutter, Admin | Low | Approved (client answers 2026-11-24) |
| CR-25 | Purchase limits | Q16 | none | none | Flutter | Low (new 4xx on abuse) | Approved (client answers 2026-11-24) |
| CR-26 | Server-calculated checkout total, display mode, app update gate | Q1, Q2 | BUG-B20 | Flutter release and store review | Flutter, Admin | **High** (live total, ADR-012) | Approved (client answers 2026-11-24) |
| CR-27 | Languages: English, Italian, French, Spanish | Q33 | none | translations, legal texts | Flutter, backend texts | Low | Approved (client answers 2026-11-24) |
| CR-28 | Age rules (event age rule; signup stays 18+) | Q31 | none | adviser written confirmation | Flutter | Low | Partial (display only; under-18 not implemented) |
| CR-29 | Italian fiscal ticketing (SIAE route) | Section 5, 7, 8 | none | client approval of scope and cost, route decision | Flutter, Admin | High (ticket credential rules) | Proposed - awaiting client scope and cost approval |
| CR-30 | Market configuration FR, MC, ES, US (incl. Nevada tax) | Section 9 | none | client approval, advisers | Flutter, Admin | Medium | Proposed - awaiting client scope and cost approval |
| CR-31 | Legal terms drafting (booking, refund, venue authorization, partner recovery) | Item 08 | none | client approval, legal adviser | none | none | Proposed - awaiting client scope and cost approval |
| CR-32 | Referral programme | Q34, item 09 | none | holiday calendars, fee waiver rules | Flutter, Admin | Low | Proposed - awaiting client scope and cost approval |
| CR-33 | Ticket resale and waitlist alerts | Q34 | none | separate estimate and terms | Flutter, Admin | Medium | Proposed - awaiting client scope and cost approval |
| CR-34 | Attendee messaging and avatar preview | Q34, answers-01 6d | none | later | Flutter | Low | Proposed - awaiting client scope and cost approval |

## Details

### CR-01 Auth and test-access reliability
- **Status:** Partial (owner gate moved to CR-18)
- **Decision note:** ONLY: social sign-in date of birth (`profileComplete`), admin refresh returns 401 (BUG-B17), retry safety. DEFERRED until the client answers D1: the owner-approval gate (PENDING on signup, `OWNER_NOT_APPROVED`, admin approval endpoints, `ownerApprovalStatus`). Signup and owner endpoints behave as today; BUG-S03 stays open. Changed on 2026-11-21: this replaces the earlier decision "D1 = Option B".
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline (code):** signup requires `dateOfBirth`; OTP is 6 digits in Redis, 5 min expiry, 5 attempts, 60 s resend (email only). `POST /auth/social` creates a user with an empty profile, so no date of birth. `signup` accepts `role: CLUB_OWNER` from any client (BUG-S03). Flutter never calls `POST /auth/refresh` (BUG-B08) and a 401 does nothing (BUG-B07).
- **Proposed:** fix refresh and 401 handling contract; make social sign-up able to collect a missing date of birth; define server-side behaviour on retry (no duplicate account); close self-service `CLUB_OWNER` or gate it (needs owner decision, see CR-02); test accounts per role (P0.4 is process, no API change).
- **Needs owner decision:** does self-signup as club owner stay allowed?
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** The owner-approval gate is no longer deferred: it is CR-18 (D1 answered, Q22, Q23, ADR-010). BUG-S03 stays open until CR-18 ships. Social sign-in date of birth stays as built; the signup minimum age stays 18 (CR-28, product owner decision 3).

### CR-02 Organizer role, collaboration, venues
- **Status:** Partial
- **Decision note:** ONLY: organizer identity (no new role value; organizer = CLUB_OWNER with an organizer profile), organizer profile and follow, collaboration request (organizer to club, accept/reject). NOT YET: unregistered-venue flow (Q4), payout split (Q3). Owner approval (D1) is deferred and not required by anything here.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `AccountRole` is `USER | ADMIN | CLUB_OWNER`; there is no organizer role (`auth.routes.ts:63` says organizers use `CLUB_OWNER`). Closest existing concepts: `Event.clubHostStatus`, `VipHost`, `HostContact`.
- **Proposed:** `ORGANIZER` role (or organizer profile on `CLUB_OWNER`; ADR needed), organizer profile (name, description, city, website, tags, social links, followers), collaboration request club-to-organizer (PENDING, ACCEPTED, REJECTED), manual unregistered venue with authorization record (text version, account, timestamp, review result), `Event.organizerId`.
- **Blocked by:** Q3 (payout split), Q4 (authorization evidence). Approve only the role, profile and collaboration request now.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q3 and Q4 answered: the payout split is CR-21 (ADR-006), unregistered venues and disputes are CR-23, team permissions are CR-19 (ADR-008). Organizer identity stays ADR-002 as amended. Organizer permissions for quotes, chat and refunds are OFF until the owner grants them.

### CR-03 Ticket sections, presets, descriptions, pricing mode
- **Status:** Approved
- **Decision note:** Full.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `EventTicketTier` already has `parentId` (self-relation), `groupName`, `tierName`, `description?`, `sortOrder`. Section vs tier semantics are not formal.
- **Proposed:** formalize section (parent) and tier (child); tier type `TICKET | PASS` with preset names plus custom; explicit `pricingMode` on `Event` (SINGLE, TIERED, FREE, MIXED); optional description everywhere.

### CR-04 Tier inventory, progression, starting price, badges
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** ONLY: stable tier ids on event update (BUG-B24 fix), tier stored on each purchase, stock released when a payment expires or fails. NOT YET: auto progression, starting price, availability badges, checkout hold rules (Q5).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `soldCount` is incremented at order creation, before payment (unknown whether it is decremented on cancel/expiry). `EventPurchase` has no `ticketTierId`: the tier is not persisted, only `pricePerPerson`. `PUT /event/:id` with `ticketTiers` deletes and recreates tiers, resetting `soldCount` (BUG-B24, High).
- **Proposed:** persist `ticketTierId` per purchase and per attendee; hold/release on payment expiry; stable tier IDs on update (upsert); server-computed `startingPrice`, `activeTierId`, `availability` badge (`ALMOST_SOLD_OUT | LAST_TICKETS | SOLD_OUT | null`); exact remaining counts hidden from public responses, kept for owner. Auto progression by `sortOrder` plus `startAt/endAt`.
- **Breaking:** removing public `soldCount` or capacity from existing responses breaks the "never remove fields" rule, so expose a v2 shape and keep v1.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q20: the next tier opens on sellout, the lowest available price is shown on cards, event page and button, 'Last tickets' shows at 20% or less of the tier, exact counts are hidden publicly (v2 shape; v1 `soldCount` kept). Q15 restock is CR-22. The 15-minute checkout hold is confirmed.

### CR-05 Multi-day passes, day capacity, entry scanning
- **Status:** Approved (deferral lifted 2026-11-24)
- **Decision note:** Waiting on Q5. Old `POST /owner/verify-ticket` stays as is (only its error codes are fixed under CR-17).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `POST /owner/verify-ticket` takes `orderId`, sets one `Order.checkedInAt`, no day, tier or attendee check; one check-in per order, not per attendee. No event-day or session entity exists.
- **Proposed:** `EventDay` (session) entity, tier-to-day validity, per-attendee entitlement (credential) and `EntryScan` rows (who, when, day), per-day capacity, no-show derivation. New scan endpoint (v2); the old one stays working, deprecated.
- **Blocked by:** Q5 (capacity formula, re-entry rule, no-show finality).
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q17, Q18, Q20, Q21: a no-show is recorded at each day's entry cutoff and the next covered day stays valid; the club sets the entry cutoff (default event end) and the guest-list approval hold (default 24 h, 1 to 72 h, capped by the cutoff); one place per included date; one valid admission per day; venue staff may reduce online inventory for offline sales. Design: ADR-013. The old `verify-ticket` stays (deprecated). Target dates are in the completion plan; the client answers (Q32) do not fix them.

### CR-06 Free tickets, guest list, access codes
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** ONLY: free tier checkout (price 0), role/ownership checks on promo management (BUG-S02), rate limit on promo validate (BUG-S09), duplicate guest-list join blocked (BUG-B29). NOT YET: guest-list access codes and pending-hold rule (Q5).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** zero-price tier is rejected; `EventGuestList` and entries exist (`PENDING..` statuses); promo create/update/delete lack role checks (BUG-S02); `POST /promo/validate` is public and unthrottled (BUG-S09); duplicate guest-list join not prevented (BUG-B29).
- **Proposed:** allow price 0 as an explicit free tier (instant confirm) vs guest-list request (approval); guest-list access code type on `PromoCode`; server-side limits; role checks on promo management.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q19: one code management screen (purpose discount or guest-list request, event or list, expiry, use limit; 1 use = single-use, 100 = shared). Guest-list codes submit a request and the ticket is issued after approval where required. Priority is not stated in Q34 (asked in the clarification document). Hold timeout per Q18 (see CR-05).

### CR-07 Tables, quotes, extras, Hosts workflow
- **Status:** Approved (payment part waits for the Stripe spike)
- **Decision note:** ONLY: fixed vs starting-from tables, authenticated quote submission (v2; v1 stays public but rate-limited), purchasable extras. NOT YET: quote-to-payment conversion (Q1), Hosts/Quotes role text (Q6).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `EventModule` (VIP table) with `startingPrice`, `deposit`, `minSpend`, `includedExtras[]`, `optionalExtras[]` (text only, not purchasable); `Quote` (`QuoteStatus`) is a public request; `POST /quotes` and `/hosts/:id/contact` are public (BUG-S08) and the contact is not linked to a user (BUG-B30).
- **Proposed:** fixed-price vs starting-from module (`pricingType`), quote lifecycle with `offeredPrice`, accept to booking, purchasable extras (`EventExtra` with price and stock, linked to a purchase), authenticated quote/contact.
- **Blocked by:** Q1 (payment approach), Q6 (Hosts and Quotes roles).
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q3 = A (card authorization, capture after venue approval, fresh payment if unsupported or expired), Q4 = A (48 h default, club-configurable, capped by the booking deadline, withdrawable), Q5 = C (club offers deposit online plus venue balance, full online, or two online payments), Q14 = C (policy per table). Design: ADR-005. Chat is CR-20. `QUOTE_REQUIRED` and the public `POST /quotes` stay for the live app.

### CR-08 Analytics
- **Status:** Approved (scans and no-shows unblocked)
- **Decision note:** ONLY: confirmed-bookings series, revenue, time filters, free/paid and category filters, per-event view. NOT YET: scans, no-shows, attendance rate (need CR-05 / Q5).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `GET /owner/dashboard`, `/owner/earnings`, `/owner/payments`; admin `/admin/dashboard`, `/admin/earnings`. No per-event, per-tier, per-day, scan, no-show or attendance-rate analytics. `/owner/earnings` omits `eventModulePurchase` in its where clause.
- **Proposed:** `GET /owner/analytics` (club) and `GET /owner/events/{id}/analytics` with `range`, `timezone`, `payType (ALL|FREE|PAID)`, `category (ALL|TICKETS|TABLES|EXTRAS)`; response separates orders, admissions, tables, extras and fees, commission, proceeds. Depends on CR-05 for scans and no-shows.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q17: scans, no-shows and attendance rate are unblocked; they depend on CR-05.

### CR-09 City selector, radius, chronological Explore
- **Status:** Approved
- **Decision note:** Full. Q6a answered 2026-11-22: radius steps 10, 20, 30, 40, 50 km, initially 30 km (the earlier default was 20 km). ; Flutter work is milestone M8. Backend implementation moved to the backend milestone M4 (before the admin work); Flutter integration is the last milestone (M8) and is not started.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `/explore` has no radius param (fixed 20 km `ST_DWithin` when `lat` and `lng` are sent); `city` is `ILIKE` on a location string; no `City` entity; `sort=trending` ignored (BUG-B28); duplicated events miss `geog` (BUG-B25); `geog` filled only by specific raw SQL (BUG-B02).
- **Proposed:** `radiusKm` param (default 20 so current clients are unchanged), returned `distanceKm`, `City` lookup (`GET /cities`, search, launched flag), explore grouping (`group=day`: Today, Tomorrow, This Weekend, Upcoming), feed honours `city` and `radiusKm`, fix `geog` on duplicate and update.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Radius initially 30 km (answers-01). Q26-Q27: the Cote d Azur is a destination area independent of the 50 km radius and all eleven destinations are enabled; this is CR-24 (ADR-011). Built T-031 to T-038 stay valid for ordinary cities.

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
- **Status:** Approved (values received 2026-11-24)
- **Decision note:** ONLY: rule table with effective dates and precedence, v2 admin endpoints, separate fee/commission reporting. Rule VALUES wait for Q2. Old `/admin/commission` and `/service-charge` stay and are marked deprecated.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** `ServiceCharge` is one global flat amount (`id="GLOBAL"`, not multiplied by person count); `ApplicationCharge` is one percentage per `Service` (CLUB, EVENT); order stores snapshots of all amounts. `GET /admin/commission` returns `{ EVENT, CLUB }` while `PATCH` returns `{ commission }` (BUG-B20).
- **Proposed:** `FeeRule` and `CommissionRule` (product category TICKET, TABLE, EXTRA; scope global, client, event; percent or fixed; `effectiveFrom`, `effectiveTo`, precedence), applied-rule reference stored on `Order`. Old endpoints keep working from the global rules and are deprecated.
- **Blocked by:** Q2 (policy matrix). Schema can be approved, rule values cannot.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Q1, Q2: Technical Fee 5% of the eligible paid subtotal plus EUR 0.50 (local equivalent) once per order; Service Fee 10% tickets and passes, 15% tables, sunbeds and extras; admin controls by country, category, club, event and table or quote; preview before saving; rates saved per sale. ADR-003 amended; migration 6 (T-022) is not written yet and must follow the amendment. The total shown to customers comes from CR-26. The 1.5% + EUR 0.26 figure was a test benchmark and is not used.

### CR-16 Checkout, refunds, payout reconciliation
- **Status:** Partial (refund parts superseded)
- **Decision note:** ONLY: refund request by owner, admin approval (full/partial), refund webhook handling, bad-signature 400 fix (BUG-B16). NOT YET: payout mode (Q3), table payment rules (Q1). Added 2026-11-21: admin order list and detail (`GET /admin/orders`, `GET /admin/orders/{orderId}`). One refund per order for now (kept on purpose). Per-attendee refunds are NOT built: open question Q8 (the tracker says "full/partial refunds" in E6 and V9 but never mentions a single attendee). Impact if Q8 = C: a refund state per ticket, ticket-level entry invalidation and stock return, a new table or column (see `data-model.md` 8.6.7), and `verify-ticket` changes. Until then a partial refund is a money amount, allowed once per order, and entry is invalidated only by a FULL refund.
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** refunds are created only on formal event cancellation (full gross, service charge kept, executed by `processRefund` job); no user-initiated or partial refund endpoint; unverified whether refund webhooks are handled; Stripe signature errors return 500 (BUG-B16); module purchase has no idempotency body check (BUG-B19).
- **Proposed:** admin/owner refund request endpoint (full, partial), inventory release and entry invalidation on refund, refund webhook handling, payout-mode field (SPLIT or CLUB_ONLY) once Q3 is decided.
- **Blocked by:** Q1, Q2, Q3.
- **Update 2026-11-24 (source: `01-discovery/client-answers-02.md`):** Refund authority, per-ticket cancellation, goodwill, partner recovery and restock are replaced by CR-22 (ADR-007); payouts and splits by CR-21 (ADR-006); table payment by CR-07 and ADR-005. T-063 to T-066 and T-078 are superseded; T-067 (webhooks) and T-068 (admin orders) stay.

### CR-17 Timezones, errors, permissions
- **Status:** Approved
- **Decision note:** Full. Status-code corrections confirmed non-breaking for Flutter; `verify-ticket` errors use 404/409/422, never 401/403 (Flutter treats 403 like 401).
- **Decided by:** Product owner
- **Date:** 2026-11-21
- **Baseline:** owner earnings use CST boundaries; several handlers return 500 for not-found (BUG-B15, B17, B18, B26, B27); `GET /admin/users` leaks the password hash (BUG-S17, High); `validateReqBody` skips DELETE (BUG-S18).
- **Proposed:** event `timezone` field used for all day logic; standard error codes; fix S17 immediately. Status-code fixes are technically behaviour changes, so they are listed for explicit approval.

### CR-18 Partner approval gate and pending status
- **Status:** Approved (client answers 2026-11-24; recorded by Claude, for product owner confirmation)
- **Decision note:** Lifts the CR-01 deferral. New club owners and organizers start PENDING and see only the club-area home; existing owners are backfilled APPROVED (Q23). The server answer for pending is HTTP 423 `PARTNER_APPROVAL_PENDING`, never 401 or 403 (product owner decision 7; ADR-010). Customer use needs a separate customer account.
- **Decided by:** Client (answers-02 Q22, Q23); product owner (status code)
- **Date:** 2026-11-24
- **Baseline:** `POST /auth/signup` accepts `role: CLUB_OWNER` (BUG-S03); the live Flutter app lets the user choose it; Flutter treats 401 and 403 as a dead session.
- **Proposed:** `PartnerApplication`, additive `partnerStatus` on auth responses, gate middleware with a club-area home allow-list, admin approve and reject endpoints, notifications; Flutter signup change and pending screen.
- **Blocked by:** named approvers (checklist item 12); how one person gets both account types (clarification document).

### CR-19 Team roles and permissions (club and platform)
- **Status:** Approved (client answers 2026-11-24; recorded by Claude, for product owner confirmation)
- **Decision note:** Club roles: Club Owner, General Manager (the former Primary Manager), Event Manager, Reservations Staff, Organizer (permissions off until granted). Platform roles: Platform Admin, Platform Manager, Country Manager (country or region only), Platform Staff. Page-level view/manage checkboxes plus sensitive actions, an editable permissions page, server-side and geographic enforcement. Staff and platform roles live in separate tables with additive fields; `AccountRole` is not changed (decision 6; ADR-008).
- **Decided by:** Client (Q24); product owner (storage)
- **Date:** 2026-11-24
- **Baseline:** `AccountRole` is `USER | ADMIN | CLUB_OWNER`; only the owner acts for a club; admin is one role.
- **Proposed:** migration 14, permission catalogue and resolver, team invite, owner endpoint enforcement, platform roles and country scope, admin permissions page, ten labelled test accounts.
- **Blocked by:** default permission matrix (clarification document).

### CR-20 Booking chat and support link
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** Booking-linked chat is primary; link to one Bookdia WhatsApp Business number for urgent tables or unanswered requests; diversion attempts flagged; chat deleted 30 days after booking closure (after dispute closure if a dispute was opened). ADR-009.
- **Decided by:** Client (Q6)
- **Date:** 2026-11-24
- **Baseline:** none (v1 quote and host contact only).
- **Proposed:** migration 21, chat endpoints, flagging, retention job, support link setting, admin review, push notifications.
- **Blocked by:** the WhatsApp number; legal check that 30-day deletion is acceptable; push account (item 03).

### CR-21 Settlement: splits, payouts, ledger
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** Admin sets the Bookdia share; the owner proposes the split; the organizer accepts before sales open (Q7 = A). Transfers start three calendar days after event end; shares show Pending then Confirmed; holds for open refunds or disputes; reversals; 3 retries in 3 days for transient failures (Q8, Q9). ADR-006.
- **Decided by:** Client (Q7, Q8, Q9)
- **Date:** 2026-11-24
- **Baseline:** `connect` module and webhook exist; no split, ledger or transfer scheduling.
- **Proposed:** migration 16, settlement setup, ledger, scheduler transfers, holds, retries, reversals, statements, demonstration pack.
- **Blocked by:** Stripe test keys with Connect and the spike (holding limits, Monaco eligibility).

### CR-22 Refund engine v2
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** Per-ticket cancellation, automatic refund inside the published cutoff, club decides exceptions, organizers only with owner permission, goodwill partial refund with admission kept, restock while sales are open, Technical Fee retained on customer-initiated cancellation, partner-funded Technical Fee refund with admin waiver and an admin-only "Charge to club" (Q10, Q12 to Q15). ADR-007. Supersedes the CR-16 refund parts.
- **Decided by:** Client (Q10, Q12, Q13, Q14, Q15)
- **Date:** 2026-11-24
- **Baseline:** one refund per order, event-cancel refunds only (service fee kept), `verify-ticket` rejects any refunded order.
- **Proposed:** migration 17, cancellation policy per event, single-ticket cancel, orchestration, exceptions, partner debit and recovery, waiver, restock, reconciliation.
- **Blocked by:** Technical Fee default on partner cancellation (terms and adviser); Italian goodwill treatment (CR-29).

### CR-23 Event change, unregistered venues, venue dispute
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** Date or venue change: notify at once, tickets stay valid, refund window 7 days from notice, immediate route for a last-minute change (Q11). Unregistered venues need the completed authorization form and admin approval before publication or sales; on dispute sales are suspended, sold tickets stay valid, admin decides within two working days (Q25).
- **Decided by:** Client (Q11, Q25)
- **Date:** 2026-11-24
- **Baseline:** no reschedule design (plan flag 3); no unregistered venue flow.
- **Proposed:** change notice endpoint and notices, migration 19, authorization submission and review, dispute suspension, public label "Presented by organizer at venue".
- **Blocked by:** authorization form wording (item 07); last-minute threshold; working-day calendar.

### CR-24 Destination areas and activation
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** The Cote d Azur runs from Saint-Tropez to Menton as a destination area independent of the 50 km radius; Monaco stays its own destination; all eleven destinations enabled; texts for cities with no club or no results (Q26, Q27). ADR-011.
- **Decided by:** Client (Q26 = B, Q27 = A)
- **Date:** 2026-11-24
- **Baseline:** `City` is a point; T-032 seeded the Cote d Azur as an inactive placeholder.
- **Proposed:** migration 20, area-aware explore and map, activation, empty-state texts.
- **Blocked by:** town list or boundary; activation confirmation per city.

### CR-25 Purchase limits
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** 5 tickets per order and 10 per customer per event, configurable per event; repeated cancellations flagged for review; a table booking is its own product (Q16).
- **Decided by:** Client (Q16 = A)
- **Date:** 2026-11-24
- **Baseline:** limit of 5 per order only.
- **Proposed:** per-event limit settings in migration 22, enforcement at checkout, flag for repeat cancellers.
- **Blocked by:** none.

### CR-26 Server-calculated checkout total, display mode and app update gate
- **Status:** Approved (client answers 2026-11-24; product owner decision 5)
- **Decision note:** The server calculates the payable total (`POST /v2/checkout/preview`); the Flutter app uses it; a force-update gate (`GET /v2/app/version-policy`); all released together; the old `/service-charge` keeps working for old builds (ADR-012).
- **Decided by:** Product owner (release rule); client (fee model, Q1, Q2)
- **Date:** 2026-11-24
- **Baseline:** the live app loads `/service-charge` and computes the total itself.
- **Proposed:** preview, display mode, version policy and enforcement switch, legacy path tests, Flutter change.
- **Blocked by:** Flutter release and store review; minimum build number.

### CR-27 Languages: English, Italian, French, Spanish
- **Status:** Approved (client answers 2026-11-24)
- **Decision note:** All four complete at launch across app flows and customer documents; the other previously agreed languages follow shortly after; the client wants a language inventory for reconciliation (Q33).
- **Decided by:** Client (Q33)
- **Date:** 2026-11-24
- **Baseline:** English and Italian labels in the client lists; inventory not yet done.
- **Proposed:** inventory, backend texts (emails, push, errors) in four languages, legal document versions, Flutter French and Spanish.
- **Blocked by:** translations review; final legal texts (item 08).

### CR-28 Age rules
- **Status:** Partial (display only)
- **Decision note:** The client answered that under-18 customers may sign in and buy, with the warning "Many events are 18+. Check the age requirement before you book. Continue?", and that the event age rule is shown before purchase (Q31). Product owner decision 3: the signup rule stays 18+ until the client's adviser confirms in writing. Only the event age rule field and the warning text key are built.
- **Decided by:** Product owner
- **Date:** 2026-11-24
- **Baseline:** `MIN_SIGNUP_AGE = 18`, social sign-in under 18 returns 422 (T-009), the live date picker enforces 18.
- **Proposed:** event age rule field (display), warning text; no change of the minimum.
- **Blocked by:** adviser written confirmation; age requirement for owners and organizers.

### CR-29 Italian fiscal ticketing (SIAE route)
- **Status:** Proposed - awaiting client scope and cost approval
- **Decision note:** No fiscal ticketing partner is selected. Options: integrate an approved partner, or build a Bookdia fiscal system. A decision memo with engineering days, calendar dependencies, external fees and responsibilities comes before paid work. Development may proceed in test mode only; real Italian admission sales only on an approved route. No tasks until the client approves scope and cost (decision 4).
- **Decided by:** Client asked for the memo (answers-02 Sections 5, 7, 8)
- **Date:** 2026-11-24
- **Baseline:** the QR comes from the booking id; no issuer integration.
- **Proposed:** see `05-delivery/siae-decision-memo-2026-11-24.md`.
- **Blocked by:** client decision on the route and cost; provider quote.

### CR-30 Market configuration FR, MC, ES, US
- **Status:** Proposed - awaiting client scope and cost approval
- **Decision note:** Separate configuration for France, Monaco, Spain and the US (including the upfront fee total and the Nevada Live Entertainment Tax), one worked sale, refund, scan and event report per market; a country flag alone does not authorize sales. No tasks until approved.
- **Decided by:** Client asked (answers-02 Section 9)
- **Date:** 2026-11-24
- **Baseline:** none.
- **Proposed:** estimate per market in the scope-and-timeline file.
- **Blocked by:** client approval; local advisers (item 13).

### CR-31 Legal terms drafting
- **Status:** Proposed - awaiting client scope and cost approval
- **Decision note:** The client asks us to prepare booking, cancellation and refund, and venue authorization terms for review, including partner recovery. Legal drafting needs a qualified adviser; we can supply a structured draft only. No tasks until approved.
- **Decided by:** Client asked (answers-02 item 08)
- **Date:** 2026-11-24
- **Baseline:** none.
- **Proposed:** estimate in the scope-and-timeline file.
- **Blocked by:** client approval; legal adviser.

### CR-32 Referral programme
- **Status:** Proposed - awaiting client scope and cost approval (priority: soon after launch)
- **Decision note:** Complete referral programme; needs holiday calendars per market and which fees a complimentary event waives (item 09). Detailed questions follow the priority choice.
- **Decided by:** Client (Q34 = Soon after)
- **Date:** 2026-11-24
- **Baseline:** none.
- **Proposed:** separate estimate before commissioning.
- **Blocked by:** item 09; estimate approval.

### CR-33 Ticket resale and waitlist alerts
- **Status:** Proposed - awaiting client scope and cost approval (priority: soon after launch)
- **Decision note:** Complete resale and waitlist flow; priced separately; resale and referral terms are due with those releases.
- **Decided by:** Client (Q34 = Soon after)
- **Date:** 2026-11-24
- **Baseline:** none.
- **Proposed:** separate estimate.
- **Blocked by:** estimate approval and terms.

### CR-34 Attendee messaging and avatar preview
- **Status:** Proposed - awaiting client scope and cost approval (priority: later)
- **Decision note:** Attendee messaging and the optional Interested avatar preview are later. The genuine Interested count is already built.
- **Decided by:** Client (Q34 = Later)
- **Date:** 2026-11-24
- **Baseline:** Interested count built (T-040).
- **Proposed:** none scheduled.
- **Blocked by:** later.

## Decisions the owner needs to make before approval

1. Q1 to Q6 in the tracker: answered (`client-answers-01.md`, `client-answers-02.md`); the open items are listed in `05-delivery/blockers.md`.
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
| 2026-11-24 | Recorded from `01-discovery/client-answers-02.md` (client answers to the 2026-11-22 clarifications, Q1 to Q34), for product owner confirmation: CR-04, 05, 06, 07, 08, 15 set to Approved; CR-01, 02, 16 stay Partial; CR-18 to CR-27 added as Approved; CR-28 Partial. | Claude |
| 2026-11-24 | CR-05 deferral LIFTED (Q17 to Q21 answered; ADR-013). D1 gate un-deferred as CR-18 (ADR-010). BUG-S03 gets a planned fix. | Claude (from client answers) |
| 2026-11-24 | Q22 rule recorded: pending owners and organizers see only the club-area home, partner tools locked and enforced on the server; customer use needs a separate customer account. The pending answer is HTTP 423 `PARTNER_APPROVAL_PENDING`, never 401 or 403. | Product owner (decision 7) |
| 2026-11-24 | Under-18 (Q31): the signup rule stays 18+ in code until the client's adviser confirms in writing; the answer is recorded and goes into the clarification document. CR-28 is display only. | Product owner (decision 3) |
| 2026-11-24 | Fees: server-calculated total endpoint, Flutter change and a force-update gate are released together; old `/service-charge` stays for old builds (CR-26, ADR-012). Terminology follows the client: Technical Fee (customer) and Service Fee (partner commission). | Product owner (decision 5) |
| 2026-11-24 | Roles: staff and platform roles live in separate tables with an additive field; no new `AccountRole` values (CR-19, ADR-008). | Product owner (decision 6) |
| 2026-11-24 | NEW SCOPE, Proposed - awaiting client scope and cost approval, no tasks until approved: CR-29 Italian fiscal ticketing, CR-30 market configuration FR/MC/ES/US, CR-31 legal terms drafting, CR-32 referral, CR-33 resale and waitlist, CR-34 attendee messaging. Scheduling a feature does not approve extra charges (client, Q34). | Product owner (decision 4) |
| 2026-11-24 | Access received per the product owner: Stripe yes, Apple/Google yes, push yes; hosting not yet stated (treated as not confirmed). Tasks that waited on Stripe and push are unblocked; the stalled-checkout run still waits for hosting or database access. | Product owner (decisions 1, 2) |
