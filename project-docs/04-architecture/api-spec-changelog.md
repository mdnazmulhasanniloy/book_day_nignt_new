# API spec changelog

## Changes in v2 (TO-BE, 2026-11-21)

Scope: Approved CRs and the approved parts of Partial CRs in `02-product/change-requests.md`. CR-05 is deferred. The CR-01 owner-approval gate is deferred until the client answers D1, so no endpoint, field or error code for it appears here. Per-operation detail with a "breaking for the live Flutter app?" answer for every changed v1 operation is in `api-spec-diff-v2.md`.

Compatibility rules used:
- **v1 is additive only.** New optional parameters and response fields, new endpoints. No field removed or renamed, no type changed.
- **Breaking changes go to `/api/v2`** and the v1 operation stays and is marked `deprecated` (ADR-001).
- **One exception:** `GET /admin/users` no longer returns the bcrypt `password` hash (BUG-S17). Only the Admin client calls it and it does not read that field.
- **Status-code corrections** (500 to 404/400/401/409/422) are not breaking for the live Flutter app: it shows the real message for any 4xx and a generic text for 5xx. `verify-ticket` uses 404/409/422, never 401/403.
- Every operation below has `x-requirement` and `x-status: planned` in `api-spec.yaml`; operations changed in place also carry `x-change`.

Totals: 47 added, 33 changed, 6 deprecated. The spec grows from 151 to 198 operations. 5 of the added operations are v2 (breaking-change route).

### Added

