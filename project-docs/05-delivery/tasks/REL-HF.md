# REL-HF: Release checkpoint, Hotfix track (branch from `main`, ship before M1)

| Field | Value |
|---|---|
| Stack | release |
| Depends on | HF-001, HF-002, HF-003, HF-004, HF-005 |
| Status | `fix/merge-hotfix` pushed to origin on 2026-11-25 (not merged to `main`); release checkpoint items not run |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

HF-001 to HF-004 (S-17 verify, B-16, S-04, S-19). Branch from `main`. No migrations. Suggested version bump: PATCH.

## Update 2026-11-24 (client answers 2)

Phase 1. HF-005 (`/media` auth) is not in `main`: it exists only in the unpushed branch `fix/merge-hotfix` (merge commit `c31c358`, backend typecheck clean and 167 of 167 unit tests passing, DB tests not run). Release steps: approve and merge that branch, then run this checkpoint. HF-002, HF-003 and HF-004 are already in `main`.

Additional review items:

- [ ] Confirm `fix/merge-hotfix` was merged to `main` after the product owner approved it; do not push or merge without that approval.
- [x] Follow-up 1: database tests run on 2026-11-25 on `fix/merge-hotfix` (tip `c31c358`) against a throwaway local `postgis/postgis:16-3.4` container (port 55432, database `bookdia_ci_test`, placeholder credentials, container removed afterwards; nothing near production). `npx prisma migrate deploy` applied all migrations, then `npm run test:db` in `backend/server`: **386 tests, 386 pass, 0 fail, 0 cancelled, 0 skipped** (83 suites, 45.8 s). HF-004 cases in `auth.checkOrder.db.test.ts`, suite "recover routes with a real user": pass: `reset with a valid token and body but no OTP verification -> 403 RECOVER_OTP_NOT_VERIFIED (HF-004 intact)`; pass: `verify with a wrong OTP -> 401 INVALID_OTP; with the right OTP -> 200 and marker set`. The T-032 seed suite against Postgres also ran and passed. Unit tests (no database) were 167 of 167 on the same commit; typecheck clean for server, worker and scheduler.
- [x] Follow-up 2 (waived by the product owner on 2026-11-25, for REL-HF only): lint does not run ("typescript-eslint does not support TS 7.0"; `typescript` ^7.0.2, `typescript-eslint` ^8.66.0). The review item below that asks for a green `npm run lint` is waived for this release. [FU-002](FU-002.md) stays open and is not part of REL-HF.

Additional smoke checks (staging, then the read-only subset on production):

- [ ] `POST /media` and `DELETE /media` without a token: 401; with a user token: 200 (HF-005).
- [ ] Webhook with a bad signature: 400 `INVALID_STRIPE_SIGNATURE`; reset password without OTP: 403 `RECOVER_OTP_NOT_VERIFIED`.

## 1. Review

