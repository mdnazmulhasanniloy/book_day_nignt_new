# API spec diff, v1 to v2 (TO-BE)

Companion to `api-spec-changelog.md`. Source of truth is `api-spec.yaml` (every item has `x-requirement`, `x-status: planned`). This file lists **every change to an existing v1 operation** with an explicit answer to "breaking for the live Flutter app?", then the deprecated and the new operations.

How "breaking for the live Flutter app" was judged: the Flutter app in `flutter_app/` calls `/api/v1` only. Its endpoints are listed in `flutter_app/lib/app/core/network/end_point.dart`. It does not call any `/admin/*` path, `/auth/refresh` or the Stripe webhooks. Errors: 401/403 go to `UnauthorizedException`, other 4xx to `ValidationException` with the server message, 5xx to `ServerException` with a generic text (`base_client.dart:489-500`, `api_error_handler.dart:68-74`). JSON is parsed by hand, so new response keys are ignored. Not every model and screen was read: statements marked "not read" are assumptions, the rest were checked in code.

Totals: 33 changed v1 operations, 6 deprecated, 47 added (5 under `/api/v2`). Spec operations: 151 to 198.

**Update 2026-11-24 (client answers 2026-11-24, CR-18 to CR-28):** 50 more operations added (47 under `/api/v2`), 8 existing operations changed additively (rows marked 2026-11-24 in section 1), plus a 423 response added to the 50 partner (club owner) operations, no new deprecations. Spec operations: 198 to 247. The result of the Flutter check is in the paragraph before section 1.

**Result: no change to an existing v1 operation is breaking for the live Flutter app.** One operation is breaking for other clients in general: `GET /admin/users` (password hash removed, a security fix; only the Admin client calls it). The closest call was the free-order path in `POST /purchase/event`: as first drafted it would have broken the live app, so it is now opt-in (`freeCheckout`).

**Update 2026-11-24 result: nothing in this update is breaking for the live Flutter app, on three conditions.** (1) The new fee model (Technical Fee 5 percent plus a fixed part) is switched on only after the force-update gate (ADR-012): the live app loads the flat `/service-charge` and adds it to the price on the device (`flutter_app/lib/app/modules/user_side/club_details_view/controllers/buy_ticker_controller.dart:88-96`), so a different server-side fee would show a total that differs from the charge. (2) Pending club owners and organizers are answered with HTTP 423 `PARTNER_APPROVAL_PENDING`, never 401 or 403, because the live app treats 401 and 403 as a dead session (`flutter_app/lib/app/core/network/api_error_handler.dart:68`, `base_client.dart:492`) and shows the server message for other 4xx (ADR-010). (3) Staff and platform roles are separate tables and additive response fields; no value is added to `AccountRole` (ADR-008), because the app compares the role string (`sign_in_controller.dart:157,166,394,401`).

## 1. Changed v1 operations