| Method | Path | Requirement | Compatibility | What |
|---|---|---|---|---|
| GET | `/ticket-tier-presets` | CR-03 | additive (new endpoint) | Preset tier names. **Implemented in T-016** (public, tested locally, not deployed): `data` has `ticketPresets`, `passPresets`, `presets[{name,tierType,sortOrder}]`, `sectionHelp`, `tierHelp` |
| POST | `/v2/quotes` | CR-07, BUG-S08 | v2 (new) | Create a quote request (authenticated) |
| POST | `/event/{eventId}/extras` | CR-07 | additive (new endpoint) | Create an extra |
| GET | `/event/{eventId}/extras` | CR-07 | additive (new endpoint) | List extras of an event |
| PUT | `/event/{eventId}/extras/{id}` | CR-07 | additive (new endpoint) | Update an extra |
| DELETE | `/event/{eventId}/extras/{id}` | CR-07 | additive (new endpoint) | Delete or deactivate an extra |
| GET | `/owner/analytics` | CR-08 | additive (new endpoint) | Club overview analytics |
| GET | `/owner/events/{eventId}/analytics` | CR-08 | additive (new endpoint) | Per-event analytics |
| GET | `/cities` | CR-09 | additive (new endpoint) | Search cities |
| GET | `/admin/cities` | CR-09 | additive (new endpoint) | List cities (admin) |
| POST | `/admin/cities` | CR-09 | additive (new endpoint) | Create a city |
| PATCH | `/admin/cities/{id}` | CR-09 | additive (new endpoint) | Update a city (launch / unlaunch) |
| GET | `/explore/filters` | CR-10 | additive (new endpoint) | Filter vocabulary for a type |
| GET | `/explore/map` | CR-10 | additive (new endpoint) | Map pins with the same filters as /explore |
| GET | `/admin/filter-options` | CR-10 | additive (new endpoint) | List genre and mood vocabulary |
| POST | `/admin/filter-options` | CR-10 | additive (new endpoint) | Add a genre or mood |
| PATCH | `/admin/filter-options/{id}` | CR-10 | additive (new endpoint) | Edit or deactivate a genre or mood |
| POST | `/events/{eventId}/interested` | CR-11 | additive (new endpoint) | Mark Interested |
| DELETE | `/events/{eventId}/interested` | CR-11 | additive (new endpoint) | Remove Interested |
| GET | `/me/recently-viewed` | CR-11 | additive (new endpoint) | My recently viewed events |
| GET | `/explore/most-viewed` | CR-11 | additive (new endpoint) | Most viewed events in a city |
| GET | `/artists` | CR-12 | additive (new endpoint) | Discover artists |
| GET | `/artists/{id}` | CR-12 | additive (new endpoint) | Artist profile |
| PATCH | `/artists/{id}` | CR-12 | additive (new endpoint) | Edit an artist profile (owner) |
| GET | `/admin/artists` | CR-12 | additive (new endpoint) | List artists (admin) |
| PATCH | `/admin/artists/{id}` | CR-12 | additive (new endpoint) | Edit or verify an artist (admin) |
| POST | `/organizer/profile` | CR-02 | additive (new endpoint) | Create my organizer profile |
| PUT | `/organizer/profile` | CR-02 | additive (new endpoint) | Update my organizer profile |
| GET | `/organizers/{id}` | CR-02 | additive (new endpoint) | Public organizer profile |
| POST | `/organizers/{id}/follow` | CR-02 | additive (new endpoint) | Follow an organizer |
| DELETE | `/organizers/{id}/follow` | CR-02 | additive (new endpoint) | Unfollow an organizer |
| POST | `/collaboration-requests` | CR-02 | additive (new endpoint) | Ask a club to host an event |
| GET | `/collaboration-requests` | CR-02 | additive (new endpoint) | List my collaboration requests |
| PATCH | `/collaboration-requests/{id}` | CR-02 | additive (new endpoint) | Accept, reject or cancel |
| GET | `/admin/organizers` | CR-02 | additive (new endpoint) | List organizer profiles (admin) |
| PATCH | `/admin/organizers/{id}` | CR-02 | additive (new endpoint) | Verify or suspend an organizer (admin) |
| GET | `/admin/collaboration-requests` | CR-02 | additive (new endpoint) | List collaboration requests (admin, read only) |
| GET | `/v2/admin/pricing-rules` | CR-15 | v2 (new) | List fee and commission rules |
| POST | `/v2/admin/pricing-rules` | CR-15 | v2 (new) | Create a rule |
| PATCH | `/v2/admin/pricing-rules/{id}` | CR-15 | v2 (new) | End-date or edit a future rule |
| GET | `/v2/admin/financials` | CR-15 | v2 (new) | Fees vs commission vs proceeds report |
| POST | `/owner/orders/{orderId}/refund-requests` | CR-16 | additive (new endpoint) | Request a refund (owner) |
| GET | `/admin/orders` | CR-16 | additive (new endpoint) | List orders (admin, read only) |
| GET | `/admin/orders/{orderId}` | CR-16 | additive (new endpoint) | Order detail (admin, read only) |
| GET | `/admin/refund-requests` | CR-16 | additive (new endpoint) | List refund requests |
| PATCH | `/admin/refund-requests/{id}` | CR-16 | additive (new endpoint) | Approve or reject a refund request |
| GET | `/admin/refunds` | CR-16 | additive (new endpoint) | List refunds |

### Changed (existing operations, v1 stays compatible)

