# Staging checklist (2026-11-23)

Status: **checklist for you. Nothing was created.** No server, database, bucket, secret, workflow run, tag or deploy exists because of this file. You choose the host and create the resources; each box below is yours to tick. It turns `staging-plan-2026-11-23.md` into steps. Secret **names** only: never write a value in this repository, in chat or in an issue.

Legend: **[you]** needs your account or a decision. **[dev]** the development team can do it once you say so.

## Part 0. Before you start

- [ ] **[you]** Choose the host: a new small droplet (recommended) or another provider. Do not reuse the production droplet, database, Redis or bucket.
- [ ] **[you]** Choose the staging domain, for example `staging-api.<your domain>`, and point its DNS record at the host.
- [ ] **[you]** Decide the data: generated test data only (safest) or a scrubbed copy of production (emails, names, phones, dates of birth, tokens removed first). Never an unscrubbed copy.
- [ ] **[you]** Confirm the rule: **staging never gets live Stripe keys, live push keys or a real mail sender.**

## Part 1. Resources (all separate from production)

- [ ] PostgreSQL with PostGIS (own instance or own database server). After creating it, run `SELECT postgis_version();`. If it fails, enable the extension (`CREATE EXTENSION postgis;`) with a user that may. The schema needs it.
- [ ] Redis (own instance). Note whether it needs TLS (`REDIS_TLS=true`).
- [ ] Object storage: own bucket (or prefix) and its own access key pair. Public read only for the media URL you set in `S3_PUBLIC_URL`.
- [ ] Container registry access for the staging host (the existing registry is fine; use a **pull-only** token for staging).
- [ ] Stripe **test-mode** setup: test secret key, a test webhook endpoint for `POST /webhooks/payment/stripe` and a test Connect webhook endpoint for `POST /connect/webhook`, each with its own signing secret.
- [ ] Mail: a sandbox SMTP account or a catch-all inbox. No customer address may receive anything from staging.
- [ ] Push: a separate Firebase project (or a test one) so only test devices receive anything.
- [ ] Firewall: 80/443 open to the world, 22 only for your admin IP (and the CI runner rule later, see Part 3).
- [ ] TLS certificate for the staging domain and the reverse proxy to port 5000 (same as production).
- [ ] **Production compose file:** `backend/docker/docker-compose.yaml` is listed in `backend/.gitignore` and is **not in the repository**. Copy it from the production droplet (`/opt/bookdianight-server/docker-compose.yaml`), keep the same services (`db-migrator`, `server`, `worker`, `scheduler`) and put the staging values in a staging `.env` next to it. Tell us when it is ready so we can commit a sanitised copy.

## Part 2. Environment variables (names only)

One `.env` file on the staging host, next to the compose file (read by `env_file: .env`). Values come from the resources above. The names are taken from the code (`server/src/env.ts`, `worker/src/env.ts`, `scheduler/src/env.ts`). Note: `backend/docs/environment.md` still lists older names (`REDIS_URL`, `JWT_ACCESS_SECRET`, `S3_ACCESS_KEY_ID`); the names below are the ones the code reads.

**All services**
- [ ] `NODE_ENV` (staging uses `production` so the app behaves as in production, with test keys)
- [ ] `DATABASE_URL` (staging database only; the database name must **not** be the production one)
- [ ] `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`; optional `REDIS_TLS`

