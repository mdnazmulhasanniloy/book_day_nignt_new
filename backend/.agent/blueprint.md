# BookDiaNight blueprint

Read this file first. Then open only the module you are changing. Do not walk the whole repository again unless this file does not cover that area. If a change moves a boundary listed here, update this file in the same change.

Last verified against the working tree: 2026-11-12.

This file is a map. `GEMINI.md`, `.agent/rules.md`, and `.agent/workflow.md` still win when they conflict with it. Do not put secrets, passwords, or tokens in this file.

## Product

Nightlife ticketing API. Actors: customer, club manager, organizer, admin.

There is no separate ibady codebase. `D:\ongiong\bookdianight-server` is the only repo.

## Two runtimes

| Name | What it is | How code gets there |
|---|---|---|
| Local / ibady | This repo's Docker Compose. `server` bind-mounts `./server` to `/app` and publishes host `5005` to container `5000`. Public URL `https://ibady.nazmul.qzz.io/api/v1` is Cloudflare in front of this machine's port 5005. Postgres host port `5440`. Redis host port `6382`. | Saving a file under `server/`, `worker/`, or `scheduler/` is enough. Nodemon reloads. A Prisma schema change also needs `prisma generate` inside the container and a migration on the local database. |
| Live | `https://api.bookdianight.com`. Droplet `206.189.250.83`, SSH user `deploy`, compose directory `/opt/bookdianight-server`. Images are `bookdianight-server:vps-deploy`, `bookdianight-worker:vps-deploy`, `bookdianight-scheduler:vps-deploy`, `bookdianight-admin:vps-deploy`. Docker network is `bookdianight-server_bookdianight-network`. Nginx proxies the public host to container port 5000. | The live server is a built image, not a bind mount. Build `server/Dockerfile` from the repo root, load it on the droplet, run `prisma migrate deploy` with that image, then `docker compose up -d --no-deps --force-recreate` only the service that changed. |

Do not run `scripts/vps-apply-new-images.sh`. It removes the Postgres volume. Do not `docker compose down -v`. Do not commit, push, or deploy unless the user explicitly asks.

As of 2026-11-12 the auth changes below are in this working tree and were being served by local ibady (`GET /api/v1/auth/roles` returned 200 locally and 404 on live). A production server image was built locally. Copying that image to the droplet was not finished. Treat live as unchanged until `GET /api/v1/auth/roles` returns 200 on `https://api.bookdianight.com`.

## Stack

Express 5, TypeScript, Prisma 6 with PostgreSQL/PostGIS, Redis via ioredis, BullMQ, Zod 4, jsonwebtoken, bcrypt. Mail is queued to the worker and sent with nodemailer. Server unit tests are `tsx --test` on `dob.utils.test.ts` and `otpPolicy.test.ts`. `server` `npm run build` runs those tests, then `tsc`. `noUnusedLocals` and `strict` are on.

## Processes

- `server`: HTTP and Socket.IO. Module shape is route, middleware, Zod schema, thin controller, service. Internal imports use `@/app/...`.
- `worker`: BullMQ consumer only. Email, FCM, PDF, refunds, transfers. Jobs must be idempotent.
- `scheduler`: cron producer only. It enqueues work. It does not run worker jobs.
- `prisma/schema.prisma` is the database source of truth. Migrations are forward-only. Never `migrate reset`. Never edit an old migration.
- API prefix is `/api/v1`, mounted in `server/src/app.ts`. `trust proxy` is `1`. Validation failures return 422 with `errors: [{ field, code, message }]`. Client errors use `{ success: false, message, errorType, traceId }` from `globalError.middlewares.ts`. Status 502 and 503 are included so a missing OAuth config stays 503 instead of becoming a generic 500.

New HTTP files should come from the repo generators (`create:endpoint` and the queue/job generators) when they fit.

## Roles

`AccountRole`: `USER`, `CLUB_OWNER`, `ADMIN`. There is no `ORGANIZER` value. Customer is `USER`. Club manager and event organizer are both `CLUB_OWNER`. Admin is `ADMIN`.

`AccountStatus`: `ACTIVE`, `INACTIVE`, `BLOCKED`, `DELETED`.

`AuthProvider`: `MANUAL`, `GOOGLE`, `APPLE`.

Owner and buyer queries must stay scoped to the token's user id. A manager must not read another owner's bookings, revenue, or admin commission by changing an id. Buyer bookings filter on `buyerUserId`. Owner export checks `club.userId`, `event.userId`, or `order.sellerUserId` and 404s otherwise. Do not invent an organizer permission model.

## Auth map

Files: `server/src/app/modules/auth/*`, `server/src/app/modules/recover/*`, `server/src/app/utils/jwt.utils.ts`, `session.utils.ts`, `otp.utils.ts`, `otpPolicy.ts`, `dob.utils.ts`, `oauthToken.utils.ts`, `server/src/const.ts`.

