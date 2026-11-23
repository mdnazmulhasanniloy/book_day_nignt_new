# API Usage Map (as-is)

> Maps every backend route in `api-spec.yaml` (151 operations: 139 under `/api/v1` plus 12 root-level routes served by `app.ts`) to the client code that calls it.
> Clients: **Flutter** = `flutter_app/` (the task called it `flutter_app`; read-only), **Admin** = `admin/`.
> Current state only. No changes proposed.

## 1. Method and confidence

- Call sites come from a static read of the two clients by a code-reading subagent (Flutter `core/network/end_point.dart` plus about 15 hardcoded paths in repositories; Admin `src/apis/*`, `src/features/*/api`, `src/configs/axios.configs.ts`).
- Flutter paths below are relative to the repo root (`flutter_app/lib/app/...`); Admin paths start with `admin/src/`.
- Every cited file was confirmed to exist and every cited line number to be within the file by script. The line numbers themselves were **⚠️ UNVERIFIED** (not individually matched to the endpoint string), except where spot-checked (section 6).
- Dynamic paths (for example `/explore/club/{id}/events/${kind}`) are listed against every backend route they could reach.
- "Unused" means no call site was found in either client. A route can still be used by clients outside this repo.

## 2. Summary

| Status | Routes |
|---|---|
| Both | 6 |
| Flutter only | 99 |
| Admin only | 23 |
| Not an API client route | 16 |
| **UNUSED** | 7 |
| **Total** | 151 |

Field additions on existing routes (no new routes): T-006 added `ticketTierId` and `ticketTierName` to `POST /purchase/event` (`data.eventPurchase`) and to `GET /bookings/{id}` (`data.booking.eventPurchase`). Both are additive and null for no-tier and old purchases. T-008 adds no route or field: after commit `POST /purchase/event` also enqueues the worker job `expire-event-ticket-hold` (15 min) that releases the tier stock of an order still unpaid. The route table below is unchanged: Flutter parses by hand and ignores unknown keys (not every model was read).

## 3. Route table

Columns: endpoint | used by Flutter (file:line) | used by Admin (file:line) | status.

### auth

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /auth/roles` | - | - | **UNUSED** |
| `POST /auth/signup` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:22` | - | Flutter only |
| `POST /auth/login` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:33` | - | Flutter only |
| `POST /auth/verify` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:51`<br>`flutter_app/lib/app/modules/authentication/controllers/otp_verification_controller.dart:118` | - | Flutter only |
| `POST /auth/resend` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:63` | - | Flutter only |
| `POST /auth/refresh` | - | - | **UNUSED** |
| `POST /auth/check` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:120`<br>`flutter_app/lib/app/modules/splash/splash_view.dart` | - | Flutter only |
| `POST /auth/logout` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:143`<br>`flutter_app/lib/app/modules/profile/controllers/profile_controller.dart:262` | - | Flutter only |
| `POST /auth/social` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:38` | - | Flutter only |

