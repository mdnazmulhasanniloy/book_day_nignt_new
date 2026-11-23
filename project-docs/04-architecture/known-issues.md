# Known Issues (as-is)

> List only. Nothing here has been fixed or changed. Found while reverse-engineering `backend/`, `admin/` and `flutter_app/` (Flutter).
> Severity is a first-pass judgement: **High** = exploitable or data-loss/money impact, **Med** = wrong behaviour or weak control, **Low** = hygiene.
> "Verified" means the file was read directly in this session; otherwise the finding comes from a code-reading subagent and is marked **⚠️ UNVERIFIED** until re-checked.

## 1. Security

| ID | Sev | Location | Issue | Status |
|---|---|---|---|---|
| S-01 | High | `backend/server/src/app/modules/media/media.routes.ts:15-25` | `POST /media` (upload up to 10 files) and `DELETE /media` (delete S3 objects by URL, `media.services.ts:38`) have no auth middleware. Anyone can upload to or delete from the bucket. | Verified (routes); service behaviour ⚠️ UNVERIFIED |
| S-02 | High | `backend/server/src/app/modules/promo/promo.routes.ts:37-66`, `promo.services.ts:18-22,109` | Promo create/update/delete need only a logged-in USER (comment says "Admin or authenticated owner"). No role check and no ownership check on `eventId` / `clubId`; global codes (no event or club) appear editable and deletable by any user. | Routes verified; service behaviour ⚠️ UNVERIFIED |
| S-03 | High | `backend/server/src/app/modules/auth/auth.schema.ts:22` | `POST /auth/signup` accepts `role: 'CLUB_OWNER'` from the client, so anyone can self-assign the owner role. | Verified |
| S-04 | High | `backend/server/src/app/middlewares/socket.middlewares.ts:48`, `modules/auth/auth.middlewares.ts:77`, `const.ts:294` | Blacklist key mismatch: middlewares read `blacklist:jwt:<token>` but the key prefix in `const.ts` is `blacklist:token`. Logout writes `blacklist:token:<token>` (**⚠️ UNVERIFIED**), so these two checks never see revoked tokens (socket auth and the OTP-page token check). Whether the normal HTTP user middleware blacklists correctly was not checked. | Mismatch verified; impact ⚠️ UNVERIFIED |
| S-05 | High | `flutter_app/lib/main.dart:52,121-127` | `MyHttpOverrides.badCertificateCallback` returns `true` and is installed globally, so the app accepts any TLS certificate for all requests (man-in-the-middle possible). | Verified |
| S-06 | High | `backend/bookdianight.dump`, `backend/dump.rdb` | A Postgres dump (191 KB) and a Redis dump are tracked in git (`git ls-files`), and `.gitignore` does not exclude them. They may contain PII, hashes, tokens or sessions. | Tracked: verified; contents ⚠️ UNVERIFIED |
| S-07 | Med | `backend/server/src/app/utils/jwt.utils.ts:16-37` | User and admin access tokens are signed with the same `JWT_ACCESS_TOKEN_SECRET_KEY`. Role separation then depends only on server-side checks. | Verified |
| S-08 | Med | `backend/server/src/app/modules/quotes/quotes.routes.ts:28`, `hosts/hosts.routes.ts:74` | `POST /quotes` and `POST /hosts/:id/contact` are public with no rate limit and trigger emails to owners or hosts (spam and email-bombing). | ⚠️ UNVERIFIED |
| S-09 | Med | `backend/server/src/app/modules/promo/promo.routes.ts:28` | `POST /promo/validate` is public with no rate limit; codes can be enumerated. | Route verified |
| S-10 | Med | `flutter_app` `lib/app/core/local_storage/local_storage.dart`, `sign_in_controller.dart:93,384-386` | Access token, refresh token and, with "remember me", the plain-text password are stored in unencrypted GetStorage. | ⚠️ UNVERIFIED |
| S-11 | Med | `flutter_app` `lib/main.dart:33,41`, Dio interceptor in `core/network/base_client.dart` | Debug logging prints the access token, the FCM token, and full request/response bodies (including passwords). | ⚠️ UNVERIFIED |
| S-12 | Med | `flutter_app` `.env` listed as an asset in `pubspec.yaml`; `explore_repository.dart`, `club_location_repository.dart` | `.env` is bundled in the app package, so `MAP_API_KEY` and the Stripe publishable key can be extracted. Google Places is called directly from the client with `X-Goog-Api-Key`, so that key needs app and API restrictions. | ⚠️ UNVERIFIED |
| S-13 | Med | `flutter_app` `lib/firebase_options.dart:44-80`, `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json` | Firebase API keys committed in the app. Normal for Firebase, but restrictions in the console cannot be confirmed from code. | ⚠️ UNVERIFIED |
| S-14 | Low | `backend/.agent/blueprint.md` | Contains the production droplet IP and SSH user. Values are intentionally not copied here. | ⚠️ UNVERIFIED |
| S-15 | Low | `backend/server/src/const.ts` (`corsWhiteList`), `app.ts:173`, `server.ts:25` | Dev tunnel and LAN origins in the production CORS whitelist; hardcoded host `https://ibady.nazmul.qzz.io` in Swagger config. | ⚠️ UNVERIFIED |
| S-16 | Low | `backend/server/src/app/modules/notification/notification.routes.ts:41` | `PATCH /notifications/:id/read` has no params schema (see V-01). | ⚠️ UNVERIFIED |
| S-17 | High | `backend/server/src/app/modules/admin/admin.services.ts:439-540` (`getAdminUsersService`) | `GET /admin/users` loads users with `include` (all scalar fields) and returns `...restUser`; the `password` hash is not stripped (other admin functions at lines 68, 92, 202, 253 do strip it). Every listed user's bcrypt hash is sent to the admin client. | Verified |
| S-18 | Med | `backend/server/src/app/utils/system.utils.ts:117-123`, `media.routes.ts` | `validateReqBody` only validates POST, PUT and PATCH (`ALLOWED_WRITE_METHODS`), so the `deleteMediaSchema` on `DELETE /media` is never applied; `req.body.urls` reaches the controller unvalidated. Same applies to any other DELETE route that relies on `validateReqBody`. | Verified |
| S-19 | High | `backend/server/src/app/modules/recover/` | `POST /recover/reset` needs only the reset-page token; the OTP check is reportedly not enforced server-side at that step. | ⚠️ UNVERIFIED (subagent) |
| S-20 | Med | `owner` module, `GET /owner/bookings/export` | The exported CSV is uploaded to S3 with a public-read ACL and the URL is returned as `downloadUrl`; the file contains booking data. | ⚠️ UNVERIFIED (subagent) |
| S-21 | Med | `owner` module | `GET /owner/bookings/export` and `POST /owner/verify-ticket` have no Connect readiness check (other owner routes do). | ⚠️ UNVERIFIED (subagent) |
| S-22 | Low | `admin` routes | CSRF header is required on `/admin/dashboard`, `/admin/users`, `/admin/earnings` (GETs) but not on `GET /admin/profile` or `GET /admin/commission`; inconsistent. | ⚠️ UNVERIFIED (subagent) |

