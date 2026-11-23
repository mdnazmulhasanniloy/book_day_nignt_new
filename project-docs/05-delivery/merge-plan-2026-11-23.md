# Merge plan (2026-11-23)

Status: **plan only. Nothing was merged, rebased, tagged or pushed.** Every step below is run by you (or by us after your explicit go). Related: `staging-checklist-2026-11-23.md`, `staging-plan-2026-11-23.md`, `release-hotfix-readiness-2026-11-23.md`.

## 1. Order

1. `release/hotfix` goes to `main` **first**, and only **after it passed staging** (no waiver).
2. `dev/backend-queue` is then **rebased on the new `main`** and reviewed and released **block by block**, each block through staging.

## 2. Step 1: release/hotfix to main

State: branch `release/hotfix`, five commits on `main`, no migrations, 28 of 28 tests, `tsc` clean.

| # | Step | Who |
|---|---|---|
| 1 | Staging exists and has the hotfix images (`staging-checklist-2026-11-23.md`, Parts 1 to 5) | you |
| 2 | Smoke list 6a passes on staging, result recorded in `tasks/REL-HF.md` | you, with us |
| 3 | Review the five commits (`git log main..release/hotfix`) | you |
| 4 | Merge `release/hotfix` into `main` (pull request, not a direct push) | you |
| 5 | Version bump and tag only through the production workflow gate (S3) | you |

Note: the root CI workflow (`.github/workflows/ci.yaml`) exists only on `dev/backend-queue`. To run on the hotfix pull request, add the same file to the hotfix branch (one commit, tests only) or merge it first. Say which you prefer.

## 3. Step 2: rebase dev/backend-queue on main

**What the rebase will meet (checked 2026-11-23):**

- The branch holds 153 commits over the old `main`. Three of them are the same code as the hotfix commits (compared line by line, tests excluded): `a9e54f7` (HF-002), `3ca7417` (HF-003), `c9907f1` (HF-004). After the hotfix is merged they duplicate it. Expect conflicts or empty commits on these three: **skip them** (`git rebase --skip`), after checking the diff is empty.
- HF-005 (`POST` and `DELETE /media` need authentication) is **not** on the queue branch, so nothing to skip there; it arrives with `main`.
- Hotfix changes to `backend/openapi.yaml` (`/media`) and `api-spec.yaml` may conflict with the queue's spec sync. Resolve by keeping both and re-running the YAML guard test (`apiSpec.valid.test.ts`).
- Keep a safety copy first: `git branch backup/dev-backend-queue-2026-11-23` on the current tip. Rebase with `git rebase main`; never force-push over a shared branch without a second check.
- After the rebase: `npm test`, `npm run test:db` (needs a `*_test` database), `tsc` for server, worker and scheduler, and the migration rehearsal on a fresh production dump. All must be as green as today (160 unit and 386 DB tests, 14 worker, 2 scheduler on the last run).

## 4. Step 3: review and release per block

The branch is too large to review as one. Split it by block. Each block is a pull request into `main` made from the rebased branch (cherry-picked or split by path), reviewed, deployed to staging, smoke-tested, then released. The migration numbers are fixed by name, so blocks must keep their order.

| Block | Contents | Migrations | Tests to watch | Release gate |
|---|---|---|---|---|
| **A. Stock fix** | Tier stock released on expired and failed payments (T-005 to T-008): tier stored on the purchase, release once, expire job in the worker, guard against deleting a tier with purchases | `add_tier_on_purchase` | `*.db.test.ts` for tiers, worker job tests | Client check of live sales numbers (question 8) is read-only and done before release; stock-release smoke on staging |
| **B. M1 correctness** | Status codes and error mapping (T-010 to T-014, T-021), geography backfill (T-029, T-030), tier update in place (T-004), social sign-in date of birth (T-009) | `backfill_geog` | status-code tests, geography tests, auth order tests | Rehearsal on a fresh dump including the drift check; the Flutter token-refresh and date-of-birth fixes ship with or before this block |
| **C. M2 sections, promo, guest list** | Time zone, pricing mode, ticket types and presets (T-015 to T-017), promo role and rate limit (T-018, T-019), guest list duplicate (T-020) | `add_event_timezone_pricing_mode_tier_type` | tier, promo and guest-list tests | **Promo decision pending (client Q1):** ship with the safe defaults or wait; no behaviour change until answered |
| **D. Discovery** | Cities, filter options, radius, day grouping, map, interested, view tracking, trending, artists, event page fields, bookings bucket (T-031 to T-046), share page escape and artist protection (S-23, W-04, W-05, W-09) | `add_cities_filter_options`, `add_engagement_tracking`, `add_artist_profile_fields` | explore, map, engagement, artists, share-page tests | Seed run together with us; cities stay inactive until the client decides (Q5, Q27); the scheduler flush tick enabled |

Docs-only commits (`docs:` and the work-queue files) travel with the block they describe. The `openapi.yaml` sync (W-02) is a separate docs pull request and can go at any time after step 1.

**Per block, the same loop:**
1. Open the pull request; CI (root workflow) must be green.
2. Review the diff (we provide a summary per task from `work-queue-2026-11-23.md`).
3. Run the migration rehearsal for any block with a migration.
4. Deploy the release candidate to staging; run the smoke items from `staging-checklist-2026-11-23.md` Part 6b that belong to the block.
5. You approve in writing; production promotion with the same images.

## 5. Things we do not do

- No push, merge, rebase of a shared branch, tag or deploy by us. You run these, or tell us to for one named step.
- No `git add -A`; the untracked `.claude/` folder is never committed.
- Global discount codes (Q1) and late payments (Q2) stay as they are until the client answers.
- Refund tasks T-063 to T-066 and T-078 stay on hold.

## 6. Decisions for you

1. Where does the root CI workflow go first: onto the hotfix branch, or only with the queue?
2. Is the block split above right (A stock, B correctness, C sections and promo, D discovery), or do you want a different order?
3. Do you want the per-block pull requests prepared by us (as local branches, not pushed) so you only review and push?