### admin

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /admin/auth/login` | - | `admin/src/features/login/api/login.api.ts:15` | Admin only |
| `POST /admin/auth/check` | - | `admin/src/apis/auth.api.ts:20` | Admin only |
| `POST /admin/auth/refresh` | - | `admin/src/configs/axios.configs.ts:66` | Admin only. T-010: now 401 (was 500) when the session is consumed; the Admin client logs out on any refresh failure, so no behaviour change |
| `POST /admin/auth/logout` | - | `admin/src/apis/auth.api.ts:25` | Admin only |
| `GET /admin/profile` | - | - | **UNUSED** |
| `PATCH /admin/profile` | - | `admin/src/apis/auth.api.ts:85` | Admin only |
| `PATCH /admin/change-password` | - | `admin/src/apis/auth.api.ts:59` | Admin only |
| `GET /admin/commission` | - | `admin/src/apis/commission.api.ts:32` | Admin only |
| `PATCH /admin/commission` | - | `admin/src/apis/commission.api.ts:37` | Admin only |
| `GET /admin/dashboard` | - | `admin/src/apis/dashboard.api.ts:34` | Admin only |
| `GET /admin/users` | - | `admin/src/apis/users.api.ts:67` | Admin only. T-010: page/limit validated (422); the Admin client sends limit 10 or 5 and a positive page, so no behaviour change |
| `PATCH /admin/users/{id}/suspend` | - | `admin/src/apis/users.api.ts:82` | Admin only. T-010: unknown id is 404 (was 500); the Admin client treats both as an error |
| `PATCH /admin/users/{id}/delete` | - | `admin/src/apis/users.api.ts:95` | Admin only |
| `PATCH /admin/users/{id}/restore` | - | - | **UNUSED** |
| `GET /admin/earnings` | - | `admin/src/apis/earnings.api.ts:30` | Admin only. T-010: page/limit validated (422) |

### legal

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /admin/terms` | - | `admin/src/apis/legal.api.ts:32` (getEndpoint) | Admin only |
| `PATCH /admin/terms` | - | `admin/src/apis/legal.api.ts:37` | Admin only |
| `GET /admin/privacy` | - | `admin/src/apis/legal.api.ts:32` (getEndpoint) | Admin only |
| `PATCH /admin/privacy` | - | `admin/src/apis/legal.api.ts:37` | Admin only |
| `GET /admin/about-us` | - | `admin/src/apis/legal.api.ts:32` (getEndpoint) | Admin only |
| `PATCH /admin/about-us` | - | `admin/src/apis/legal.api.ts:37` | Admin only |
| `GET /terms` | `flutter_app/lib/app/modules/rules/views/terms_and_condition_view.dart:36` | - | Flutter only |
| `GET /privacy` | `flutter_app/lib/app/modules/rules/views/privacy_policy_view.dart:36` | - | Flutter only |
| `GET /about-us` | `flutter_app/lib/app/modules/rules/views/about_us_view.dart:36` | - | Flutter only |

### profile

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /profile` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:154` | - | Flutter only |
| `PATCH /profile` | `flutter_app/lib/app/modules/profile/controllers/profile_controller.dart:132` | - | Flutter only |
| `DELETE /profile` | `flutter_app/lib/app/modules/profile/controllers/profile_controller.dart:297` | - | Flutter only |
| `GET /profile/deletion-preview` | - | - | **UNUSED** |
| `PATCH /change-password` | `flutter_app/lib/app/modules/profile/controllers/profile_controller.dart:209` | - | Flutter only |

### recover

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /recover/find` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:85` | `admin/src/features/forgot-password/api/forgot-password.api.ts:12` | Both |
| `POST /recover/verify` | `flutter_app/lib/app/modules/authentication/controllers/otp_verification_controller.dart:131` | `admin/src/features/forgot-password/api/forgot-password.api.ts:21` | Both |
| `POST /recover/reset` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:100` | `admin/src/features/forgot-password/api/forgot-password.api.ts:30` | Both |
| `POST /recover/resend` | `flutter_app/lib/app/modules/authentication/auth_repository/auth_repository.dart:76` | `admin/src/features/forgot-password/api/forgot-password.api.ts:39` | Both |

### media

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /media` | `flutter_app/lib/app/services/media_service.dart:28` | `admin/src/apis/media.api.ts:7` | Both |
| `DELETE /media` | `flutter_app/lib/app/services/media_service.dart:69` | `admin/src/apis/media.api.ts:21` | Both |

### notification

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /notifications` | `flutter_app/lib/app/modules/notification/repository/notification_repository.dart:32` | - | Flutter only |
| `GET /notifications/unread-count` | `flutter_app/lib/app/modules/notification/repository/notification_repository.dart:60` | - | Flutter only |
| `PATCH /notifications/read-all` | `flutter_app/lib/app/modules/notification/repository/notification_repository.dart:80` | - | Flutter only |
| `PATCH /notifications/{id}/read` | `flutter_app/lib/app/modules/notification/repository/notification_repository.dart:73` | - | Flutter only |

### serviceCharge

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /service-charge` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:130` | - | Flutter only |
| `GET /admin/service-charge` | - | `admin/src/apis/commission.api.ts:85` | Admin only |
| `PATCH /admin/service-charge` | - | `admin/src/apis/commission.api.ts:90` | Admin only |

### club

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /club` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/club_repository.dart:35` | - | Flutter only |
| `POST /club` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/club_repository.dart:16` | - | Flutter only |
| `GET /club/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/club_repository.dart:45` | - | Flutter only. T-012: missing or foreign id is now 404 NOT_FOUND (was 500); no client depends on the 500 (read only check: the app maps 4xx to a validation error with the server message, 5xx to a generic error) |
| `PUT /club/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/club_repository.dart:58` | - | Flutter only. T-012: missing or foreign id is now 404 NOT_FOUND (was 500) |
| `PUT /club/{id}/bookings/close` | - | - | **UNUSED** |
| `GET /admin/club` | - | `admin/src/apis/clubs.api.ts:28` | Admin only |