- [ ] Each HF task has its evidence in the PR (HF-001: test and staging output; HF-004: the reproduction result either way).
- [ ] Behaviour changes called out in the PR text: revoked tokens are now refused (HF-003); reset without OTP is refused (HF-004); bad Stripe signatures give 400 (HF-002); `/media` upload and delete now need a signed-in account (HF-005).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` (waived for REL-HF, see follow-up 2) and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] FIRST ACTION: the old workflows have NO staging stage (a `v*` tag deploys straight to production) and, because the repo is now a monorepo, no workflow runs at all until root-level workflows exist. Read the 'Monorepo CI/CD' section at the bottom of this file, decide how staging is done (or accept none), and write the answer here.
- [ ] Deploy the hotfix branch/tag to staging and apply no migrations (none in this release).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] `GET /admin/users?page=1&limit=50` as admin: no item has a `password` key (HF-001).
- [ ] `POST /webhooks/payment/stripe` and `POST /connect/webhook` with no signature and with a wrong one: 400; with a Stripe test event signed correctly: 200 (HF-002).
- [ ] Log in, log out, replay the old access token on a protected route and on the socket handshake: both refuse it (HF-003).
- [ ] `POST /media` and `DELETE /media` with no credentials return 401; with a valid mobile token and with the admin dashboard session, upload and delete still work (HF-005).
- [ ] Admin forgot-password: full flow works; skipping the verify step returns 403 and the password does not change (HF-004).
- [ ] Normal login, one ticket purchase in Stripe test mode and one webhook delivery still succeed (regression).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

No migrations in this release, so rolling back is safe: set `IMAGE_TAG` to the previous tag (`release-management.md` section 4). Rolling back reopens S-04, S-19 and B-16; do it only if the hotfix itself breaks login or payments.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |


---

# Monorepo CI/CD (docs only, nothing added under `.github/` yet)

Written 2026-11-22 from reading `backend/.github/workflows/ci.yaml`, `backend/.github/workflows/deploy.yaml`, `admin/.github/workflows/deploy.yml`, `backend/docs/release-management.md`, `backend/docs/production-deployment.md`, `backend/docker/docker-compose.yaml`, the three Dockerfiles' build steps and the `build.sh` scripts. Nothing was run. The repo remote is now `github.com/mdnazmulhasanniloy/book_day_nignt_new` (note the spelling `nignt`).

## A. The problem

GitHub Actions only reads workflows from the repository ROOT `.github/workflows/`. The root has no `.github/` at all, so today **none** of these run: `backend/.github/workflows/ci.yaml`, `backend/.github/workflows/deploy.yaml`, `admin/.github/workflows/deploy.yml`. Pushing a `v*` tag to the new repo currently deploys nothing and CI runs nothing. (`backend/.github/CODEOWNERS`, the PR template and the issue templates are ignored for the same reason.)

## B. How deploy works today (as written in the old backend workflows)

**CI (`ci.yaml`, name "CI Pipeline")**
- Trigger: `push` to `main` and `pull_request` into `main`. No path filter.
- One job, `ubuntu-latest`, env `DATABASE_URL` = a dummy literal (not a secret).
- Steps: checkout (`actions/checkout@v4`), Node 22 with npm cache (`actions/setup-node@v4`), `npm ci --legacy-peer-deps` at the backend root, then for each of `scheduler`, `worker`, `server`: `npm install`, copy `../prisma` in, `npx prisma generate`, `npm run build`.
- What it really checks: build only. Each service's `scripts/build.sh` runs `npm run test` and then `tsc` and `tsc-alias`, so the server unit tests run inside the build (scheduler and worker tests are `echo "No tests written yet"`). Server `build.sh` prints that ESLint is skipped. **No lint step runs**, which differs from `production-deployment.md` section 3 (it says CI lints and runs tests as separate steps).

**CD (`deploy.yaml`, name "Build and Deploy")**
- Trigger: `push` of a tag matching `v*` (the docs use `vMAJOR.MINOR.PATCH`, for example `v1.0.15`). There is no branch check: a `v*` tag on any commit deploys to production. There is **no staging stage** in the workflow: tag to production directly.
- Job 1 `build-and-push` (`ubuntu-latest`): checkout; Buildx (`docker/setup-buildx-action@v3`); `doctl` (`digitalocean/action-doctl@v2`, token secret); `doctl registry login --expiry-seconds 1200`; for each service `docker/metadata-action@v5` then `docker/build-push-action@v5` with `context: .` (the backend root) and `file: ./server/Dockerfile`, `./scheduler/Dockerfile`, `./worker/Dockerfile`. Images and registry: `registry.digitalocean.com/bookdianight-registry/bookdianight-server`, `...-scheduler`, `...-worker`. Each is pushed with the metadata tags (the git tag name) plus `:latest`.
- Job 2 `deploy-to-droplet` (needs job 1): checkout; doctl; read the runner's public IP from `api.ipify.org`; `doctl compute firewall add-rules <firewall id> --inbound-rules protocol:tcp,ports:22,address:<ip>/32` (the firewall id is hardcoded in the file); `appleboy/scp-action@master` copies `docker/docker-compose.yaml` to `/opt/bookdianight-server` on the droplet (`strip_components: 1`); `appleboy/ssh-action@master` runs on the droplet: export `DOCKER_USERNAME=registry.digitalocean.com/bookdianight-registry` and `IMAGE_TAG=<git tag>`, `docker login registry.digitalocean.com` with the registry token (username = an account email variable), `cd /opt/bookdianight-server`, `docker compose pull`, `docker compose up -d`; final step (`if: always()`) removes the runner IP rule from the firewall.
- Migrations: the compose file has a one-shot `db-migrator` service (the server image running `npx prisma migrate deploy`); `server`, `worker` and `scheduler` have `depends_on: db-migrator: service_completed_successfully`. So migrations run on every deploy, before the new services start, against the `DATABASE_URL` in `/opt/bookdianight-server/.env` on the droplet (read through `env_file: .env`; the file is not in git).
- Target: one DigitalOcean droplet (user from a variable), Docker Compose, images from DOCR. Managed Postgres and Valkey are external. A health check hits `http://127.0.0.1:5000/health`.
- Rollback: on the droplet, `export IMAGE_TAG=<previous tag>; docker compose pull; docker compose up -d` (`release-management.md` section 4). Schema changes are not rolled back.
- Release steps (`release-management.md` section 3): bump `package.json`, `npm install` for the lockfile, commit to `main`, `git tag vX.Y.Z`, push commit and tag.