| Behavior | Rule |
|---|---|
| Signup DOB | Required ISO UTC datetime. Real calendar date, not in the future, age at least `MIN_SIGNUP_AGE` (18). Same check on profile update when DOB is sent. |
| Unverified retry | Same email while `isVerified` is false updates that user and issues a new OTP. It does not insert a second user. A verified email returns 409 `USER_ALREADY_EXISTS`. |
| Profile | `GET /profile` returns `profile.dateOfBirth` and `registrationState`: `COMPLETE` when `isVerified`, otherwise `UNVERIFIED`. |
| OTP | 6 digits from `crypto.randomInt`. Redis stores only the HMAC hash. TTL is `otpExpireAt` minutes times 60 seconds (5 minutes, 300 seconds). Wrong code is `INVALID_OTP`. Missing or expired key is `OTP_EXPIRED`. Five failures is `TOO_MANY_ATTEMPTS` and deletes the code. Resend inside 60 seconds is 429 `RESEND_TOO_SOON`. More than 10 sends per IP per 15 minutes is 429 `RATE_LIMITED`. Do not rename these codes. Do not log the code. |
| Verified session | Login and signup-verify return `token` and `refreshToken`. Access token is 7 days, or 30 days when `rememberMe` is true (`generateAccessTokenForUser`). Refresh is 3 days, or 30 days with `rememberMe`. `POST /auth/refresh` rotates the pair. Reuse of the old refresh token is 401 `TOKEN_BLACKLISTED`. |
| Unverified login | Returns the OTP-page token only. No refresh token. That token is for `/auth/verify` and `/auth/resend`. |
| Logout | Requires the access token. Optional body `refreshToken` deletes the Redis session key. The access token is blacklisted. |
| Social | `POST /auth/social` requires `idToken`. The body email is ignored. Verify RS256 against Google or Apple JWKS. Google `aud` comes only from `GOOGLE_OAUTH_CLIENT_IDS` (Web client ID). Google `azp` must be that audience or a value in `GOOGLE_OAUTH_AUTHORIZED_PARTIES` (iOS client ID). Apple audience comes only from `APPLE_OAUTH_CLIENT_IDS`. If the provider's audience env is unset, return 503 `PROVIDER_NOT_CONFIGURED`. Match `OAuthIdentity` on provider plus provider `sub`, then the token email. An existing account, including an unverified email, is logged in and marked verified. A missing account is created, then logged in with `token` and `refreshToken`. Phone is optional. A missing or already-used phone is stored as `social:<provider>:<sub>`. A token with no email uses `social.<provider>.<sub>@users.bookdianight.invalid`. `DELETED`, `BLOCKED`, and `INACTIVE` still return 401. `FIREBASE_CLIENT_ID` is not an OAuth audience. |
| Deleted account | Login returns 401 `ACCOUNT_DELETED`. App cannot use a `DELETED` user. Admin restore sets `ACTIVE` and does not rewrite the email. Preview is `GET /profile/deletion-preview`, self-delete is `DELETE /profile`. |

Recover routes are `/recover/find`, `/recover/verify`, `/recover/resend`, `/recover/reset`.

Demo users are created only by `server/scripts/seed-demo.ts`. Emails and the password come from `DEMO_CUSTOMER_EMAIL`, `DEMO_MANAGER_EMAIL`, `DEMO_ADMIN_EMAIL`, and `DEMO_PASSWORD`. Never hardcode or commit them. Fixed ids: club `00000000-0000-4000-8000-0000000000c1`, event `00000000-0000-4000-8000-0000000000e1`. The seed was run on the local database only.

## Where to edit

| Change | Open |
|---|---|
| Signup, login, OTP, social, refresh, logout | `server/src/app/modules/auth/` |
| Password recovery | `server/src/app/modules/recover/` |
| Me, DOB update, soft-delete | `server/src/app/modules/profile/` and `server/src/app/utils/accountDeletion.utils.ts` |
| Admin users, commission, restore | `server/src/app/modules/admin/` |
| Clubs | `server/src/app/modules/club/` |
| Events and ticket tiers | `server/src/app/modules/event/` |
| Tables / extras | `server/src/app/modules/eventModule/` |
| Buy club, event, or module | `server/src/app/modules/purchase/` and `payment/` |
| Buyer tickets | `server/src/app/modules/bookings/` |
| Owner dashboard, earnings, export | `server/src/app/modules/owner/` |
| Stripe webhooks | `server/src/app/modules/webhook/` |
| Email or PDF jobs | `worker/src/app/queues/` |
| Cron that only enqueues | `scheduler/` |
| Tables and enums | `prisma/schema.prisma`, then a new migration |

Route paths live in each module's `*.routes.ts`. The v1 router that mounts them is `server/src/app/routes/v1/index.ts`. Public role notes are `GET /auth/roles`.

Other mounted areas, each in its own module folder: explore, wishlist, follow, notification, reviews, promo, waitingList, guestList, hosts, artists, quotes, connect, serviceCharge, legal, media.

## Mail and providers

OTP delivery can be accepted by SMTP and still miss the inbox. That is DNS/provider, not an API 500. Local `.env` SMTP and the droplet SMTP are different. Do not copy secrets into chat, logs, or this file. Google sign-in stays 503 until `GOOGLE_OAUTH_CLIENT_IDS` is set on that runtime. That value is the Web client ID checked as `idToken` `aud`. `GOOGLE_OAUTH_AUTHORIZED_PARTIES` is the extra `azp` list (the iOS client ID). Apple stays 503 until `APPLE_OAUTH_CLIENT_IDS` is set. For the iOS app that value is the bundle ID checked as `idToken` `aud`. Team ID, Key ID, and a `.p8` key are not used to verify an app identity token. These vars are optional on purpose. Do not add them through `getEnv`, which throws when a variable is missing. The ibady `.env` sets the Google keys and `APPLE_OAUTH_CLIENT_IDS`. Recreate the server container after changing them. The droplet env is separate.

## Checks before saying a fix works

Run the server unit tests for auth/DOB/OTP changes. Hit the local API on `http://127.0.0.1:5005` when the behavior is HTTP. Say live is updated only after a request to `https://api.bookdianight.com` shows the new behavior. Do not claim a path was tested if it was only read.