### event

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /event` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/event_repository.dart:15` | - | Flutter only. T-016: tier objects accept optional `tierType` (TICKET or PASS, default TICKET; invalid value 422). The live app does not send it. T-017: optional `timezone` (IANA, else 422), `pricingMode` (checked against price and tiers, 422 PRICING_MODE_INVALID, derived when omitted), empty-string descriptions stored as NULL; the response event row gains `timezone` and `pricingMode`. The live app sends none of them, so its create behaves as before (UTC, derived mode) |
| `GET /event` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/event_repository.dart:37`<br>`flutter_app/lib/app/modules/club_owner_side/owner_home/repository/owner_stats_repository.dart:86` | - | Flutter only |
| `PUT /event/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/event_repository.dart:85` | - | Flutter only. T-012: missing or foreign id is now 404 NOT_FOUND (a foreign id was 403, which the app treats like 401). T-016: tier objects accept optional `tierType` (omitted keeps the stored value, so the live app never resets a PASS) and a tier with sales cannot be sent with `children` (422 TIER_SECTION_HAS_SALES). T-017: same optional `timezone`, `pricingMode` and empty-string description rules; without them the stored values are kept (a stored pricingMode that no longer fits the new tiers or price is re-derived, never a 422) |
| `GET /ticket-tier-presets` | - | - | New in T-016 (public). Not called by Flutter or Admin yet |
| `GET /cities` | - | - | New in T-033 (public). Not called by Flutter or Admin yet |
| `GET /admin/cities`, `POST /admin/cities`, `PATCH /admin/cities/{id}` | - | - | New in T-033 (admin cookie; POST and PATCH also need the CSRF header). The admin Cities page is T-071, not built |
| `GET /event/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/event_repository.dart:48` | - | Flutter only. T-012: missing or foreign id is now 404 NOT_FOUND (was 500) |
| `POST /event/{id}/duplicate` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:448` | - | Flutter only |
| `PUT /event/{id}/bookings/close` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:456` | - | Flutter only |
| `GET /admin/event` | - | `admin/src/apis/events.api.ts:28` | Admin only |

### eventModule

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /event/{eventId}/modules` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:217` | - | Flutter only |
| `GET /event/{eventId}/modules` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:197` | - | Flutter only |
| `POST /event/{eventId}/modules/reorder` | - | - | **UNUSED** |
| `POST /event/{eventId}/modules/{id}/duplicate` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:239` | - | Flutter only |
| `PUT /event/{eventId}/modules/{id}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:212` | - | Flutter only |
| `DELETE /event/{eventId}/modules/{id}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:229` | - | Flutter only. T-013: a module with purchases is now 409 (was 500); the app maps 4xx to a validation error with the server message, so no client depended on the 500 |

### guestList

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /event/{eventId}/guest-list` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:249` | - | Flutter only |
| `PUT /event/{eventId}/guest-list` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:298` | - | Flutter only |
| `POST /event/{eventId}/guest-list/join` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:59` | - | Flutter only. T-020: a repeat join while a PENDING or CONFIRMED entry exists returns 409 GUEST_LIST_DUPLICATE (shown as a message; not tested in the app). |
| `GET /event/{eventId}/guest-list/entries` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:278` | - | Flutter only |
| `PUT /event/{eventId}/guest-list/entries/{id}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:329` | - | Flutter only |