| Method | Path | Requirement | What changes | Breaking for live Flutter app? (yes/no + reason) | Contract-breaking for any client? |
|---|---|---|---|---|---|
| POST | `/auth/social` | CR-01 | Request accepts optional `dateOfBirth`. Response `data` gains `profileComplete` (boolean; false while date of birth is missing) so clients can ask for it before purchase. Retried calls with the same provider subject never create a second account. | No. Flutter calls it (end_point.dart:13). The new request field is optional and the new response key is ignored. | No |
| POST | `/admin/auth/refresh` | CR-01, CR-17, BUG-B17 | Invalid or expired refresh token returns 401 (errorType TOKEN_INVALID / TOKEN_EXPIRED) instead of 500. Admin client already logs out on any refresh failure, so no client change is needed. | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). The Admin client logs out on any refresh failure (axios.configs.ts:61-66), so 500 and 401 behave the same. | No |
| GET | `/admin/users` | CR-17, BUG-B22, BUG-S17 | Response no longer contains `password` (bcrypt hash leak). This is the only field removal in this release, accepted as a security fix; only the Admin client calls this endpoint and it does not read the field. page/limit that are not positive integers now return 422 instead of NaN behaviour. | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). The Admin client does not read the users `password` field (the only admin files mentioning password are the login and forgot/change-password forms). | Yes: removes `password` (bcrypt hash leak, BUG-S17). Accepted security exception, see ADR-001. |
| GET | `/admin/earnings` | CR-17, BUG-B22 | page/limit that are not positive integers return 422 (was NaN behaviour). | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). Invalid page/limit now returns 422 instead of undefined NaN behaviour. | No |
| PATCH | `/admin/users/{id}/suspend` | CR-17, BUG-B18 | Unknown user id returns 404 (was 500). | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). 500 becomes 404. | No |
| POST | `/owner/verify-ticket` | CR-17, BUG-B15 | Business failures return real statuses with errorType instead of 500: not found OR not your order -> 404 (existence of other sellers' orders is not revealed); not PAID or refunded -> 422 TICKET_NOT_VALID; already used -> 409 TICKET_ALREADY_USED (body includes usedAt). 401/403 are deliberately NOT used for business failures, because the Flutter client treats 401/403 as an authentication failure. Endpoint behaviour is otherwise unchanged (one check-in per order); the per-day/per-attendee scan is deferred with CR-05. | No. Flutter calls it (end_point.dart:89). No. Only the status code changes (500 to 4xx). Flutter maps every 4xx to ValidationException and shows the server message, and every 5xx to ServerException with a generic text (base_client.dart:495-497, api_expection.dart:29-43). Not 401/403, so no logout path is triggered. Deliberately 404/409/422, because a 403 would be treated as an authentication failure. | No |
| GET | `/club/{id}` | CR-17, BUG-B26 | Club not found or not owned returns 404 (was 500 from unmapped Prisma P2025). | No. Only the status code changes (500 to 4xx). Flutter maps every 4xx to ValidationException and shows the server message, and every 5xx to ServerException with a generic text (base_client.dart:495-497, api_expection.dart:29-43). Not 401/403, so no logout path is triggered. | No |
| PUT | `/club/{id}` | CR-17, BUG-B26 | Club not found or not owned returns 404 (was 500 from unmapped Prisma P2025). | No. Only the status code changes (500 to 4xx). Flutter maps every 4xx to ValidationException and shows the server message, and every 5xx to ServerException with a generic text (base_client.dart:495-497, api_expection.dart:29-43). Not 401/403, so no logout path is triggered. | No |
| GET | `/event/{id}` | CR-17, BUG-B26 | Event not found or not owned returns 404 (was 500 from unmapped Prisma P2025). | No. Only the status code changes (500 to 4xx). Flutter maps every 4xx to ValidationException and shows the server message, and every 5xx to ServerException with a generic text (base_client.dart:495-497, api_expection.dart:29-43). Not 401/403, so no logout path is triggered. Also adds optional response fields. | No |
| DELETE | `/event/{eventId}/modules/{id}` | CR-17, BUG-B26 | Module referenced by purchases returns 409 (was 500, FK Restrict). | No. Only the status code changes (500 to 4xx). Flutter maps every 4xx to ValidationException and shows the server message, and every 5xx to ServerException with a generic text (base_client.dart:495-497, api_expection.dart:29-43). Not 401/403, so no logout path is triggered. (409 for a module that has purchases.) | No |
| POST | `/wishlist` | CR-17, BUG-B27 | Target not found returns 404 (service threw the wrong error shape and returned 500). | No. Only the status code changes (500 to 4xx). Flutter maps every 4xx to ValidationException and shows the server message, and every 5xx to ServerException with a generic text (base_client.dart:495-497, api_expection.dart:29-43). Not 401/403, so no logout path is triggered. | No |
| POST | `/promo` | CR-06, CR-17, BUG-B26, BUG-S02 | Unknown eventId/clubId returns 404 (was 500, FK violation). Requires accountRole CLUB_OWNER (403 otherwise). Checked against flutter_app: only the club-owner Promo tab calls these three operations (promo_repository.dart:36,75,108); customers only call POST /promo/validate (club_purchase_repository.dart:220). If eventId or clubId is sent it must belong to the caller (404 otherwise, not 403, because the Flutter client treats 403 like 401). A promo with neither scope is still allowed, because the owner Add Promo screen can submit it (add_promo_view.dart:338,355 toggle the ids to null and nothing forces one). Update and delete keep the existing ownership filter (createdByUserId, own event or own club; promo.services.ts:9-22, 404 otherwise). | No. Only the club-owner Promo tab calls create/update/delete (promo_repository.dart:36,75,108); customers call only POST /promo/validate (club_purchase_repository.dart:220). The new role check passes for owners; promos with no event/club stay allowed because the Add Promo screen can submit them (add_promo_view.dart:338,355). | No (authorization tightened) |
| POST | `/event` | CR-02, CR-03, CR-12, CR-17 | Request gains optional `timezone`, `pricingMode`, `organizerId` (defaults keep current behaviour). Ticket tiers gain `tierType`. Lineup items accept optional `artistId` (and artistAvatar already exists as the photo). | No. Flutter calls it (end_point.dart:92). New fields (`timezone`, `pricingMode`, `organizerId`, tier `tierType`, lineup `artistId`) are optional and defaults reproduce current behaviour. | No |
| PUT | `/event/{id}` | CR-04, BUG-B24 | Ticket tiers are now updated in place. A tier object WITH `id` updates that tier (soldCount and id preserved); a tier WITHOUT `id` is created; an existing tier missing from the array is deleted if soldCount=0, otherwise deactivated (isActive=false) and kept. capacity lower than soldCount returns 409 TIER_CAPACITY_BELOW_SOLD. Previously `id` was ignored and all tiers were deleted and recreated (soldCount reset to 0). Backward compatibility for the live app, which does not send ids: when no incoming tier carries an id, the server matches incoming tiers to existing ones by (parent groupName, tierName) and updates those in place; unmatched sold tiers are deactivated rather than deleted. | No for the request and response shape. Behaviour change on purpose: tiers are updated in place, so sold counts are no longer reset (BUG-B24). A capacity below the sold count now returns 409, a 4xx the app shows as a message. The live app sends no tier ids, so the by-name fallback (ADR-004) keeps it working. | No |
| POST | `/purchase/event` | CR-04, CR-06, CR-07 | The chosen tier is stored on the purchase (ticketTierId + tierName snapshot) and returned. soldCount is released when the payment expires or fails (stock was leaked before). Response is unchanged otherwise. Free tickets are OPT-IN so the live app is not affected. Today a price-0 order still carries the buyer service fee, so it is paid through POST /payment/intent. The live app would call /payment/intent for an order that is already PAID, so the new path must not be the default. New optional request field `freeCheckout: true`: when the order gross is 0 after promo, no PaymentIntent is needed, the order is created already PAID, the buyer service fee is waived (provisional until Q2) and the response carries `paymentRequired: false`. Without `freeCheckout` (or when gross > 0) behaviour is exactly as today and `paymentRequired` is true. Tier price 0 is already accepted by tier create/update. Optional `extras` lines add purchasable extras (e.g. sunbed for two) to the same order. Extras stock is checked and decremented inside the same transaction and released with the order. Service fee/commission treatment of extras waits for Q2. | No. Flutter calls it (end_point.dart:48). New response fields are ignored. The free-order path is opt-in through `freeCheckout`, which the live app never sends, so a price-0 order still carries the service fee and goes through /payment/intent exactly as today. (An earlier draft made it the default; that would have made the live app call /payment/intent for an already PAID order, so it was changed.) | No |
| GET | `/bookings/{id}` | CR-04 | Event bookings expose `ticketTierId` and `ticketTierName` (null for purchases made before this change and for no-tier purchases). | No. New optional fields only. Flutter parses JSON by hand (fromJson, for example promo_api_model.dart:111, event_offer_model.dart:224; json_serializable and freezed are not in pubspec.yaml), so unknown keys are ignored. Not every model was read. | No |
| PUT | `/promo/{id}` | CR-06, BUG-S02 | Requires accountRole CLUB_OWNER (403 otherwise). Checked against flutter_app: only the club-owner Promo tab calls these three operations (promo_repository.dart:36,75,108); customers only call POST /promo/validate (club_purchase_repository.dart:220). If eventId or clubId is sent it must belong to the caller (404 otherwise, not 403, because the Flutter client treats 403 like 401). A promo with neither scope is still allowed, because the owner Add Promo screen can submit it (add_promo_view.dart:338,355 toggle the ids to null and nothing forces one). Update and delete keep the existing ownership filter (createdByUserId, own event or own club; promo.services.ts:9-22, 404 otherwise). | No. Same as POST /promo (promo_repository.dart:75). Ownership filter already exists in the service (promo.services.ts:9-22). | No (authorization tightened) |
| DELETE | `/promo/{id}` | CR-06, BUG-S02 | Requires accountRole CLUB_OWNER (403 otherwise). Checked against flutter_app: only the club-owner Promo tab calls these three operations (promo_repository.dart:36,75,108); customers only call POST /promo/validate (club_purchase_repository.dart:220). If eventId or clubId is sent it must belong to the caller (404 otherwise, not 403, because the Flutter client treats 403 like 401). A promo with neither scope is still allowed, because the owner Add Promo screen can submit it (add_promo_view.dart:338,355 toggle the ids to null and nothing forces one). Update and delete keep the existing ownership filter (createdByUserId, own event or own club; promo.services.ts:9-22, 404 otherwise). | No. Same as POST /promo (promo_repository.dart:108). | No (authorization tightened) |
| POST | `/promo/validate` | CR-06, BUG-S09 | Rate limited per IP and per user (suggested 20/min). Excess returns 429 with Retry-After. | No. Flutter calls it at checkout (club_purchase_repository.dart:220). The new 429 appears only after more than about 20 attempts a minute and is a 4xx shown as a message. | No |
| POST | `/event/{eventId}/guest-list/join` | CR-06, BUG-B29 | A user with an existing PENDING or APPROVED entry for the same event gets 409 GUEST_LIST_DUPLICATE instead of a second entry. | No. 409 on a duplicate join is a 4xx shown as a message. Behaviour change on purpose (BUG-B29): a second entry is no longer created. | No |
| POST | `/event/{eventId}/modules` | CR-07 | Module gains `pricingType` (default FIXED). | No. `pricingType` is optional and defaults to FIXED, which is what existing modules do today. | No |
| PUT | `/event/{eventId}/modules/{id}` | CR-07 | Module gains `pricingType`. | No. Same as POST modules. | No |
| POST | `/purchase/module` | CR-07 | Modules with pricingType STARTING_FROM return 409 QUOTE_REQUIRED. Optional `extras` lines add purchasable extras to the same order (see /event/{eventId}/extras). | No. Existing modules default to FIXED, so the new 409 QUOTE_REQUIRED cannot occur for them. `extras` is optional. | No |
| POST | `/hosts/{id}/contact` | CR-07, BUG-B30 | When a valid optional token is present the inquiry is linked to the user (it is currently ignored). Anonymous inquiries still work. Rate limited (429). | No. The token was already optional. New: the inquiry is linked to the user when present, and a 429 on abuse. | No |
| GET | `/owner/earnings` | CR-08 | Where clause also includes event-module (table) purchases, which were previously omitted from earnings totals. | No for the contract. Numbers shown to owners change: table (module) purchases are now included in the totals. Product-visible, tell the client. | No |
| GET | `/explore` | CR-09, CR-10, BUG-B28 | New optional params radiusKm, cityId, group, from, to. `sort=trending` is implemented (views + interested over the last 7 days; Q6c default). dateFilter gains `this_week`. Items gain `distanceKm` when a search centre exists. Response is unchanged when no new param is sent. meta.total is the live result count used by filter UIs. | No. Every new parameter is optional (`radiusKm` default 20 equals the hard-coded value). `sort=trending` becomes effective, but the app does not send it (no `trending` sort in flutter_app). `dateFilter` gains an enum value. New `distanceKm` item field is ignored. | No |
| GET | `/explore/feed` | CR-09, BUG-B28 | lat/lng, city, cityId and radiusKm are honoured by every feed module (lat/lng were accepted but ignored). Module labels use the city actually applied. | No. Flutter calls it with no query parameters (discovery_feed_section.dart:46), so honouring lat/lng and radius changes nothing for it. | No |
| POST | `/event/{id}/duplicate` | CR-09, BUG-B25 | The copy gets PostGIS `geog` set, so it appears in geo-filtered explore results. | No. Only sets the missing PostGIS point on the copy, so the copy now shows up in nearby searches. | No |
| GET | `/explore/genres` | CR-10 | Unchanged for existing clients; new clients use /explore/filters. | No. Unchanged; only a description note. | No |
| GET | `/explore/{id}` | CR-11, CR-13, BUG-B28 | type=EVENT gains `interestedCount`, `isInterested` (bearer only), `mapUrl` (Google Maps link built from lat/lng and name), `timezone`. viewCount is incremented only for existing, active events, and a view is recorded in the user's history when a bearer token is sent. Event detail additions are listed under CR-11/CR-13 above (interestedCount, mapUrl, timezone). Organizer/club identity stays in `organizer`; `organizerProfile` (id, name, avatar) is added when the event has an organizer (CR-02). | No. New optional fields only. Flutter parses JSON by hand (fromJson, for example promo_api_model.dart:111, event_offer_model.dart:224; json_serializable and freezed are not in pubspec.yaml), so unknown keys are ignored. Not every model was read. A view is recorded when a token is sent; `viewCount` is incremented only for existing active events. | No |
| GET | `/bookings` | CR-14 | New optional `bucket` filter (FUTURE/PENDING/PAST) and items gain `bookingStatus` (CONFIRMED / GUEST_LIST_PENDING / PAYMENT_PROCESSING / CANCELED / REFUNDED). `tab` is unchanged. | No. `bucket` is optional and `tab` keeps working. New item field `bookingStatus` is ignored. | No |
| POST | `/webhooks/payment/stripe` | CR-16, BUG-B16 | Missing or invalid Stripe signature returns 400 (was 500, which makes Stripe retry for days). Payment webhook also handles refund events (refund created/updated/failed) to update Refund.status; duplicates are ignored via WebhookEvent.stripeEventId. | No. Called by Stripe, not by Flutter. A bad signature now returns 400 instead of 500. | No |
| POST | `/connect/webhook` | CR-16, BUG-B16 | Missing or invalid Stripe signature returns 400 (was 500). | No. Called by Stripe, not by Flutter. A bad signature now returns 400 instead of 500. | No |
| POST | `/auth/login` | CR-18, CR-19 (2026-11-24) | Session response `data` gains additive `partnerStatus` (PENDING, APPROVED, REJECTED or null), `teamRole` and `permissions`. | No. New optional fields only; Flutter parses by hand and reads `role`, which is unchanged (`sign_in_controller.dart:157`). | No |
| POST | `/auth/social` | CR-18, CR-19 (2026-11-24) | Response `data` gains the same three additive fields. Still always creates a USER. | No. New optional fields only. | No |
| POST | `/auth/check` | CR-18, CR-19 (2026-11-24) | `data` gains the same three additive fields so the app can show the pending screen. | No. New optional fields only. | No |
| (50 partner operations) | every `CLUB_OWNER` or `/owner/*` operation, for example `POST /club`, `POST /event`, `POST /owner/verify-ticket`, `GET /owner/dashboard` | CR-18 (2026-11-24) | New response `423` `PARTNER_APPROVAL_PENDING` for an owner or organizer whose application is not approved. Existing owners are backfilled as APPROVED (migration 1), so they never see it. | No for existing owners. For a NEW owner on an old app version: 423 is a 4xx, so the app shows the server message and does NOT log out (401 and 403 would: `api_error_handler.dart:68`). The old signup screen still offers `CLUB_OWNER` (`sign_up_model.dart:3`); that account is now PENDING instead of active. | No |
| GET | `/service-charge` | CR-15, CR-26 (2026-11-24) | Unchanged and kept for old app versions. New apps use `POST /v2/checkout/preview`. | No, on condition (1) above: the fee model v2 stays off until the minimum version gate is on (ADR-012). | No |
| POST | `/purchase/event` | CR-25, CR-26 (2026-11-24) | Limit of 5 tickets per order plus 10 per customer per event (configurable per event): over-limit returns 409 `PURCHASE_LIMIT_EXCEEDED`. The charged total comes from the same calculation as the preview. | No. A new 4xx on a path that already fails; shown as a message. Under the gate the charged total matches what new apps show. | No |
| GET | `/explore/{id}` | CR-04 (2026-11-24) | `type=EVENT` gains additive `startingPrice` and `availability` (LAST_TICKETS at 20 percent or less). Exact stock counts stay hidden in the v2 shape; v1 fields stay. | No. New optional fields only. | No |
| GET | `/cities` | CR-24 (2026-11-24) | Items gain additive `kind` (CITY or AREA) and `areaId` for the Cote d Azur destination area. | No. New optional fields only. | No |
| POST | `/promo` | CR-06 (2026-11-24) | Optional `purpose`, `eventId`, `expiresAt`, `maxUses` for access codes; default purpose DISCOUNT. | No. All optional; existing requests behave as before. | No |
| POST | `/owner/verify-ticket` | CR-05 (2026-11-24) | Unchanged. Multi-day passes and per-day scanning use `POST /v2/owner/scan`. | No. Same behaviour; the old per-order check-in stays. | No |

## 2. Deprecated v1 operations (still served, behaviour unchanged unless stated)

| Method | Path | Requirement | Replacement | Breaking for live Flutter app? (yes/no + reason) |
|---|---|---|---|---|
| POST | `/quotes` | CR-07, BUG-S08 | `POST /v2/quotes` | No. Flutter calls it (end_point.dart:122) and it stays public and unchanged. New: a 429 on abuse and a user link when a token is sent. Marked deprecated in favour of POST /v2/quotes; no removal date. |
| GET | `/admin/commission` | CR-15 | `/v2/admin/pricing-rules` | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). Works unchanged; deprecated in favour of /v2/admin/pricing-rules. The current Admin pages keep using it. |
| PATCH | `/admin/commission` | CR-15 | `/v2/admin/pricing-rules` | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). Works unchanged and writes through to the pricing rules (ADR-003). |
| GET | `/service-charge` | CR-15 | `/v2/admin/pricing-rules` | No. Flutter calls it (end_point.dart:51). Works unchanged; it mirrors the GLOBAL fee rule. |
| GET | `/admin/service-charge` | CR-15 | `/v2/admin/pricing-rules` | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). Works unchanged. |
| PATCH | `/admin/service-charge` | CR-15 | `/v2/admin/pricing-rules` | No. Flutter does not call /admin/* (flutter_app end_point.dart has no admin path). Works unchanged and writes through to the pricing rules. |

No removal date is set for any deprecated operation (ADR-001).

## 3. Added operations

New paths cannot break a client that does not call them. v2 paths are served under `/api/v2` and carry `x-api-version: v2`.

| Method | Path | Requirement | Version | Summary |
|---|---|---|---|---|
| GET | `/ticket-tier-presets` | CR-03 | v1 (additive) | Preset tier names |
| POST | `/v2/quotes` | CR-07, BUG-S08 | v2 | Create a quote request (authenticated) |
| POST | `/event/{eventId}/extras` | CR-07 | v1 (additive) | Create an extra |
| GET | `/event/{eventId}/extras` | CR-07 | v1 (additive) | List extras of an event |
| PUT | `/event/{eventId}/extras/{id}` | CR-07 | v1 (additive) | Update an extra |
| DELETE | `/event/{eventId}/extras/{id}` | CR-07 | v1 (additive) | Delete or deactivate an extra |
| GET | `/owner/analytics` | CR-08 | v1 (additive) | Club overview analytics |
| GET | `/owner/events/{eventId}/analytics` | CR-08 | v1 (additive) | Per-event analytics |
| GET | `/cities` | CR-09 | v1 (additive) | Search cities |
| GET | `/admin/cities` | CR-09 | v1 (additive) | List cities (admin) |
| POST | `/admin/cities` | CR-09 | v1 (additive) | Create a city |
| PATCH | `/admin/cities/{id}` | CR-09 | v1 (additive) | Update a city (launch / unlaunch) |
| GET | `/explore/filters` | CR-10 | v1 (additive) | Filter vocabulary for a type |
| GET | `/explore/map` | CR-10 | v1 (additive) | Map pins with the same filters as /explore |
| GET | `/admin/filter-options` | CR-10 | v1 (additive) | List genre and mood vocabulary |
| POST | `/admin/filter-options` | CR-10 | v1 (additive) | Add a genre or mood |
| PATCH | `/admin/filter-options/{id}` | CR-10 | v1 (additive) | Edit or deactivate a genre or mood |
| POST | `/events/{eventId}/interested` | CR-11 | v1 (additive) | Mark Interested |
| DELETE | `/events/{eventId}/interested` | CR-11 | v1 (additive) | Remove Interested |
| GET | `/me/recently-viewed` | CR-11 | v1 (additive) | My recently viewed events |
| GET | `/explore/most-viewed` | CR-11 | v1 (additive) | Most viewed events in a city |
| GET | `/artists` | CR-12 | v1 (additive) | Discover artists |
| GET | `/artists/{id}` | CR-12 | v1 (additive) | Artist profile |
| PATCH | `/artists/{id}` | CR-12 | v1 (additive) | Edit an artist profile (owner) |
| GET | `/admin/artists` | CR-12 | v1 (additive) | List artists (admin) |
| PATCH | `/admin/artists/{id}` | CR-12 | v1 (additive) | Edit or verify an artist (admin) |
| POST | `/organizer/profile` | CR-02 | v1 (additive) | Create my organizer profile |
| PUT | `/organizer/profile` | CR-02 | v1 (additive) | Update my organizer profile |
| GET | `/organizers/{id}` | CR-02 | v1 (additive) | Public organizer profile |
| POST | `/organizers/{id}/follow` | CR-02 | v1 (additive) | Follow an organizer |
| DELETE | `/organizers/{id}/follow` | CR-02 | v1 (additive) | Unfollow an organizer |
| POST | `/collaboration-requests` | CR-02 | v1 (additive) | Ask a club to host an event |
| GET | `/collaboration-requests` | CR-02 | v1 (additive) | List my collaboration requests |
| PATCH | `/collaboration-requests/{id}` | CR-02 | v1 (additive) | Accept, reject or cancel |
| GET | `/admin/organizers` | CR-02 | v1 (additive) | List organizer profiles (admin) |
| PATCH | `/admin/organizers/{id}` | CR-02 | v1 (additive) | Verify or suspend an organizer (admin) |
| GET | `/admin/collaboration-requests` | CR-02 | v1 (additive) | List collaboration requests (admin, read only) |
| GET | `/v2/admin/pricing-rules` | CR-15 | v2 | List fee and commission rules |
| POST | `/v2/admin/pricing-rules` | CR-15 | v2 | Create a rule |
| PATCH | `/v2/admin/pricing-rules/{id}` | CR-15 | v2 | End-date or edit a future rule |
| GET | `/v2/admin/financials` | CR-15 | v2 | Fees vs commission vs proceeds report |
| POST | `/owner/orders/{orderId}/refund-requests` | CR-16 | v1 (additive) | Request a refund (owner) |
| GET | `/admin/orders` | CR-16 | v1 (additive) | List orders (admin, read only) |
| GET | `/admin/orders/{orderId}` | CR-16 | v1 (additive) | Order detail (admin, read only) |
| GET | `/admin/refund-requests` | CR-16 | v1 (additive) | List refund requests |
| PATCH | `/admin/refund-requests/{id}` | CR-16 | v1 (additive) | Approve or reject a refund request |
| GET | `/admin/refunds` | CR-16 | v1 (additive) | List refunds |
| GET | `/v2/app/version-policy` | CR-26 (2026-11-24) | v2 (new) | App version policy (force-update gate) |
| POST | `/v2/checkout/preview` | CR-26, CR-15, Q1, Q2 (2026-11-24) | v2 (new) | Server-calculated total for a basket (tickets, tables, extras) |
| GET | `/admin/partner-applications` | CR-18, Q22 (2026-11-24) | additive (new endpoint) | List partner (club owner and organizer) applications |
| POST | `/admin/partner-applications/{id}/approve` | CR-18, Q22 (2026-11-24) | additive (new endpoint) | Approve a partner application |
| POST | `/admin/partner-applications/{id}/reject` | CR-18, Q22 (2026-11-24) | additive (new endpoint) | Reject a partner application |
| GET | `/v2/clubs/{clubId}/team` | CR-19, Q24 (2026-11-24) | v2 (new) | List club team members and pending invitations |
| POST | `/v2/clubs/{clubId}/team` | CR-19, Q24 (2026-11-24) | v2 (new) | Invite a manager or staff member |
| POST | `/v2/team/invitations/{token}/accept` | CR-19, Q24 (2026-11-24) | v2 (new) | Accept a team invitation |
| PATCH | `/v2/clubs/{clubId}/team/{memberId}` | CR-19, Q24 (2026-11-24) | v2 (new) | Change role, assigned events or suspend a team member |
| DELETE | `/v2/clubs/{clubId}/team/{memberId}` | CR-19, Q24 (2026-11-24) | v2 (new) | Remove a team member |
| PATCH | `/v2/admin/team-members/{id}/suspend` | CR-19, Q24 (2026-11-24) | v2 (new) | Suspend any club team account (platform) |
| GET | `/v2/admin/platform-staff` | CR-19, Q24 (2026-11-24) | v2 (new) | List platform staff |
| POST | `/v2/admin/platform-staff` | CR-19, Q24 (2026-11-24) | v2 (new) | Create a platform staff account |
| GET | `/v2/admin/role-permissions` | CR-19, Q24 (2026-11-24) | v2 (new) | Read the role-permission matrix |
| GET | `/v2/admin/audit-log` | CR-19, Q24 | v2 | Read-only audit log of sensitive actions (admin only) |
| PUT | `/v2/admin/role-permissions` | CR-19, Q24 (2026-11-24) | v2 (new) | Replace the role-permission matrix (editable page) |
| PUT | `/v2/owner/organizers/{organizerId}/permissions` | CR-19, Q24, Q12 (2026-11-24) | v2 (new) | Grant or revoke organizer permissions (quotes, chat, refunds) |
| POST | `/v2/table-requests` | CR-07, CR-16, Q3 (2026-11-24) | v2 (new) | Create a table request |
| GET | `/v2/table-requests/{id}` | CR-07, Q3 (2026-11-24) | v2 (new) | Read a table request |
| POST | `/v2/table-requests/{id}/quote` | CR-07, Q4 (2026-11-24) | v2 (new) | Issue a quote |
| POST | `/v2/table-requests/{id}/withdraw-quote` | CR-07, Q4 (2026-11-24) | v2 (new) | Withdraw an unpaid quote |
| POST | `/v2/table-requests/{id}/accept` | CR-07, Q3, Q4 (2026-11-24) | v2 (new) | Accept (club) or accept and pay (customer) |
| POST | `/v2/table-requests/{id}/reject` | CR-07, Q3 (2026-11-24) | v2 (new) | Reject a pending request (club) |
| POST | `/v2/table-requests/{id}/cancel` | CR-07, CR-22, Q14 (2026-11-24) | v2 (new) | Cancel a table request or confirmed table |
| POST | `/v2/table-requests/{id}/payments` | CR-07, Q5 (2026-11-24) | v2 (new) | Pay the second online instalment |
| GET | `/v2/events/{eventId}/settlement` | CR-21, Q7 (2026-11-24) | v2 (new) | Read the settlement arrangement and split preview |
| PUT | `/v2/events/{eventId}/settlement` | CR-21, Q7 (2026-11-24) | v2 (new) | Propose the settlement split (owner) |
| POST | `/v2/events/{eventId}/settlement/accept` | CR-21, Q7 (2026-11-24) | v2 (new) | Accept the proposed split (organizer) |
| GET | `/v2/owner/settlements` | CR-21, Q8 (2026-11-24) | v2 (new) | Settlement statements and share states (owner) |
| GET | `/v2/admin/settlements` | CR-21, Q8, Q9 (2026-11-24) | v2 (new) | Settlements, transfers and failures (admin) |
| POST | `/v2/admin/transfers/{id}/retry` | CR-21, Q9 (2026-11-24) | v2 (new) | Retry a failed transfer |
| POST | `/v2/bookings/{id}/tickets/{ticketId}/cancel` | CR-22, Q12 (2026-11-24) | v2 (new) | Customer cancels one ticket |
| POST | `/v2/owner/orders/{orderId}/refunds` | CR-22, Q12, Q13 (2026-11-24) | v2 (new) | Club exception refund or documented goodwill refund |
| GET | `/v2/admin/refunds` | CR-22, Q10 (2026-11-24) | v2 (new) | Refund oversight (admin and platform staff) |
| POST | `/v2/admin/partner-debits/{id}/waive` | CR-22, Q10 (2026-11-24) | v2 (new) | Waive part or all of Bookdia margin on a partner debit |
| POST | `/v2/admin/charge-to-club` | CR-22, Q10 (2026-11-24) | v2 (new) | Charge to club (chargebacks from event cancellation or change) |
| POST | `/v2/owner/events/{eventId}/restock` | CR-22, Q15 (2026-11-24) | v2 (new) | Manual restock of released capacity |
| POST | `/v2/owner/events/{eventId}/change-notice` | CR-23, Q11 (2026-11-24) | v2 (new) | Announce a date or venue change |
| POST | `/v2/owner/scan` | CR-05, Q17 (2026-11-24) | v2 (new) | Scan a credential (per covered day) |
| GET | `/v2/events/{eventId}/days` | CR-05, Q20 (2026-11-24) | v2 (new) | Event days, per-day availability and entry cutoff |
| GET | `/v2/bookings/{id}/chat` | CR-20, Q6 (2026-11-24) | v2 (new) | Read the booking chat |
| POST | `/v2/bookings/{id}/chat` | CR-20, Q6 (2026-11-24) | v2 (new) | Send a message |
| GET | `/v2/admin/chats` | CR-20, Q6 (2026-11-24) | v2 (new) | Chat review queue (flagged and disputed) |
| POST | `/v2/admin/chats/{id}/intervene` | CR-20, Q6 (2026-11-24) | v2 (new) | Intervene in a conversation |
| POST | `/v2/venue-authorizations` | CR-23, Q25 (2026-11-24) | v2 (new) | Submit the venue authorization form and evidence |
| GET | `/v2/admin/venue-authorizations` | CR-23, Q25 (2026-11-24) | v2 (new) | Venue authorization review queue |
| POST | `/v2/admin/venue-authorizations/{id}/decision` | CR-23, Q25 (2026-11-24) | v2 (new) | Approve or reject a venue authorization |
| POST | `/v2/admin/events/{eventId}/venue-dispute` | CR-23, Q25 (2026-11-24) | v2 (new) | Open a venue dispute (suspend sales) |
| GET | `/v2/admin/destination-areas` | CR-24, Q26, Q27 (2026-11-24) | v2 (new) | List destination areas |
| POST | `/v2/admin/destination-areas` | CR-24, Q26, Q27 (2026-11-24) | v2 (new) | Create a destination area |

## 4. Removed from the draft (not in the contract)

- (Superseded 2026-11-24: D1 answered, the gate is now CR-18 with `GET /admin/partner-applications`, `partnerStatus` and the 423 status; names differ from the removed draft. Original note follows.) CR-01 owner approval gate, decision 2026-11-21: deferred until D1 is answered. Removed: `GET /admin/owner-applications`, `PATCH /admin/owner-applications/{userId}`, `ownerApprovalStatus` on `GET /profile`, the signup note, and `403 OWNER_NOT_APPROVED` on `POST /club`, `POST /event`, `POST /connect/onboarding`.
- (Superseded 2026-11-24: per-ticket cancellation and several refunds per order are modelled by CR-22, migration 17. Original note follows.) CR-16 per-attendee partial refunds: not modelled (Q8). One refund per order.