**Admin (`admin/.github/workflows/deploy.yml`, "Trigger DigitalOcean Deployment")**
- Trigger: push of ANY tag (`'*'`). Runs `doctl apps create --spec .do/app.yaml --upsert` (DigitalOcean App Platform). `admin/.do/app.yaml` **does not exist** in this repo, so the job would fail as it stands. Once moved to the root, `'*'` would also fire on every backend `v*` tag.

## C. Proposed root-level workflows (proposal only, not added to `.github/`)

Design points:
1. Backend CI: `paths: ['backend/**']` plus the workflow file itself, `defaults.run.working-directory: backend`, npm cache pointed at `backend/package-lock.json`. Behaviour otherwise identical to today's `ci.yaml` (build only). PRs into `client-update-v2` are also covered, because the plan works from that branch.
2. Backend deploy: trigger stays `tags: ['v*']`. **`paths` filters are not applied to tag pushes in GitHub Actions** (verify in the first run), so isolation in a monorepo has to come from the tag prefix, not paths. Backend keeps plain `v*` so the documented process and rollback commands do not change; admin and Flutter must use other prefixes (`admin-v*`, `flutter-v*`). `admin-v1.0.0` does not match `v*`.
3. Build context becomes `backend` (the Dockerfiles `COPY prisma`, `openapi.yaml`, `server/...` relative to the backend root); `file` becomes `backend/server/Dockerfile` and so on. The compose file source becomes `backend/docker/docker-compose.yaml` with `strip_components: 2` so it still lands at `/opt/bookdianight-server/docker-compose.yaml`.
4. Additions that are not in the old workflows (each marked `# NEW`): a `concurrency` group on deploy (two tags pushed close together would race on the firewall rule and `docker compose`), and the three image builds as a matrix instead of three copy-pasted steps (same image names and tags). Action versions for scp/ssh are pinned (the old files use `@master`); confirm the versions on first run.
5. Not changed on purpose: no staging stage is invented, no lint step is added, no automatic gate from CI to deploy. Those are listed as decisions below.

### `.github/workflows/backend-ci.yaml` (proposed)