## 2. Bugs and correctness

| ID | Sev | Location | Issue | Status |
|---|---|---|---|---|
| B-01 | Med | `backend/prisma/schema.prisma:802` | `ClubWaitingList @@unique([userId, clubId, status])`: a user can hold only one CANCELLED (or NOTIFIED) row per club, so a second join-then-cancel cycle violates the constraint. | Verified in schema; runtime effect ⚠️ UNVERIFIED |
| B-02 | Med | `schema.prisma` Club/Event `geog`; `club.services.ts:49,189`, `event.services.ts:39,215,582` | `geog` is filled only by raw SQL in specific code paths. Rows written elsewhere have `geog` NULL and never appear in `ST_DWithin` nearby searches (`explore.services.ts:54,99`). | ⚠️ UNVERIFIED |
| B-03 | Med | migration `20261101051000_allow_event_module_purchase` | `EventModulePurchase` lacks the snapshot immutability trigger that its sibling purchase tables have. | Reported from migration reading |
| B-04 | Med | `schema.prisma:13` vs migration `20260923111443_booking_payment_foundation` | `btree_gist` is created by a migration (needed by the `ClubBooking` EXCLUDE constraint) but is missing from the schema `extensions` list. `prisma migrate dev` may report drift or try to drop it. | Schema line verified; migrate behaviour ⚠️ UNVERIFIED |
| B-05 | Low | `backend/server/src/const.ts:49` vs `jwt.utils.ts:16-26` | `userAccessTokenExpiresIn = '30d'` while the token code hardcodes `7d` / `30d`. | Verified; whether the constant is used ⚠️ UNVERIFIED |
| B-06 | Low | `backend/.env.example` | Missing `SERVER_URL`, which `server/src/env.ts` requires (`getEnv` throws if missing). | ⚠️ UNVERIFIED |
| B-07 | Med | `flutter_app` `lib/app/core/network/base_client.dart` | `_handleUnauthorized()` is an empty stub: a 401 never logs the user out or redirects. | ⚠️ UNVERIFIED |
| B-08 | Med | `flutter_app` auth repository | The app saves `refreshToken` but never calls `POST /auth/refresh`; after the access token expires the user must log in again. | ⚠️ UNVERIFIED |
| B-09 | Low | `flutter_app/lib/main.dart:36-37,45-58` | `AppConfig.init()` and `BaseClient().init()` are called twice; Stripe publishable key is also set again in `buy_ticker_controller.dart`. | ⚠️ UNVERIFIED |
| B-10 | Low | `flutter_app` `club_community_section.dart:597` | Builds `/explore/club/{id}/events/${kind}`; the backend accepts only `upcoming` and `past`. | ⚠️ UNVERIFIED |
| B-11 | Low | `flutter_app` `lib/app/config/flavor_config.dart` | `isProduction` hardcoded to `true`, so `LOCAL_BASE_URL` is never used. | ⚠️ UNVERIFIED |
| B-12 | Low | `backend/scheduler/src/app/jobs/` | No distributed lock: with more than one scheduler instance, hourly reminders and the minute-by-minute status sync are enqueued more than once (some jobs use deterministic jobIds, others may not). | ⚠️ UNVERIFIED |
| B-13 | Low | migrations `20261101163000_waiting_list_slot_context`, `20261102104500_guest_list_entry_notifications` | Use `IF NOT EXISTS`, which suggests they were applied by hand somewhere before being committed. | Inference, ⚠️ UNVERIFIED |
| B-14 | Low | `schema.prisma:168` vs `:102` | Spelling inconsistency: `WaitingListStatus.CANCELLED` vs `EventStatus.CANCELED` / `NotificationType.EVENT_CANCELED`. | Verified |
| B-15 | Med | `owner` module, `POST /owner/verify-ticket` | Business failures (not found, not the seller, not paid, refunded, already used) throw plain `Error`s with no `statusCode`, so the global handler returns 500 "Internal Server Error" and the intended messages never reach the scanner app. | Fixed in code (T-011, tested locally, not deployed): unknown or foreign order 404 TICKET_NOT_FOUND, not PAID or refunded 422 TICKET_NOT_VALID, already used 409 TICKET_ALREADY_USED (+ usedAt). Confirmed by test: all were 500. Still open: a refund of any type blocks entry until T-064; an order with no purchase row still 500s. |
| B-16 | Med | `webhook` and `connect` Stripe webhooks | A missing or invalid Stripe signature throws a plain `Error`, giving 500 instead of 400. Stripe will retry. | ⚠️ UNVERIFIED (subagent) |
| B-17 | Med | `admin` module, `POST /admin/auth/refresh` | Throws `{ status: 401 }` (key `status`, not `statusCode`), so the global handler converts it to 500. The Admin SPA's 401-refresh logic depends on this route. | Fixed in code (T-010, tested locally, not deployed): service throws `statusCode: 401` TOKEN_INVALID. Confirmed by test: before the fix a validly signed token with no live session returned 500. |
| B-18 | Low | `admin` module, `PATCH /admin/users/:id/suspend` | Unknown user id throws a plain `Error` (500) instead of 404. | Fixed in code (T-010, tested locally, not deployed): unknown id returns 404. Confirmed by test: was 500. |
| B-19 | Low | `purchase` module, `POST /purchase/module` | No request-body equivalence check when an idempotency key is replayed (club and event purchases have one). | ⚠️ UNVERIFIED (subagent) |
| B-20 | Low | `admin` module | `GET /admin/commission` returns `data = { EVENT, CLUB }` but `PATCH` returns `data = { commission }`; `GET /profile` adds `registrationState`, `PATCH /profile` does not. Inconsistent shapes. | ⚠️ UNVERIFIED (subagent) |
| B-21 | Low | `auth`, `recover` routes | `/auth/check`, `/auth/logout`, `/recover/verify`, `/recover/reset` validate the body before the token checks; `/auth/login` checks account status before the password (reveals account state to anyone who knows the email). | ⚠️ UNVERIFIED (subagent) |
| B-22 | Low | `admin` module, `/admin/users`, `/admin/earnings` | Non-numeric `page` / `limit` (`parseInt` in `admin.services.ts:441-442` gives `NaN`) likely causes a 500. | Fixed in code (T-010, tested locally, not deployed): Zod query schema, positive integers, limit at most 100, else 422. Confirmed by test: invalid values were 500 or accepted (1.5, 1abc, 101). |
| B-23 | Low | `purchase`, `/payment/intent` responses | `traceId` is missing from `/payment/intent` responses and from 422 bodies for query and params validation. | ⚠️ UNVERIFIED (subagent) |
| B-24 | High | `event` module, `PUT /event/:id` | Sending `ticketTiers` or `lineup` deletes and recreates the rows, so `EventTicketTier.soldCount` resets to 0 and any existing tier references are lost. | ⚠️ UNVERIFIED (subagent) |
| B-25 | Med | `event` module, `POST /event/:id/duplicate` | Duplicated events are created without PostGIS `geog`, so they are missing from geo-filtered `/explore` results (see B-02). | ⚠️ UNVERIFIED (subagent) |
| B-26 | Med | `club`, `event`, `eventModule`, `promo` services | Prisma not-found and FK errors are not mapped, so `GET /club/:id`, `PUT /club/:id`, `GET /event/:id` for a missing or non-owned id return 500 (not 404/403); `DELETE` of an event module with purchases returns 500 (FK Restrict); promo create/update with a non-existent `eventId`/`clubId` returns 500. | Partly fixed in code (T-012, tested locally, not deployed): `GET/PUT /club/:id` and `GET/PUT /event/:id` return 404 NOT_FOUND for a missing or foreign id (was 500; PUT event foreign id was 403). Confirmed by test. Still open: event module DELETE with purchases (T-013) and promo with unknown `eventId`/`clubId` (T-018). |
| B-27 | Med | `wishlist` module, `POST /wishlist` | Service throws `{ status: 404 }` (wrong key; the handler reads `statusCode`), so a missing target gives 500. Same wrong-key pattern as B-17. | ⚠️ UNVERIFIED (subagent) |
| B-28 | Low | `explore` module | `sort=trending` and the feed's `lat`/`lng` are accepted but ignored; `GET /explore/:id?type=EVENT` increments `viewCount` on every call (no de-duplication). | ⚠️ UNVERIFIED (subagent) |
| B-29 | Low | `guestList` module, `POST /event/:eventId/guest-list/join` | No duplicate-entry check; the same user can submit repeatedly. | ⚠️ UNVERIFIED (subagent) |
| B-30 | Low | `hosts` module, `POST /hosts/:id/contact` | Route accepts an optional token but ignores it, so the inquiry is never linked to the user. | ⚠️ UNVERIFIED (subagent) |
| B-31 | Low | `waitingList` routes | Members, notify and delete routes have no owner-role middleware; ownership is enforced only inside the service (403 "You do not own this club"). | ⚠️ UNVERIFIED (subagent) |
| B-32 | Low | `club`, `event` `/bookings/close`, `/duplicate` | Skip the Stripe Connect readiness check that create/update routes have. | ⚠️ UNVERIFIED (subagent) |
| B-33 | Low | `server/src/app/middlewares/globalError.middlewares.ts` | The global handler keeps only `statusCode`, `message`, `errorType`; any `errors` array or other fields thrown by services are dropped. | ⚠️ UNVERIFIED (subagent) |
| S-23 | Med | `explore` share-preview controllers (`GET /explore/club/:id`, `/explore/event/:id`) | Club and event names are inserted into the HTML unescaped; stored markup in a name would execute on the share page (XSS). Whether owners can store markup is not checked. | ⚠️ UNVERIFIED (subagent) |

