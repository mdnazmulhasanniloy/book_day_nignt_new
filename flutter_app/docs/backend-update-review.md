# Backend integration: v2.0.0 follow-up (27 Oct 2026)

The app stays on the black / gold UI, existing navigation, and deep links.
Event guest list, VIP modules, quotes, VIP hosts, mood filters, and artist
follow are **not** in the app. Those APIs still do not exist.

## Wired to the contracts that just shipped

1. **Club waiting list**
   - `POST /waiting-list/join` treats HTTP 201 as success for a new join and
     for an already-PENDING user. Position is read from `data` / status.
   - The app does not require 200 or 409 and does not special-case 404 on join.
   - `GET /waiting-list/my` uses `club.thumbnail` (not `coverImage`).
   - `GET /waiting-list/club/{id}/status` uses `{ isWaiting, position, entry }`.
   - This remains a **club-wide** queue, not a hold for a selected interval.

2. **Owner promo list**
   - `GET /promo?page&limit` uses the same bearer token as `POST /promo`.
   - `discountValue` is parsed as a decimal string (`"10.00"`).
   - `POST /promo/validate` still expects numeric discount fields.

3. **Owner event edit**
   - Hydration uses **owner** `GET /event/:id` only (no public-explore merge,
     so inactive tiers are not dropped).
   - Tiers: `groupName`, `description`, `soldCount`, `startAt`, `endAt`,
     `isActive`. Sold out = `soldCount >= capacity`.
   - Lineup: `id`, `audioPreviewUrl`, Spotify / SoundCloud open externally.
   - Create/update stay `POST /event` and `PUT /event/:id` with `eventName`,
     `eventDescription`, optional `clubId`, and `categoryType`.

4. **Push and inbox**
   - FCM `notificationType` is the routing key.
   - `CLUB_SEAT_AVAILABLE` + `clubId` opens that club. `CLUB_WAITING_LIST` is
     not used.
   - Booking types with `orderId` + `serviceType` (`EVENT` or `CLUB`) open
     booking details: `BOOKING_CONFIRMED`, `CLUB_BOOKING_CONFIRMED`,
     `PAYMENT_FAILED`, `TICKET_AVAILABLE`, `NEW_CLUB_BOOKING`,
     `NEW_TICKET_SALE`, plus refund/payout types when those ids are present.
   - Anything else opens the inbox.
   - Inbox fields: `notificationType`, `notificationTitle`,
     `notificationDescription`, `metaData`, `isRead`.

5. **Auth**
   - Login/social store `data.token`. Unverified users keep that token for OTP.
   - `POST /auth/check` sends `deviceIdentifier`, `lat`, `lng`, `platform`,
     optional `fcmToken`. It does not mint a new token. There is no
     `/auth/refresh-token`.

6. **Explore**
   - `type` remains `CLUB` or `EVENT`.
   - `categoryType`: `CLUB`, `CONCERT`, `FESTIVAL`, `OPEN_AIR`, `WAREHOUSE`.
   - Date chips send `dateFilter` (`today`, `tomorrow`, `this_weekend`,
     `next_weekend`). Custom dates still send `date`.
   - Free sends `isFree=true`. Genres send `genres` as a comma-separated string.
   - No mood query.

7. **Errors**
   - HTTP 201–299 succeed. Every non-2xx is failure.
   - 401/403 clear the session. 422 reads `errors[].field` + `message`.
   - 500 uses the server `message` (currently often "Internal Server Error").

## Still out of scope (no API)

- Event guest list, VIP service modules, quote requests, VIP hosts
- Mood filter, artist follow, Spotify account connect
- Nested ticket-pass objects (only `groupName` on a flat tier row)
- Apple Pay as a separate method (Stripe PaymentSheet only)

## Device checks still needed

- Real Android/iOS push taps (`CLUB_SEAT_AVAILABLE`, booking types)
- Live Stripe PaymentSheet / Apple Pay
- Waiting-list join against a live club after the 201 fix
