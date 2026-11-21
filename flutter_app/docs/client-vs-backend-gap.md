# BookDiaNight — Client brief vs Backend v2.0.0 vs App

**Date:** 27 Oct 2026  
**For:** Backend + product  
**App base:** Flutter customer + club-owner app against `https://bookdianight.localbox.online/api/v1`

The client brief, the Shotgun-style screenshots, and Integration Guide **v2.0.0** describe three different products. The app is aligned with **v2.0.0**, not with the full VIP / guest-list platform in the client brief.

---

## 1. Bottom line

| Source | What it actually is |
| --- | --- |
| Client brief | Full event commerce OS: VIP modules, guest list, quotes, VIP hosts, sold-out fallbacks, realtime inventory, CRM |
| Shotgun screenshots | Discovery UX (date/mood/type chips, artist follow, Spotify, grouped ticket passes) |
| Backend v2.0.0 | Club + event tickets + club **table packages** + **club-table waiting list** + promo + Stripe |
| Current app | Implements v2.0.0. Cannot ship the client brief without new APIs |

**App cannot invent endpoints.** Anything in section 3 must be built on backend first, or explicitly cut from scope.

---

## 2. Already covered (v2.0.0 ↔ app)

Customer app:

- Auth + `deviceIdentifier` + FCM + `POST /auth/check`
- Explore list, genres, city/date/price filters, `GET /explore/feed` (today / tomorrow / blowingUp / popularOrganizers / genres)
- Club details: follow, upcoming/past events, artists
- Event details: name, date/hours, venue, description, images, dress code, lineup, ticket tiers, book/pay
- Club table booking: availability → 15-min hold → Stripe
- Club waiting list: join / leave / status / my (API wired; **join + my currently 500**)
- Event purchase + `POST /promo/validate` + `promoCode` on `POST /purchase/event`
- My Bookings, door QR = raw `orderId`, ticket PDF download
- Notifications, wishlist, reviews

Owner app:

- Stripe Connect onboarding (`returnUrl` / `refreshUrl`)
- Club CRUD + table packages
- Event CRUD + ticket tiers + lineup (`POST /event`)
- Promo create (`POST /promo`) — **list `GET /promo` is 404**
- Dashboard / earnings (`startDate`/`endDate`) / payments
- Door QR scanner `POST /owner/verify-ticket`

---

## 3. Client brief — **no API in v2.0.0** (blocked)

Please confirm: **build these**, or **out of scope**.

### 3.1 Event VIP services / pricing modules

Needed on each event, duplicable, reorderable, with status `available | limited | sold_out | unavailable`:

- service name, image, description
- max guests, starting price, min spend, deposit
- quantity, venue area
- included extras / optional extras
- Book Now **and** Request a Quote
- Example types: Daybed, Skybar Table, Villa, Bottle Service, Birthday Package, VIP Entry, …

Closest existing object: **club table `packages`** (name, description, capacity, price, features). That is club-level, not event-level, and has no quote, deposit, min spend, quantity, extras, or sold-out status.

**Ask backend**

- Event-scoped VIP modules CRUD (create / edit / reorder / duplicate / disable)
- Duplicate module onto another event
- Public read on event details
- Book vs quote endpoints
- Realtime quantity + status

### 3.2 Join the Guest List (event)

Client wants per-event config (days, cut-off, arrival times, M/F caps, free spots, dress code, ID, notes) and a registration form (name, email, phone, men/women counts, T&Cs).

v2.0.0 rule: *Waiting list is for club tables only. It does not apply to events.*

**Ask backend**

- Event guest-list config + public form submit
- Capacity / gender-rule validation
- Email/WhatsApp confirmation
- Admin list + remaining spots

### 3.3 Sold-out guest list → paid alternatives

When guest list closes, CTAs should switch to paid entry / VIP / bottle / table / cabana / waiting list, with clubs linking paid services to that guest list.