**server and worker**
- [ ] `SERVER_URL` (the staging public URL)
- [ ] `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET_NAME`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PUBLIC_URL`
- [ ] `STRIPE_SECRET_KEY` (**test** key, starts with `sk_test_`)

**server only**
- [ ] `PORT`
- [ ] `JWT_ACCESS_TOKEN_SECRET_KEY`, `JWT_REFRESH_TOKEN_SECRET_KEY`, `JWT_VERIFY_OTP_PAGE_SECRET_KEY`, `JWT_RESET_PASSWORD_TOKEN_SECRET_KEY`, `OTP_HASH_SECRET` (new random values, **never** the production ones)
- [ ] `STRIPE_PAYMENT_WEBHOOK_SECRET_KEY`, `STRIPE_CONNECT_WEBHOOK_SECRET_KEY` (signing secrets of the **test** webhook endpoints)
- [ ] `STRIPE_CONNECT_PUBLIC_BASE_URL`, `FLUTTER_CONNECT_APP_LINK_URL`

**worker only**
- [ ] `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` (sandbox)
- [ ] `FIREBASE_ACCOUNT_TYPE`, `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_ID`, `FIREBASE_AUTH_URI`, `FIREBASE_TOKEN_URI`, `FIREBASE_AUTH_PROVIDER_X509_CERT_URL`, `FIREBASE_CLIENT_X509_CERT_URL`, `FIREBASE_UNIVERSE_DOMAIN`, `FIREBASE_CLIENT_EMAIL`
- [ ] optional `PUPPETEER_EXECUTABLE_PATH` (only if production sets it)

**Compose interpolation (set in the shell or in the deploy step)**
- [ ] `DOCKER_USERNAME` (registry path, for example `registry.digitalocean.com/bookdianight-registry`)
- [ ] `IMAGE_TAG` (the release candidate tag you deploy, never `latest`)

## Part 3. GitHub settings (needed for the pipeline later, S2 to S5)

Create a GitHub **Environment** called `staging` and, later, one called `production` with a required reviewer. Names only:

- [ ] Secrets in `staging`: `DIGITALOCEAN_ACCESS_TOKEN` (limited scope), `DO_SSH_PRIVATE_KEY` (a key for the staging host only), `DO_REGISTRY_TOKEN`
- [ ] Variables in `staging`: `DO_DROPLET_HOST`, `DO_DROPLET_USER`, `DO_ACCOUNT_EMAIL`
- [ ] The existing production secrets stay where they are and are **not** copied into `staging`.

The CI workflow at the repository root (`.github/workflows/ci.yaml`) needs **no** secret and no setting; it uses throwaway placeholder values and never deploys.

## Part 4. Database and migrations on staging

Migrations are applied by the `db-migrator` container (`npx prisma migrate deploy`) before the services start. They are forward-only (no down step) and, for the queue branch, expand-only.

**4a. Hotfix release (no migrations)**
- [ ] Use an empty staging database or a scrubbed copy that is already at the production schema. Run the migrator: it must report nothing to apply for the hotfix.

**4b. Backend queue release (six new migrations, in this order)**
1. `20261123120000_add_tier_on_purchase`
2. `20261123130000_add_event_timezone_pricing_mode_tier_type`
3. `20261123140000_backfill_geog`
4. `20261123150000_add_cities_filter_options`
5. `20261123160000_add_engagement_tracking`
6. `20261123170000_add_artist_profile_fields`

- [ ] **[dev]** Run `backend/scripts/rehearse-migrations.sh` against a **current** production dump on a local throwaway database first. Attach the report (`project-docs/05-delivery/reports/`). Never against staging or production.
- [ ] Restore the same (scrubbed) dump into the staging database, then run the migrator. Expect: all six applied, no error.
- [ ] Run the checks in `reports/check-violations.sql` on staging; expect zero violations, or a list we have already reviewed.
- [ ] `npx prisma migrate status` against staging: expect "Database schema is up to date".
- [ ] Discovery seed (genres, moods, inactive launch cities, `server/scripts/seed-discovery.ts`): the script refuses a non-local database unless a release-only override is set (see the header of the script). **Do this together with us; do not set the override yourself.** Cities stay inactive until you answer Q5 and Q27.
- [ ] Never run `prisma migrate reset` or `db push` on staging or production.

## Part 5. Deploy to staging (manual until S2 exists)

- [ ] On the host: `cd /opt/bookdianight-server`, set `DOCKER_USERNAME` and `IMAGE_TAG`, then `docker compose pull` and `docker compose up -d`. The migrator runs first, then server, worker and scheduler.
- [ ] `docker compose ps`: all services up; `db-migrator` exited with code 0.
- [ ] `GET https://<staging domain>/health` is OK (database and Redis both up).
- [ ] The logs of `worker` and `scheduler` show no error on start (queue connected, jobs registered).
- [ ] The images for staging are built from the exact commit that will go to production. Do not rebuild for production; promote the same images (S3).