### hosts

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /hosts` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:411` | - | Flutter only |
| `GET /hosts` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:337` | - | Flutter only |
| `PUT /hosts/{id}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:406` | - | Flutter only |
| `DELETE /hosts/{id}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:422` | - | Flutter only |
| `POST /hosts/{id}/contact` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:162` | - | Flutter only |
| `GET /event/{eventId}/host-inquiries` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:384` | - | Flutter only |
| `GET /event/{eventId}/hosts` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:347` | - | Flutter only |
| `POST /event/{eventId}/hosts` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:429` | - | Flutter only |
| `DELETE /event/{eventId}/hosts/{hostId}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:397` | - | Flutter only |
| `POST /club/{clubId}/hosts` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:440` | - | Flutter only |

### explore

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /explore` | `flutter_app/lib/app/core/explore/repository/explore_api_repository.dart:13` | - | Flutter only |
| `GET /explore/feed` | `flutter_app/lib/app/modules/user_side/home/widgets/discovery_feed_section.dart:46`<br>`flutter_app/lib/app/modules/user_side/home/views/trending_events_view.dart:72`<br>`flutter_app/lib/app/modules/user_side/home/views/organizers_view.dart:193` | - | Flutter only |
| `GET /explore/genres` | `flutter_app/lib/app/core/explore/repository/explore_api_repository.dart:27` | - | Flutter only |
| `GET /explore/club/{id}/events/upcoming` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/club_community_section.dart:596-598` (path built with `${kind}`; ⚠️ UNVERIFIED which values) | - | Flutter only |
| `GET /explore/club/{id}/events/past` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/club_community_section.dart:596-598` (path built with `${kind}`; ⚠️ UNVERIFIED which values) | - | Flutter only |
| `GET /explore/club/{id}/artists` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/club_community_section.dart:596-598` | - | Flutter only |
| `GET /explore/{id}` | `flutter_app/lib/app/core/explore/repository/explore_api_repository.dart:57`<br>`flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:261,368`<br>`flutter_app/lib/app/modules/club_owner_side/activity/repository/event_repository.dart:61`<br>`flutter_app/lib/app/modules/user_side/home/views/organizer_details_view.dart:31`<br>`flutter_app/lib/app/modules/user_side/club_details_view/controllers/club_details_controller.dart:190` | - | Flutter only |
| `GET /explore/club/{id}` | - | - | Not an API client route - browser share page / app link |
| `GET /explore/event/{id}` | - | - | Not an API client route - browser share page / app link |
| `GET /.well-known/apple-app-site-association` | - | - | Not an API client route - OS app-link verification |
| `GET /.well-known/assetlinks.json` | - | - | Not an API client route - OS app-link verification |

### follow

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /clubs/{clubId}/follow` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/club_community_section.dart:395` | - | Flutter only |
| `DELETE /clubs/{clubId}/follow` | `flutter_app/lib/app/core/explore/repository/discovery_repository.dart:45`<br>`flutter_app/lib/app/modules/user_side/club_details_view/widgets/club_community_section.dart:393` | - | Flutter only |
| `GET /clubs/{clubId}/is-following` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/club_community_section.dart:370` | - | Flutter only |
| `GET /me/following` | `flutter_app/lib/app/modules/user_side/home/views/organizers_view.dart:193` | - | Flutter only |

### artists

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /artists/{id}/follow` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:16` | - | Flutter only |
| `DELETE /artists/{id}/follow` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:21` | - | Flutter only |
| `GET /me/artists` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:31` | - | Flutter only |

### wishlist

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /wishlist` | `flutter_app/lib/app/modules/user_side/favorite/repository/wishlist_repository.dart:40` | - | Flutter only. T-013: a missing or unavailable target is now 404 NOT_FOUND (was 500); no client depended on the 500 (the admin app does not call the wishlist) |
| `GET /wishlist` | `flutter_app/lib/app/modules/user_side/favorite/repository/wishlist_repository.dart:24` | - | Flutter only |
| `DELETE /wishlist/{type}/{targetId}` | `flutter_app/lib/app/modules/user_side/favorite/repository/wishlist_repository.dart:58` | - | Flutter only |