```yaml
name: Backend CI

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - '.github/workflows/backend-ci.yaml'
  pull_request:
    branches: [main, client-update-v2]
    paths:
      - 'backend/**'
      - '.github/workflows/backend-ci.yaml'

concurrency:                       # NEW
  group: backend-ci-${{ github.ref }}
  cancel-in-progress: true

defaults:
  run:
    working-directory: backend

jobs:
  integration:
    name: Build & Test
    runs-on: ubuntu-latest
    env:
      DATABASE_URL: "postgresql://dummy:dummy@localhost:5432/dummy?schema=public"
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json

      - name: Install Root Dependencies
        run: npm ci --legacy-peer-deps

      - name: Build Scheduler Service
        run: |
          cd scheduler
          npm install
          cp -r ../prisma ./
          npx prisma generate
          npm run build

      - name: Build Worker Service
        run: |
          cd worker
          npm install
          cp -r ../prisma ./
          npx prisma generate
          npm run build

      - name: Build Server Service
        run: |
          cd server
          npm install
          cp -r ../prisma ./
          npx prisma generate
          npm run build
```

### `.github/workflows/backend-deploy.yaml` (proposed)

```yaml
name: Backend Build and Deploy

on:
  push:
    tags:
      - 'v*'            # backend releases only; admin uses admin-v*, flutter uses flutter-v*
                        # NOTE: GitHub does not apply `paths:` to tag pushes, so none is set here

concurrency:                       # NEW: never run two production deploys at once
  group: backend-deploy
  cancel-in-progress: false

defaults:
  run:
    working-directory: backend

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    strategy:                      # NEW: replaces three copies of the same two steps
      matrix:
        service: [server, scheduler, worker]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Install doctl
        uses: digitalocean/action-doctl@v2
        with:
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}

      - name: Log in to DigitalOcean Container Registry
        run: doctl registry login --expiry-seconds 1200

      - name: Extract metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: registry.digitalocean.com/bookdianight-registry/bookdianight-${{ matrix.service }}

      - name: Build and push image
        uses: docker/build-push-action@v5
        with:
          context: backend                           # was: .
          file: backend/${{ matrix.service }}/Dockerfile   # was: ./<service>/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }},registry.digitalocean.com/bookdianight-registry/bookdianight-${{ matrix.service }}:latest
          labels: ${{ steps.meta.outputs.labels }}

  deploy-to-droplet:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install doctl
        uses: digitalocean/action-doctl@v2
        with:
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}

      - name: Get GitHub Actions Runner IP
        id: runner-ip
        run: echo "ip=$(curl -s https://api.ipify.org)" >> $GITHUB_OUTPUT

      - name: Authorize Runner IP in DO Firewall
        run: |
          doctl compute firewall add-rules 2232b7d2-0b27-4bf7-afde-89d4fd0fd60f --inbound-rules protocol:tcp,ports:22,address:${{ steps.runner-ip.outputs.ip }}/32

      - name: Copy docker-compose.yaml to Droplet
        uses: appleboy/scp-action@v0.1.7           # was @master
        with:
          host: ${{ vars.DO_DROPLET_HOST }}
          username: ${{ vars.DO_DROPLET_USER }}
          key: ${{ secrets.DO_SSH_PRIVATE_KEY }}
          source: "backend/docker/docker-compose.yaml"   # was: docker/docker-compose.yaml
          target: "/opt/bookdianight-server"
          strip_components: 2                            # was: 1 (strips "backend/docker")

      - name: Execute deployment on DigitalOcean Droplet
        uses: appleboy/ssh-action@v1.0.3           # was @master
        with:
          host: ${{ vars.DO_DROPLET_HOST }}
          username: ${{ vars.DO_DROPLET_USER }}
          key: ${{ secrets.DO_SSH_PRIVATE_KEY }}
          script: |
            export DOCKER_USERNAME=registry.digitalocean.com/bookdianight-registry
            export IMAGE_TAG=${{ github.ref_name }}
            echo "${{ secrets.DO_REGISTRY_TOKEN }}" | docker login registry.digitalocean.com -u "${{ vars.DO_ACCOUNT_EMAIL }}" --password-stdin
            cd /opt/bookdianight-server
            docker compose pull
            docker compose up -d

      - name: Revoke Runner IP from DO Firewall
        if: always()
        run: |
          doctl compute firewall remove-rules 2232b7d2-0b27-4bf7-afde-89d4fd0fd60f --inbound-rules protocol:tcp,ports:22,address:${{ steps.runner-ip.outputs.ip }}/32
```