**No model for this.** Ticket tiers can sell out independently; they are not linked as guest-list fallbacks.

### 3.4 VIP host / promoter

“Book Directly with an Official VIP Host”: name, role, verified badge, official prices, WhatsApp / phone / email / request-info.

**No host/promoter resource.** Club follow is not a VIP host.

### 3.5 Compare VIP Options

Card grid: image, capacity, starting price, View Details, Request a Quote.

Blocked until 3.1 exists.

### 3.6 Owner dashboard extras from the brief

Missing vs v2.0.0:

- Duplicate event
- Guest-list + waiting-list admin
- Male/female caps
- Manual close bookings
- Mark VIP module sold out
- Export bookings
- Manage VIP hosts
- Quote-request inbox

Owner can already: create/edit events, table packages, ticket tiers, promo (create only), mark event inactive, view bookings/earnings, scan tickets.

### 3.7 Other brief items with no fields

| Client item | v2.0.0 |
| --- | --- |
| Event videos | Images only (`thumbnail`, `images`) |
| Minimum age | Not on event/club |
| Venue map widget | `lat`/`lng` exist; no map payload |
| Quote-request + contact CTAs | Not present |
| WhatsApp / CRM / multilingual | Not present |
| Filters by capacity / area | Explore has type, date, city, genre, min/max price |

---

## 4. Shotgun screenshots — also not in v2.0.0

Do **not** treat these as current API work unless product adds contracts.

- Mood filter
- Type chips: Club / Concert / Festival / Open air / Warehouse
- Artist follow (Spotify-style)
- Spotify / SoundCloud connect on home
- “You might like” artist rails
- Grouped ticket passes (Pass 2 jours → nested day tickets + sold-out per row)
- Service-fee legal sheet as a backend product (app can show `GET /service-charge` locally)
- Apple Pay as a dedicated method (Stripe PaymentSheet can surface it if Stripe + Apple are configured)

Explore already supports: city, date, genre, price (Free / Max €15 / range), Club vs Event.

---

## 5. Previously broken contracts — app now matches the shipped fixes

| Endpoint | App behavior |
| --- | --- |
| `POST /waiting-list/join` | HTTP 201 success for new and already-PENDING. Reads `data.position`. No 200/409 requirement. No 404 branch. |
| `GET /waiting-list/my` | Paginated PENDING rows. Uses `club.thumbnail`. |
| `GET /waiting-list/club/{id}/status` | `{ isWaiting, position, entry }` |
| `GET /promo` | Owner list. Parses `discountValue` decimal strings. |
| `GET /event/:id` | Owner edit hydrates all tiers (including inactive) and lineup from this call only. |

Login stores `data.token`. `POST /auth/check` sends `deviceIdentifier`, `lat`, `lng`, `platform`, optional `fcmToken`. Club availability/purchase datetimes still end in `-06:00`.

---

## 6. Minimum backend if the client brief is in scope

Suggested order (do not start Flutter UI for these until contracts exist):

1. **Event VIP module** resource + public list on event details + book/quote  
2. **Event guest list** config + submit + remaining capacity  
3. Sold-out guest list → linked paid modules + waiting-list option  
4. **VIP host** on event/club + contact channels  
5. Owner: duplicate event/module, export bookings, manual sold-out/close  
6. Optional: event video, minAge, mood/type taxonomy

Until 1–3 ship, the event page stays: **info + ticket tiers + (club) table packages**.

---

## 7. App-only leftovers (no new backend)

Safe to do in Flutter against current APIs:

- Date-picker sheet UX (This weekend / calendar) on existing `date` query
- Event map from `lat`/`lng`
- Stronger sold-out badges on ticket tiers if capacity/sold fields are returned
- Device QA: push tap, Stripe PaymentSheet / Apple Pay, live checkout

**Not** safe to fake: guest list, VIP modules, quote, VIP host, mood, artist follow, event waiting list.