### reviews

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /reviews/{clubId}` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_review_repository.dart:25` | - | Flutter only |
| `POST /reviews` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_review_repository.dart:45` | - | Flutter only |

### quotes

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /quotes` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:86` | - | Flutter only |
| `GET /quotes` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:133` | - | Flutter only |
| `PUT /quotes/{id}` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:147` | - | Flutter only |

### promo

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /promo/validate` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:219` | - | Flutter only |
| `GET /promo` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/promo_repository.dart:16` | - | Flutter only |
| `POST /promo` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/promo_repository.dart:36` | - | Flutter only |
| `PUT /promo/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/promo_repository.dart:75` | - | Flutter only |
| `DELETE /promo/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/promo_repository.dart:108` | - | Flutter only |

### waitingList

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /waiting-list/join` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/waiting_list_panel.dart:129` | - | Flutter only |
| `POST /waiting-list/leave` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/waiting_list_panel.dart:568` | - | Flutter only |
| `GET /waiting-list/my` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/waiting_list_panel.dart:363` | - | Flutter only |
| `GET /waiting-list/club/{clubId}/status` | `flutter_app/lib/app/modules/user_side/club_details_view/widgets/waiting_list_panel.dart:58,534` | - | Flutter only |
| `GET /waiting-list/club/{clubId}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/owner_waiting_list_repository.dart:18` | - | Flutter only |
| `POST /waiting-list/{id}/notify` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/owner_waiting_list_repository.dart:30` | - | Flutter only |
| `DELETE /waiting-list/{id}` | `flutter_app/lib/app/modules/club_owner_side/activity/repository/owner_waiting_list_repository.dart:52` | - | Flutter only |

### purchase

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /purchase/club/availability` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:145` | - | Flutter only |
| `POST /purchase/club` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:244` | - | Flutter only |
| `POST /purchase/event` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:172` | - | Flutter only |
| `POST /purchase/module` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:196` | - | Flutter only |

### payment

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /payment/intent` | `flutter_app/lib/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart:261` | - | Flutter only |

### webhook

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /webhooks/payment/stripe` | - | - | Not an API client route - server-to-server (Stripe) |

### connect

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `POST /connect/onboarding` | `flutter_app/lib/app/modules/club_owner_side/stripe_connect/repository/stripe_connect_repository.dart:20` | - | Flutter only |
| `GET /connect/status` | `flutter_app/lib/app/modules/club_owner_side/stripe_connect/repository/stripe_connect_repository.dart:32`<br>`flutter_app/lib/app/modules/authentication/controllers/sign_in_controller.dart:198` | - | Flutter only |
| `GET /connect/return` | - | - | Not an API client route - browser redirect from Stripe |
| `GET /connect/refresh` | - | - | Not an API client route - browser redirect from Stripe |
| `POST /connect/webhook` | - | - | Not an API client route - server-to-server (Stripe) |

### bookings

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /bookings` | `flutter_app/lib/app/modules/user_side/booking/repository/booking_repository.dart:29` | - | Flutter only |
| `GET /bookings/{id}` | `flutter_app/lib/app/modules/user_side/booking/repository/booking_repository.dart:49` | - | Flutter only |
| `GET /bookings/{id}/ticket` | `flutter_app/lib/app/modules/user_side/booking/repository/booking_repository.dart:71` | - | Flutter only |
| `GET /bookings/{id}/ticket/file` | `flutter_app/lib/app/modules/user_side/booking/repository/booking_repository.dart:66` | - | Flutter only |