## Part 6. Smoke tests

Use test accounts you create on staging (customer, club owner, admin). Never real customer data.

**6a. Hotfix list (from `tasks/REL-HF.md` section 3)**
- [ ] `GET /admin/users?page=1&limit=50` as admin: no item has a `password` key.
- [ ] `POST /webhooks/payment/stripe` and `POST /connect/webhook` with no signature, then a wrong one: both 400. A correctly signed Stripe **test** event: 200.
- [ ] Log in, log out, replay the old access token on a protected route and on the socket handshake: both refused.
- [ ] `POST /media` and `DELETE /media` with no credentials: 401. With a mobile token and with the admin session: upload and delete work.
- [ ] Admin forgot-password: full flow works. Skipping the verify step returns 403 and the password does not change.
- [ ] Normal login, one ticket purchase in Stripe **test** mode and one webhook delivery still succeed.

**6b. Backend queue list (in addition, only for that release)**
- [ ] Buy a ticket and let a second order expire unpaid: the section stock is released (sold count goes back down). A failed or cancelled payment releases it only once.
- [ ] Event create and update: a ticket type with sales is hidden, not deleted; a section with sales cannot receive sub-types (422).
- [ ] An event with a time zone, with a pricing mode and with an empty optional description saves and reads back.
- [ ] `GET /cities`; `GET /explore?cityId=...&radiusKm=...` returns `distanceKm`; `GET /explore/map` pins match the list; `group=day` and `this_week` order correctly.
- [ ] `GET /explore/filters` returns music styles and moods; the admin filter-options list shows them.
- [ ] `POST` and `DELETE /events/{id}/interested` change `interestedCount`; view counters move after the flush job runs.
- [ ] `sort=trending`, most viewed and recently viewed return results; recently viewed is private to the account.
- [ ] Artists: list, profile, owner edit (only for an artist on the owner's own event), admin edit. A line-up sent without an artist id does **not** change a shared artist. A line-up sent with `isVerified: true` for an unverified artist still shows unverified.
- [ ] `GET /explore/{id}` for an event: `mapUrl` present; the club block appears only when the host club is approved.
- [ ] `GET /bookings?bucket=...` returns the right tickets with `bookingStatus`.
- [ ] Promo code validation: the 21st attempt within a minute returns 429.
- [ ] Guest list: joining twice returns 409; two parallel joins create one entry.
- [ ] Auth order: a bad token with a bad body returns 401, not 422.
- [ ] Share pages: `GET /explore/event/{id}` and `/explore/club/{id}` for a name containing `<script>` show the text, not markup.
- [ ] Live-sales check (client question 8): a read-only report of events whose sold number is higher than their paid orders. It goes to the client before anything is corrected.

**6c. Record**
- [ ] Write the results, date and who ran them in the release record of `tasks/REL-HF.md` (hotfix) or the matching `REL-M*` file.
- [ ] Anything fails: stop, do not tag production, send us the output.

## Part 7. Promotion to production (only after Parts 5 and 6 pass)

- [ ] You approve in writing. The hotfix is **not** waived from staging.
- [ ] Merge order is in `merge-plan-2026-11-23.md`. **Create no `v*` tag until the production workflow requires a reviewer (S3)**: today any `v*` tag in the old workflow deploys straight to production.
- [ ] Production deploys the same images that passed staging.
- [ ] Rollback: set `IMAGE_TAG` back to the previous tag on the droplet, `docker compose pull`, `docker compose up -d`. Schema changes are not undone (all migrations are expand-only, so the previous image keeps working).

## Part 8. What to send us when done

- [ ] Staging URL, the release candidate tag that is deployed, and the date.
- [ ] The names (never the values) of anything missing from Part 2.
- [ ] The results of Part 6, with failures pasted.