## 3. Missing validation

| ID | Sev | Location | Issue |
|---|---|---|---|
| V-01 | Low | `notification.routes.ts:41` | `PATCH /notifications/:id/read` has no params schema; `GET /notifications` and `GET /hosts` have no query schema. ⚠️ UNVERIFIED |
| V-02 | Low | `schema.prisma:369` | `ClubReview.rating` is a `Float` with no range check at DB level. API-level validation ⚠️ UNVERIFIED. |
| V-03 | Low | `schema.prisma:382` | `ClubOpeningHour.dayOfWeek` is an `Int` with no 0 to 6 CHECK. |
| V-04 | Low | `schema.prisma` (many) | `currency` is a free `String` everywhere (no enum, no length check, no DB check that `Order.currency` matches its child rows). |
| V-05 | Low | `schema.prisma:464-471, 763-771` | `Wishlist` and `PromoCode` have both `eventId` and `clubId` nullable with no check that exactly one is set; a `PromoCode` with neither applies globally. |
| V-06 | Low | `schema.prisma:686, 821` | `EventTicketTier.soldCount` and `EventModule.remaining` are counters with no CHECK (`soldCount <= capacity`, `remaining >= 0`). |
| V-07 | Low | `schema.prisma:927` | `EventGuestListEntry.arrivalTime` is a free `String`, not a time. |
| V-08 | Low | `auth.schema.ts` (signup) | Password minimum is 6 characters; no other strength rule seen. |