The `defaults.run.working-directory` has no effect on the `uses:` steps; it is kept only because you asked for it and for the two `run:` steps that would later need it. The deploy job has no local build, so the context change above is what actually matters.

Not proposed here: the admin deploy. When the admin workflow is moved, it needs `tags: ['admin-v*']`, `paths` do not apply to tags, `working-directory: admin` for any build step, and the missing `.do/app.yaml` must be found first (see B).

## D. Secrets and variables the workflows use (names only)

| Name | Kind | Used by | What it is for |
|---|---|---|---|
| `DIGITALOCEAN_ACCESS_TOKEN` | secret | backend deploy (3 uses), admin deploy | `doctl`: registry login, firewall rule add/remove, App Platform deploy |
| `DO_REGISTRY_TOKEN` | secret | backend deploy | Droplet logs in to the DigitalOcean registry before `docker compose pull` |
| `DO_SSH_PRIVATE_KEY` | secret | backend deploy (scp and ssh) | SSH key of the deploy user on the droplet |
| `DO_DROPLET_HOST` | variable | backend deploy (scp and ssh) | Droplet address |
| `DO_DROPLET_USER` | variable | backend deploy (scp and ssh) | Droplet SSH user |
| `DO_ACCOUNT_EMAIL` | variable | backend deploy | Username for `docker login` to the registry |

Backend CI uses no secrets (`DATABASE_URL` is a dummy literal inside the file). No `GITHUB_TOKEN` is referenced explicitly.

**Hardcoded in the workflow files (not secrets, but they must still be true for the new repo):** the DO cloud firewall id (`2232b7d2-...`), the registry name `bookdianight-registry`, the image names, the droplet path `/opt/bookdianight-server`.

**Not in the workflows but needed for a deploy to work:** the file `/opt/bookdianight-server/.env` on the droplet (read by every container). Its variable NAMES are in `backend/.env.example`: NODE_ENV, PORT, DATABASE_URL, REDIS_HOST, REDIS_PASSWORD, REDIS_PORT, SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, FIREBASE_ACCOUNT_TYPE, FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL, FIREBASE_CLIENT_ID, FIREBASE_AUTH_URI, FIREBASE_TOKEN_URI, FIREBASE_AUTH_PROVIDER_X509_CERT_URL, FIREBASE_CLIENT_X509_CERT_URL, FIREBASE_UNIVERSE_DOMAIN, JWT_ACCESS_TOKEN_SECRET_KEY, JWT_REFRESH_TOKEN_SECRET_KEY, JWT_VERIFY_OTP_PAGE_SECRET_KEY, JWT_RESET_PASSWORD_TOKEN_SECRET_KEY, S3_ACCESS_KEY, S3_SECRET_KEY, S3_REGION, S3_BUCKET_NAME, S3_ENDPOINT, S3_PUBLIC_URL, OTP_HASH_SECRET, STRIPE_SECRET_KEY, STRIPE_PAYMENT_WEBHOOK_SECRET_KEY, STRIPE_CONNECT_WEBHOOK_SECRET_KEY, STRIPE_CONNECT_PUBLIC_BASE_URL, FLUTTER_CONNECT_APP_LINK_URL, GOOGLE_OAUTH_CLIENT_IDS, GOOGLE_OAUTH_AUTHORIZED_PARTIES, APPLE_OAUTH_CLIENT_IDS. These already exist on the droplet; nothing needs to be re-created for them, but `.env.example` also lacks `SERVER_URL` (BUG-B06), so copy the real file's key list when asking.