### owner

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /owner/dashboard` | `flutter_app/lib/app/modules/club_owner_side/owner_home/repository/owner_stats_repository.dart:22` | - | Flutter only |
| `GET /owner/earnings` | `flutter_app/lib/app/modules/club_owner_side/owner_home/repository/owner_stats_repository.dart:32` | - | Flutter only |
| `GET /owner/payments` | `flutter_app/lib/app/modules/club_owner_side/owner_home/repository/owner_stats_repository.dart:72` | - | Flutter only |
| `POST /owner/verify-ticket` | `flutter_app/lib/app/modules/club_owner_side/ticket_scanner/repository/ticket_scanner_repository.dart:68` | - | Flutter only. T-011: business failures are now 404/409/422 (were 500); the scanner screen shows the server message for any 4xx and a generic text for 5xx, and 401/403 are not used, so no logout path is triggered |
| `GET /owner/bookings/export` | `flutter_app/lib/app/core/explore/repository/event_commerce_repository.dart:480` | - | Flutter only |

### public-web

| Endpoint | Used by Flutter | Used by Admin | Status |
|---|---|---|---|
| `GET /health` | - | - | Not an API client route - ops / load balancer |
| `GET /api-docs` | - | - | Not an API client route - browser (Swagger UI) |
| `GET /` | - | - | Not an API client route - browser redirect |
| `GET /website` | - | - | Not an API client route - browser static page |
| `GET /marketing` | - | - | Not an API client route - browser static page |
| `GET /support` | - | - | Not an API client route - browser static page |
| `GET /privacy-policy` | - | - | Not an API client route - browser static page |
| `GET /connect/complete` | - | - | Not an API client route - browser page / app link fallback |

## 4. Unused API routes (no client call found)

- `GET /auth/roles`
- `POST /auth/refresh`
- `GET /admin/profile`
- `PATCH /admin/users/{id}/restore`
- `GET /profile/deletion-preview`
- `PUT /club/{id}/bookings/close`
- `POST /event/{eventId}/modules/reorder`

## 5. Client references with no matching backend route, and other notes

- Flutter `EndPoint.GOOGLE_LOGIN = '/auth/google'` (`flutter_app/lib/app/core/network/end_point.dart:12`): no backend route; nothing calls it (Google sign-in uses `/auth/social`).
- Flutter `EndPoint` also has a constant for `/event/{eventId}/modules/reorder`; it is never used.
- Flutter builds `/explore/club/{id}/events/${kind}` (`club_community_section.dart:597`); the backend serves only `upcoming` and `past`. ⚠️ UNVERIFIED which values `kind` takes.
- Flutter calls `/auth/*` and `/recover/*` flows but never `POST /auth/refresh`; the refresh token is stored and unused.
- Admin reuses the user-facing `/recover/*` routes and `/media` (no admin-specific versions).
- Both clients call `/media` upload and delete; the route has no auth (see `known-issues.md` S-01). `DELETE /media` body validation runs since T-014 (S-18); Flutter (`media_service.dart:69`) and Admin (`media.api.ts:21`) both send `{urls: [string]}`.
- Flutter calls Google Places (New) directly: `POST https://places.googleapis.com/v1/places:autocomplete` and `GET https://places.googleapis.com/v1/places/{placeId}` (`explore_repository.dart:255,302`, `club_location_repository.dart:34,82`). Not a backend route.
- Admin pages still on mock data: Notifications (`features/notifications/api/mock.ts`) and `useGetDashboardMetrics` (`features/dashboard/api/dashboard.api.ts`); the backend has no admin notifications endpoint. Unused mock files: `features/{clubs,events,earnings,settings}/api/mock.ts`.
- Flutter does not use Socket.IO or any `/socket` route; the Admin app does not either.
- Admin app base URL `VITE_API_URL` points at `https://ibady.nazmul.qzz.io/api/v1`; Flutter uses `BASE_URL` from a bundled `.env` (not on disk).

## 6. Spot checks

- Script check: all cited files exist and all line numbers are within the file (no orphan references, no route without a spec entry).
- Keyword check (cited line plus or minus 5 lines contains the endpoint word) on 11 sampled references: 11 of 11 matched. Sampled: `auth_repository.dart:33`, `club_purchase_repository.dart:172`, `wishlist_repository.dart:58`, `event_commerce_repository.dart:480` and `:406`, `promo_repository.dart:75`, `owner_waiting_list_repository.dart:30`, `ticket_scanner_repository.dart:68`, `admin/src/apis/users.api.ts:82`, `admin/src/configs/axios.configs.ts:66`, `admin/src/apis/commission.api.ts:90`.
- The remaining references are from the subagent scan and stay **⚠️ UNVERIFIED** at line level.