## 4. Data integrity and schema design

| ID | Sev | Location | Issue |
|---|---|---|---|
| D-01 | Med | `schema.prisma` `EventPurchase` | No link to the ticket tier purchased; `EventTicketTier.soldCount` is a denormalised counter with nothing tying sales to tiers. T-005: columns `ticketTierId`/`ticketTierName` added (nullable, old rows stay NULL); filled by `POST /purchase/event` since T-006 (no-tier purchases stay NULL). T-007: failed or canceled payments release the stock of tier-linked orders (`releaseEventTierStock`); old orders and no-tier purchases still release nothing. T-008: unpaid orders still PENDING_PAYMENT after 15 minutes are released by the worker job `expire-event-ticket-hold` (no scheduler sweep: a lost delayed job leaks stock until one exists; `reports/stock-leak.sql` detects it). |
| D-02 | Med | `schema.prisma:920` | `EventGuestListEntry.userId` has no relation, FK or index. |
| D-03 | Low | `schema.prisma:908` | `EventGuestListFallback.targetId` is polymorphic with no FK; can point at deleted rows. |
| D-04 | Med | `schema.prisma:326,416` vs `:485,498,500,539,564,843` | Deleting a User cascades to Club and Event but is Restricted by Orders, purchases and Stripe account, so a hard delete fails partway. Deletion works only as soft delete (`AccountStatus.DELETED`). |
| D-05 | Med | `schema.prisma:867` | `Quote.module` is Cascade: deleting an `EventModule` silently deletes customer quotes. |
| D-06 | Med | `schema.prisma:679` | `EventTicketTier.parent` is Cascade: deleting a parent tier deletes its children. |
| D-07 | Low | `schema.prisma:846` | `EventModulePurchase.status` reuses `ClubBookingStatus`. |
| D-08 | Low | `schema.prisma:208` | `User.phoneNumber` is required, but social-login users may have none; placeholder values are likely. ⚠️ UNVERIFIED |
| D-09 | Low | `schema.prisma:267` | `Device.deviceIdentifier` is globally unique, so the same device cannot be linked to two accounts. |
| D-10 | Low | `schema.prisma:305` | `LegalContent.legalContentType` is indexed but not unique; duplicate "current" documents are possible. |
| D-11 | Low | `schema.prisma:294-295, 781` | No `(userId, createdAt)` index on `Notification`; `PromoCode @@index([code, isActive])` is redundant with `code @unique`. |
| D-12 | Low | `schema.prisma:343,707,433` | `Club.followerCount`, `Artist.followerCount`, `Event.viewCount` are denormalised with no trigger keeping them in sync. |
| D-13 | Low | `schema.prisma:434` | `Event.eventPrice` is a legacy single price that coexists with `EventTicketTier` prices. |