### Questions to ask the client or the previous developer
1. Values for the six names in the table, set in the new repo (Settings, Secrets and variables, Actions). Prefer a NEW DigitalOcean token and a NEW deploy SSH key pair (add the new public key to the droplet's `deploy` user) rather than reusing the old repo's.
2. Is the DO firewall id in the file still the current firewall of the droplet, and is the registry still `bookdianight-registry`?
3. Is there a staging environment (droplet, database, registry) at all? Nothing in the workflows deploys to one.
4. What is the latest tag deployed to production, and which tags exist in the registry? (see E.3)
5. Which Git commit of the old repo is running in production? (see E.2)
6. Who owns the DigitalOcean account and the Stripe, Firebase, SMTP and S3 accounts (for the `.env` values), and who may rotate them?
7. Is the admin app really deployed through App Platform, and where is its `app.yaml`? Or is it served some other way?

## E. Old repo references and production provenance

1. **The workflow files do not reference the old repo URL.** They use `github.ref_name` and fixed registry and server names only; no `github.repository` and no clone URL. Moving them does not break on the old name.
2. **References to the old repo that remain elsewhere (docs only, none affects a deploy):** `backend/package.json` lines 33-40 (`repository`, `bugs`, `homepage` point to `github.com/Abdullah00001/bookdianight-server`); `backend/docs/developer-workflow.md` line 29 (`git clone` of that repo); `backend/.github/CODEOWNERS` (`@abdullah00001`, a user from the old repo; as it is not at the root it is inactive, and when it is moved it will request reviews from that account). The Docker image name `bookdianight-server` and the droplet path `/opt/bookdianight-server` carry the old repo's name but are infrastructure names, not repo links; keep them.
3. **Confirm production matches this code.** The new repo history starts at "first commit", so old tags are gone. Two checks, read-only: (a) on the droplet, `docker inspect <server container> --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'` gives the old-repo commit the running image was built from (the metadata action sets that label); ask the previous developer to confirm that commit equals the tree in `main` here. (b) `doctl registry repository list-tags bookdianight-server` lists existing image tags.
4. **Tag collision risk.** DOCR tags are plain mutable tags. The new repo has no `v*` tags, so the first tag cut here could equal one already in the registry (for example `v1.0.15`); pushing it would overwrite that image and break the documented rollback. Choose the first new tag above the highest tag in the registry.
5. Local hooks: `backend/.husky` and `backend/package.json` assume the Git root is `backend/`; in the monorepo the Git root is the parent, so the husky `pre-commit` (lint-staged) probably no longer runs. Not a CI issue; listed so it is not a surprise.

## F. Decisions needed from you before anything is added under `.github/`

1. Tag scheme: keep `v*` for backend and use `admin-v*`, `flutter-v*` (proposed), or `backend-v*` (cleaner, but changes `release-management.md`, the rollback commands and `IMAGE_TAG` handling).
2. Add a lint step and `npm run test:db` to CI once T-003 exists (not added now; the proposed CI equals today's behaviour).
3. Add a gate so a deploy only runs for a tag on `main` and after CI is green (not in the old workflow; recommended).
4. Create a staging environment or accept tag-to-production with the rehearsal script (T-002) as the pre-release check.
5. Who is added as the CODEOWNER in a root `.github/CODEOWNERS`.

## G. Checklist for this part of REL-HF (docs-only status)

- [x] Read both backend workflows, `release-management.md`, `production-deployment.md`, the compose file, the Dockerfiles' build steps and the build scripts (2026-11-22).
- [x] Deploy described (section B); proposed root workflows written (section C); secret and variable names listed (section D); old-repo references checked (section E).
- [ ] Section D answers collected and secrets added to the new repo.
- [ ] Section E.3 provenance and tag checks done; first tag chosen.
- [ ] Decisions in section F made.
- [ ] Workflows copied into root `.github/workflows/` (code change, later) and validated: CI run on a pull request, deploy tested with a throwaway tag against a non-production target if one exists, otherwise a dry run reviewed line by line before the hotfix tag.

## Note 2026-11-24: statuses to re-verify

T-001 to T-003 and HF-001 to HF-004 are marked done after a file comparison only. Before this release, re-run their tests (`npm test`, `npm run test:db` against a `*_test` or `*_rehearsal` database, typecheck) and the HF-001 staging check, and record the result here.
