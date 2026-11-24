# REL-M12: Release checkpoint, M12 Venue authorization, disputes and destination areas

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-157, T-158, T-159, T-160, T-161, T-162, T-163, T-164 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

Unregistered venue authorization with admin review and dispute handling, public label, destination areas and the activation of destinations. Migrations 19 and 20. Event change refund path is part of REL-M6.

- T-157 Migration: venue authorization record, uploaded evidence, admin decision, public label (backend, 0.5 day; blocked: authorization form wording (item 07))
- T-158 Unregistered venue events: submit form and evidence, sales blocked until approval (backend, 0.5 day)
- T-159 Admin review of venue authorizations with notices (backend, 0.5 day; blocked: D12 (named reviewers))
- T-160 Venue dispute: suspend sales, tickets stay valid, decision in 2 working days, escalation for imminent events (backend, 0.5 day; blocked: working-day calendar (Q25))
- T-161 Public label Presented by organizer at venue on the event page (backend, 0.5 day)
- T-162 Migration: destination areas (Cote d Azur) independent of the radius, town membership (backend, 0.5 day; blocked: town list or boundary (Q26))
- T-163 Explore and map by destination area, per-destination activation, empty-state reasons (backend, 0.5 day)
- T-164 Activate the eleven destinations and set time zones; first-party-on-its-way text key (backend, 0.5 day; blocked: activation confirmation per city (Q27))

## 1. Review

- [ ] The authorization form wording (English and Italian) reviewed by the client's legal adviser is in place, or the build uses a clearly marked placeholder version that cannot go to production.
- [ ] The Cote d Azur town list or boundary came from the client (open question).
- [ ] Activation of each destination is a separate written confirmation (Q27); commercial coverage and Stripe payout eligibility are checked separately.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migrations 19 and 20; run the seed script without `--activate`.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Organizer submits a manual-venue event: purchase returns 409 `VENUE_NOT_AUTHORIZED`; after approval it succeeds (T-158, T-159).
- [ ] Admin disputes the venue: new sales stop, a sold ticket still scans (T-160).
- [ ] `GET /explore?cityId=<Cote d Azur>` returns Cannes and Menton events, not Marseille; Monaco is separate (T-163).
- [ ] City with no club returns `emptyReason` NO_CLUB_IN_CITY (T-163).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Activate cities only with the client's per-city confirmation.
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

new tables unused by old code; disputed events stay suspended in the data, so resolve open disputes before rolling back.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