## 5. Dead and unused code

| ID | Location | Item |
|---|---|---|
| X-01 | `backend/server/src/app/configs/socket.config.ts`, `const.ts` | `chatNameSpace`, `notificationNameSpace` never initialised; `SOCKET_EVENTS` unused; the default namespace has no handlers beyond connect/disconnect. |
| X-02 | `backend/server/src/const.ts` | `baseUrl.v2` unused. |
| X-03 | `flutter_app` | `EndPoint.GOOGLE_LOGIN = '/auth/google'` (`end_point.dart:12`) has no backend route and no callers. |
| X-04 | `flutter_app/pubspec.yaml` | `firebase_auth`, `flutter_map`, `latlong2` listed but not used; `AppConfig.socketUrl` never read; `device_preview` listed (dev package in dependencies, ⚠️ UNVERIFIED). |
| X-05 | `admin/src/features/{clubs,events,earnings,settings}/api/mock.ts` | Mock files that nothing imports. |
| X-06 | `admin/src/features/notifications/api/mock.ts`, `features/dashboard/api/dashboard.api.ts` | Notifications page and `useGetDashboardMetrics` run on mock data; the backend has no admin notifications endpoint. |
| X-07 | Backend routes no client calls (from usage scan) | `/auth/roles`, `GET /admin/profile`, `PATCH /admin/users/:id/restore`, `GET /profile/deletion-preview`, `PUT /club/:id/bookings/close`, `POST /event/:eventId/modules/reorder`. Server-to-server routes are expected to have no client. Full table in `api-usage-map.md`. |
| X-08 | `backend/openapi.yaml`, `backend/server/openapi.yaml` | Two byte-identical copies of the same spec (247,251 bytes); `server/prisma/`, `worker/prisma/`, `scheduler/prisma/` are empty directories used only as mount points. |

