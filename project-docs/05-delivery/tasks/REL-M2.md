# REL-M2: Release checkpoint, M2 Ticket sections, presets, promo, guest list

| Field | Value |
|---|---|
| Stack | release |
| Depends on | T-015, T-016, T-017, T-018, T-019, T-020, T-021 |
| Status | all tasks done in code; release checkpoint items not run |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

T-015 to T-021. Migration 4 (event timezone, pricing mode, tier type). Suggested bump: MINOR.

## 1. Review

- [ ] Rehearsal report for migration 4: counts per `pricingMode`; list of tiers that might be PASS (review query) given to the product owner. They are changed by hand after the release, not automatically.
- [ ] Promo role check confirmed against `flutter_app` usage (only the owner Promo tab) and recorded in the PR (T-018).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] `npm test`, `npm run test:db`, `npm run lint` and `npm run build` green in CI on the release commit.

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 4 (constant defaults, no table rewrite expected; confirm timing in staging).
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002).

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] `GET /ticket-tier-presets` returns the list.
- [ ] Create an event without the new fields (old client body): succeeds, `pricingMode` derived, `timezone` set (T-017).
- [ ] Owner promo create/update/delete works; a USER-role account gets 403; another owner's code 404 (T-018).
- [ ] 21 quick `POST /promo/validate` calls: the last returns 429 (T-019).
- [ ] Second guest-list join for the same event: 409 (T-020).

## 4. Production deploy

- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline (images `bookdianight-server`, `worker`, `scheduler`).
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them (same deploy, migrator first).
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and one test account; never use real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

Previous image works (new columns have defaults). Rolling back re-enables unlimited promo validation and the guest-list duplicates. Events created on the new version keep their `timezone` and `pricingMode`, ignored by old code.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4 and the warning in `production-deployment.md`). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