| Method | Path | Requirement | Compatibility | What changes |
|---|---|---|---|---|
| POST | `/auth/social` | CR-01 | additive | Request accepts optional `dateOfBirth`. Response `data` gains `profileComplete` (boolean; false while date of birth is missing) so clients can ask for it before purchase. Retried calls with the same provider subject never create ... |
| POST | `/admin/auth/refresh` | CR-01, CR-17, BUG-B17 | additive | Invalid or expired refresh token returns 401 (errorType TOKEN_INVALID / TOKEN_EXPIRED) instead of 500. Admin client already logs out on any refresh failure, so no client change is needed. Implemented in T-010 (tested locally). |
| GET | `/admin/users` | CR-17, BUG-B22, BUG-S17 | security exception | Response no longer contains `password` (bcrypt hash leak). This is the only field removal in this release, accepted as a security fix; only the Admin client calls this endpoint and it does not read the field. page/limit that are ... |
| GET | `/admin/earnings` | CR-17, BUG-B22 | additive | page/limit that are not positive integers return 422 (was NaN behaviour). Implemented in T-010 (tested locally): limit is also capped at 100. |
| PATCH | `/admin/users/{id}/suspend` | CR-17, BUG-B18 | additive | Unknown user id returns 404 (was 500). Implemented in T-010 (tested locally). |
| GET, PUT | `/club/{id}` | CR-17, BUG-B26 | additive | Missing id or another owner's club returns 404 `{success:false, message:"Club not found", errorType:"NOT_FOUND", traceId}` (same body for both) instead of 500. Implemented in T-012 (tested locally, not deployed). |
| GET, PUT | `/event/{id}` | CR-17, BUG-B26 | additive | Missing id or another owner's event returns 404 `{success:false, message:"Event not found", errorType:"NOT_FOUND", traceId}` instead of 500 (GET) or 403 "Forbidden" (PUT, foreign event; the live app treats 403 like 401). Success paths unchanged. Implemented in T-012 (tested locally, not deployed). |
| DELETE | `/event/{eventId}/modules/{id}` | CR-17, BUG-B26 | additive | A module that has purchases returns 409 `{success:false, message:"Module has purchases and cannot be deleted; deactivate it instead", errorType:"FOREIGN_KEY_CONFLICT", traceId}` instead of 500; the module is kept. Implemented in T-013 (tested locally, not deployed). |
| POST | `/wishlist` | CR-17, BUG-B27 | additive | Missing or unavailable club or event returns 404 `{success:false, message:"Club not found or unavailable" / "Event not found or unavailable", errorType:"NOT_FOUND", traceId}` instead of 500 (service threw `status` instead of `statusCode`). Implemented in T-013 (tested locally, not deployed). |
| POST | `/owner/verify-ticket` | CR-17, BUG-B15 | additive | Business failures return real statuses with errorType instead of 500: not found OR not your order -> 404 (existence of other sellers' orders is not revealed); not PAID or refunded -> 422 TICKET_NOT_VALID; already used -> 409 ... Implemented in T-011 (tested locally, not deployed): the 404 carries errorType TICKET_NOT_FOUND and the 409 body carries usedAt (additive); human messages unchanged. |
| GET | `/club/{id}` | CR-17, BUG-B26 | additive | Club not found or not owned returns 404 (was 500 from unmapped Prisma P2025). |
| PUT | `/club/{id}` | CR-17, BUG-B26 | additive | Club not found or not owned returns 404 (was 500 from unmapped Prisma P2025). |
| GET | `/event/{id}` | CR-17, BUG-B26 | additive | Event not found or not owned returns 404 (was 500 from unmapped Prisma P2025). |
| DELETE | `/event/{eventId}/modules/{id}` | CR-17, BUG-B26 | additive | Module referenced by purchases returns 409 (was 500, FK Restrict). |
| POST | `/wishlist` | CR-17, BUG-B27 | additive | Target not found returns 404 (service threw the wrong error shape and returned 500). |
| POST | `/promo` | CR-06, CR-17, BUG-B26, BUG-S02 | behaviour (role check added; owner app unaffected) | Unknown eventId/clubId returns 404 (was 500, FK violation). Requires accountRole CLUB_OWNER (403 otherwise). Checked against flutter_app: only the club-owner Promo tab calls these three operations ... As built in T-018 (tested locally, not deployed): the role gate also admits ADMIN (so an admin can create and manage global codes); a club owner may still create a promo with neither id (approved judgement); the legacy global code is ADMIN only; foreign or unknown ids give the same 404 NOT_FOUND. Open question: the T-018 task text says owners must not create global codes, which conflicts with the approved judgement. |
| POST | `/event` | CR-02, CR-03, CR-12, CR-17 | additive | Request gains optional `timezone`, `pricingMode`, `organizerId` (defaults keep current behaviour). Ticket tiers gain `tierType`. **`timezone` and `pricingMode` implemented in T-017 (tested locally, not deployed):** `timezone` is a validated IANA name (422), default UTC, not inferred from city or coordinates; `pricingMode` is checked against price and active tiers (422 PRICING_MODE_INVALID) and derived when omitted; both are returned on the event row (additive). `eventDescription` and tier `description` accept an empty string, stored as NULL. Lineup items accept optional `artistId` (and artistAvatar already exists as the photo). |
| PUT | `/event/{id}` | CR-04, BUG-B24 | additive | Ticket tiers are now updated in place. A tier object WITH `id` updates that tier (soldCount and id preserved); a tier WITHOUT `id` is created; an existing tier missing from the array is deleted if soldCount=0, otherwise ... |
| POST | `/purchase/event` | CR-04, CR-06, CR-07 | additive | (T-006: tier storage implemented; release of soldCount still planned) The chosen tier is stored on the purchase (ticketTierId + tierName snapshot) and returned. soldCount is released when the payment expires or fails (stock was leaked before). Response is unchanged otherwise. Free tickets are ... |
| GET | `/bookings/{id}` | CR-04 | additive | Event bookings expose `ticketTierId` and `ticketTierName` (null for purchases made before this change and for no-tier purchases). |
| PUT | `/promo/{id}` | CR-06, BUG-S02 | behaviour (role check added; owner app unaffected) | Requires accountRole CLUB_OWNER (403 otherwise). Checked against flutter_app: only the club-owner Promo tab calls these three operations (promo_repository.dart:36,75,108); customers only call POST /promo/validate ... As built in T-018 (tested locally, not deployed): the role gate also admits ADMIN (so an admin can create and manage global codes); a club owner may still create a promo with neither id (approved judgement); the legacy global code is ADMIN only; foreign or unknown ids give the same 404 NOT_FOUND. Open question: the T-018 task text says owners must not create global codes, which conflicts with the approved judgement. |
| DELETE | `/promo/{id}` | CR-06, BUG-S02 | behaviour (role check added; owner app unaffected) | Requires accountRole CLUB_OWNER (403 otherwise). Checked against flutter_app: only the club-owner Promo tab calls these three operations (promo_repository.dart:36,75,108); customers only call POST /promo/validate ... As built in T-018 (tested locally, not deployed): the role gate also admits ADMIN (so an admin can create and manage global codes); a club owner may still create a promo with neither id (approved judgement); the legacy global code is ADMIN only; foreign or unknown ids give the same 404 NOT_FOUND. Open question: the T-018 task text says owners must not create global codes, which conflicts with the approved judgement. |
| POST | `/promo/validate` | CR-06, BUG-S09 | additive | Rate limited per IP and per user (suggested 20/min). Excess returns 429 with Retry-After. |
| POST | `/event/{eventId}/guest-list/join` | CR-06, BUG-B29 | additive | A user with an existing PENDING or APPROVED entry for the same event gets 409 GUEST_LIST_DUPLICATE instead of a second entry. |
| POST | `/event/{eventId}/modules` | CR-07 | additive | Module gains `pricingType` (default FIXED). |
| PUT | `/event/{eventId}/modules/{id}` | CR-07 | additive | Module gains `pricingType`. |
| POST | `/purchase/module` | CR-07 | additive | Modules with pricingType STARTING_FROM return 409 QUOTE_REQUIRED. Optional `extras` lines add purchasable extras to the same order (see /event/{eventId}/extras). |
| POST | `/hosts/{id}/contact` | CR-07, BUG-B30 | additive | When a valid optional token is present the inquiry is linked to the user (it is currently ignored). Anonymous inquiries still work. Rate limited (429). |
| GET | `/owner/earnings` | CR-08 | behaviour (totals now include tables) | Where clause also includes event-module (table) purchases, which were previously omitted from earnings totals. |
| GET | `/explore` | CR-09, CR-10, BUG-B28 | additive | New optional params radiusKm, cityId, group, from, to. `sort=trending` is implemented (views + interested over the last 7 days; Q6c default). dateFilter gains `this_week`. Items gain `distanceKm` when a search centre exists. ... |
| GET | `/explore/feed` | CR-09, BUG-B28 | additive | lat/lng, city, cityId and radiusKm are honoured by every feed module (lat/lng were accepted but ignored). Module labels use the city actually applied. |
| POST | `/event/{id}/duplicate` | CR-09, BUG-B25 | additive | The copy gets PostGIS `geog` set, so it appears in geo-filtered explore results. |
| GET | `/explore/genres` | CR-10 | additive | Unchanged for existing clients; new clients use /explore/filters. |
| GET | `/explore/{id}` | CR-11, CR-13, BUG-B28 | additive | type=EVENT gains `interestedCount`, `isInterested` (bearer only), `mapUrl` (Google Maps link built from lat/lng and name), `timezone`. viewCount is incremented only for existing, active events, and a view is recorded in the ... |
| GET | `/bookings` | CR-14 | additive | New optional `bucket` filter (FUTURE/PENDING/PAST) and items gain `bookingStatus` (CONFIRMED / GUEST_LIST_PENDING / PAYMENT_PROCESSING / CANCELED / REFUNDED). `tab` is unchanged. |
| POST | `/webhooks/payment/stripe` | CR-16, BUG-B16 | additive | Missing or invalid Stripe signature returns 400 (was 500, which makes Stripe retry for days). Payment webhook also handles refund events (refund created/updated/failed) to update Refund.status; duplicates are ignored via ... |
| POST | `/connect/webhook` | CR-16, BUG-B16 | additive | Missing or invalid Stripe signature returns 400 (was 500). |

### Deprecated (kept working)

| Method | Path | Requirement | Replacement | Note |
|---|---|---|---|---|
| POST | `/quotes` | CR-07, BUG-S08 | `POST /v2/quotes` | Still served unchanged; no removal date. |
| GET | `/admin/commission` | CR-15 | `/v2/admin/pricing-rules` | Still served unchanged; no removal date. |
| PATCH | `/admin/commission` | CR-15 | `/v2/admin/pricing-rules` | Still served unchanged; no removal date. |
| GET | `/service-charge` | CR-15 | `/v2/admin/pricing-rules` | Still served unchanged; no removal date. |
| GET | `/admin/service-charge` | CR-15 | `/v2/admin/pricing-rules` | Still served unchanged; no removal date. |
| PATCH | `/admin/service-charge` | CR-15 | `/v2/admin/pricing-rules` | Still served unchanged; no removal date. |

### Not in this release

- CR-05 (multi-day passes, per-day scanning): deferred (Q5). `POST /owner/verify-ticket` stays one check-in per order.
- CR-01 owner approval (PENDING on signup, `OWNER_NOT_APPROVED`, admin approval endpoints, `ownerApprovalStatus`): deferred until the client answers D1. Signup and owner endpoints behave as today.
- CR-04 availability badges, auto progression, starting price: not approved yet, so tiers still expose `soldCount` and `soldOut`.
- CR-02 unregistered venues and payout split (Q3, Q4); CR-07 quote-to-payment (Q1); CR-15 rule values (Q2); CR-06 guest-list access codes; CR-08 scans and no-shows; CR-16 partial refunds per attendee (Q8): one refund per order for now.
- Gap 2 (pricing rule preview endpoint): deferred.

---

## v1 baseline

The as-is contract (151 operations, reverse-engineered) is the baseline for everything above. Operations without `x-status` in `api-spec.yaml` describe current behaviour.

