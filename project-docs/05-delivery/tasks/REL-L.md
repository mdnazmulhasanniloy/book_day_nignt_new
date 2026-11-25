# REL-L: Release checkpoint, L Launch readiness

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-185, T-186, REL-HF, REL-M1, REL-M2, REL-M3, REL-M4, REL-M5, REL-M6, REL-M7, REL-M8, REL-M9, REL-M10, REL-M11, REL-M12, REL-M13, REL-M14, REL-MG |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

Owner acceptance run on the ten labelled test accounts and the five end-to-end demonstrations. Joys retests and closes each tracker id individually; we never mark an id Completed. Real Italian admission sales stay disabled until an approved ticketing route exists (separate new scope).

- T-185 Owner acceptance run on the labelled test accounts, tracker evidence per ID (backend, 0.5 day; blocked: tester availability (item 05))
- T-186 The five end-to-end demonstrations from the client answers (tables, split, passes, refunds, staff roles) (backend, 0.5 day; blocked: Stripe, Joys availability)

## 1. Review

- [ ] Every launch-priority item of Q34 has a named owner, date and end-to-end test.
- [ ] Open client items are listed with their effect: Stripe access, push, hosting, authorization form wording, terms, named admins and advisers.
- [ ] Written approval to publish builds and servers (Q30).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Staging has all releases above deployed; build numbers recorded.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Sign in as each of the ten roles (Customer, Club Owner, General Manager, Event Manager, Reservations Staff, Organizer, Admin, Platform Manager, Country Manager, Platform Staff) and verify the allowed screens (T-185).
- [ ] Run the five demonstrations from the demo pack (T-186).
- [ ] Italian admission sales are off: a purchase for an Italian paid event is refused or flagged test-only.

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Hold the store release and the production switch until the product owner approves in writing.
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

follow the rollback note of each included checkpoint, newest first.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