## 6. Documentation drift

| ID | Item |
|---|---|
| R-01 | `backend/openapi.yaml` has 85 paths and 99 operations against 139 routes in code (about 70% coverage). Missing: eventModule (6), guestList (5), hosts (10), quotes (3), `/auth/roles`, `/auth/refresh`, `/admin/users/:id/restore`, `/admin/earnings`, `/admin/club`, `/admin/event`, club/event `bookings/close`, `/event/:id/duplicate`, `/purchase/module`, `/owner/bookings/export`, `/profile/deletion-preview`, and artist follow routes. (From exploration; ⚠️ UNVERIFIED until the merged spec is compared.) |
| R-02 | `backend/CLAUDE.md` says to keep both OpenAPI files in sync with code, and that `project-docs/04-architecture/` files do not exist yet; this folder now contains the as-is versions. |
| R-03 | `backend/CLAUDE.md` lists `blockers.md` and a changelog under `project-docs/05-delivery/`; neither exists. |
| R-04 | Earlier task text used a different folder name for the Flutter app; it is now `flutter_app/`. |
| R-05 | Initial exploration counted 39 models and 25 enums; the schema actually has 41 and 26 (`grep`-verified). Treat other subagent counts as ⚠️ UNVERIFIED until re-counted. |
| R-06 | Request validation failures (Zod body, query, params, and a missing `Idempotency-Key`) return HTTP **422**, not 400 (`system.utils.ts:117-140`). The only real 400s seen are bad Connect callback tokens. Existing `openapi.yaml` and any 400-based client handling should be checked against this. (Flutter `BaseClient` maps all 4xx to `ValidationException`, so it works there.) |

