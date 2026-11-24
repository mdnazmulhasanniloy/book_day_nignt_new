# Staging plan (2026-11-23)

Status: **proposal, nothing created or changed.** No server, workflow, secret, tag or deploy was touched. Every step below needs your explicit approval before anyone runs it.

## 1. Why this is needed

- Today a `v*` tag builds three images (server, scheduler, worker) and deploys them **straight to the production droplet**. There is no staging stage (`backend/.github/workflows/deploy.yaml`).
- The workflows sit under `backend/.github/` and `admin/.github/`. GitHub only reads `.github/` at the repository root, so **no workflow runs in this monorepo**, including the CI job prepared on `ci/backend-tests`.
- The hotfix (`release/hotfix`, no migrations) and the backend queue (`dev/backend-queue`, 6 migrations) are both code complete locally and wait on this.

## 2. Target shape

| Piece | Staging | Production |
|---|---|---|
| Trigger | push of a tag `v*-rc.N` (release candidate) | push of a tag `vX.Y.Z`, only after the same commit passed staging |
| Server, worker, scheduler | separate droplet (or a separate compose project on a small droplet) | existing droplet, unchanged |
| Database | **own PostgreSQL with PostGIS**, never the production one. Seeded from a scrubbed copy of production, or from the rehearsal dump. | existing |
| Redis | own instance | existing |
| Stripe | **test-mode keys only** and its own webhook endpoint | live keys |
| Object storage | own bucket or prefix | existing |
| Secrets | separate GitHub Environment `staging` | GitHub Environment `production`, with required reviewer |
| Domain | for example `staging-api.<domain>` with its own certificate | existing |
| Email, push | sandbox or a catch-all inbox, never real customers | live |

Rule: staging holds **no real customer data**. If a production copy is used, personal data (emails, names, phone numbers, dates of birth, tokens) is scrubbed first.

## 3. Work items (in order)

| # | Step | Who | Needs from you |
|---|---|---|---|
| S1 | Move the CI workflow to the repository root (`.github/workflows/ci.yaml`) with the paths set to `backend/`. Run `npm test`, `npm run test:db` (PostGIS service container) and `tsc`. Dummy credentials only, as the existing file already does. | development team | **Done in code (W-10, local branch, not pushed).** `.github/workflows/ci.yaml` runs `tsc` and all tests; lint is non-blocking (FU-002). It has not run on GitHub yet. |
| S2 | Add root `deploy-staging.yaml`: build the three images, tag `rc`, deploy to staging, run the migration container, then the smoke script. | development team | approval; staging host details |
| S3 | Add root `deploy-production.yaml`: same images, **reuses the images already tested on staging** (promote by tag, no rebuild), requires manual approval through the `production` environment. Keep the firewall open and close steps. | development team | approval |
| S4 | Create the staging infrastructure (extend the existing Terraform and Ansible under `backend/infrastructure/`). | whoever owns the cloud account | cloud account access, budget approval |
| S5 | Create the GitHub Environments and secrets for staging (test Stripe keys, staging database URL, registry token, SSH key). | repository owner | the secrets, entered by you; we never see production secrets |
| S6 | Write `scripts/smoke-staging.sh` from the checklist in `tasks/REL-HF.md` section 3, so the smoke list is one command. | development team | none |
| S7 | Admin dashboard: its deploy workflow also triggers on any tag. Give it the same staging then production split. | development team | decision on where the dashboard is hosted |

S1 is done in code. S2 to S5 need your approval and the cloud details. The step-by-step version of this plan for the owner is `staging-checklist-2026-11-23.md`; the merge order is in `merge-plan-2026-11-23.md`.

## 4. First release through staging

1. **Hotfix first, alone** (as recommended in `release-hotfix-readiness-2026-11-23.md`): no migrations, so the rollback is only an image tag.
2. Tag `v<next patch>-rc.1` on `release/hotfix` after it is merged to `main` by you. Staging deploys.
3. Run the smoke list (REL-HF section 3) on staging, record the result in `REL-HF.md`.
4. You approve; tag the final version; production deploys the same images.
5. The backend queue goes later as its own release, with its own migration rehearsal on a fresh production dump (`backend/scripts/rehearse-migrations.sh`) before staging.

## 5. Gates before the queue branch can go to production

- Client answers on the two High questions (global discount codes, late payments) or an explicit decision to ship with the safe defaults.
- Read-only check of live sales numbers (client question 8) and of tickets sections with sales and sub-types.
- Migration rehearsal on a current production dump, including the drift check and the report scripts.
- Flutter app builds that match the new fields are not required (all changes are additive), but token-refresh and date-of-birth fixes should ship with or before them.

## 6. Risks and rollback

- Migrations have no down step. All six on the queue branch are expand-only, so the previous image keeps working after a migration; rollback = previous `IMAGE_TAG`.
- The tag workflow currently opens an SSH rule on the cloud firewall for the runner and closes it at the end (`if: always()`). Keep that.
- A mistaken `v*` tag today deploys to production. Until S3 is in place, **do not create any tag**.

## 7. Decisions for you

1. May we do S1 now (root CI workflow; tests only, no deploy)?
2. Staging host: new small droplet, or a second compose project on the existing one (cheaper, but shares the machine; not recommended)?
3. Who creates the cloud resources and the GitHub secrets?
4. Is a production-data copy allowed for staging, scrubbed, or do we use only generated test data?
5. Do you waive staging for the hotfix in writing, or do we wait for it? (We recommend waiting.)