## 7. Operations and process

| ID | Item |
|---|---|
| O-01 | Only `server/` has tests (`tsx --test`); worker and scheduler have none (from `CLAUDE.md`). Test coverage not measured. |
| O-02 | Admin API host (`ibady.nazmul.qzz.io`) differs from the production host named in `CLAUDE.md` (`api.bookdianight.com`). ⚠️ UNVERIFIED which is live. |
| O-03 | `redis:latest` and `rediscommander/redis-commander:latest` are unpinned images in `docker-compose.yaml`. |
| O-04 | `lint_results.json` and `admin_dashboard_plan.md` sit in `backend/` root (stray artifacts). ⚠️ UNVERIFIED relevance. |

## 8. Planned disposition (TO-BE, 2026-11-21)

Nothing in this section has been fixed. It records where each item is planned in `05-delivery/implementation-plan.md` and `05-delivery/tasks/`. The tables above stay AS-IS.

| Item | Disposition | Task |
|---|---|---|
| CR-17 standard error codes (correct HTTP status plus a stable `errorType` instead of 500 for business failures) | Resolved by the status-code tasks: B-15, B-17, B-18, B-22, B-26, B-27, S-18 | T-010, T-011, T-012, T-013, T-014 (M1); B-16 in HF-002 |
| S-04 blacklist key mismatch | Hotfix track (verify the writer and readers first) | HF-003 |
| S-01 unauthenticated `/media` upload and delete | Hotfix track. Auth now required (bearer or admin cookie + CSRF). Residual: any signed-in account can delete any URL (no ownership record); DELETE body validation not applied (S-18) | HF-005 |
| S-19 reset password without OTP | Hotfix track (verify first, then fix) | HF-004 |
| S-17 password hash in `GET /admin/users` | Fix already in the baseline code; task is verification (tests run, staging check) | HF-001 |
| B-16 Stripe webhook signature gives 500 | Hotfix track | HF-002 |
| B-21 auth check order | Later: auth cleanup, last task of M2, no dependents | T-021 |
| B-19 module purchase idempotency body check | Built with the module and extras tasks (M5), not as a separate task | T-056 |
| B-20 inconsistent `/admin/commission` response shapes | Skipped: the v2 pricing rules (CR-15) supersede these endpoints; v1 shapes stay as they are and are deprecated | none |
| B-24 tier update resets `soldCount` | M1, in place update with no dependency on migration 5 | T-004 |
| S-03 self-signup as `CLUB_OWNER`, S-21, B-07, B-08, B-10 | Not scheduled in backend/admin: S-03 waits on D1; S-21 belongs to deferred CR-05; B-07, B-08, B-10 are Flutter (M8, not started) | none |
