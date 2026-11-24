# REL-M9: Release checkpoint, M9 Team roles and permissions

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-101, T-102, T-103, T-104, T-105, T-106, T-107, T-108, T-109, T-110, T-111 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

Roles in separate tables (ADR-008). `AccountRole` keeps USER, ADMIN, CLUB_OWNER. Migration 14.

- T-101 Migration: club team members, platform staff, permission grants, audit rows (AccountRole untouched) (backend, 0.5 day)
- T-102 Permission catalogue and resolver: page view/manage plus sensitive actions (backend, 0.5 day; blocked: default permission matrix (Q24))
- T-103 Club team: invite, accept, suspend, remove (owner), suspend any (platform) (backend, 0.5 day)
- T-104 Enforce club roles on events, bookings and check-in (assigned events only) (backend, 0.5 day)
- T-105 Enforce club roles on revenue, refunds, payout destination and team changes (backend, 0.5 day)
- T-106 Organizer permissions for quotes, chat and refunds: off by default, granted one by one, history kept (backend, 0.5 day)
- T-107 Platform roles (Manager, Country Manager, Staff) and the country limit on admin endpoints (backend, 0.5 day)
- T-108 Sensitive actions reserved to Admin: rates, payouts, Technical Fee refunds, club debits, admin management (backend, 0.5 day)
- T-109 Admin endpoints for the editable role-permissions page (backend, 0.5 day)
- T-110 Additive staff fields on login and check responses (teamRole, permissions) for the apps (backend, 0.5 day)
- T-111 Labelled test accounts for the ten roles (seed script, test payments only) (backend, 0.5 day)

## 1. Review

- [ ] No value was added to `AccountRole`; staff data is in the new tables and only additive fields appear in auth responses.
- [ ] The default permission matrix was confirmed by the client (open question) or the default is recorded as provisional.
- [ ] Server-side enforcement tested for every sensitive action (rates, payouts, Technical Fee refunds, club debits, admin management) and the country limit.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 14.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Owner invites a General Manager: invitation accepted, role visible in `teamRole` on login (T-110).
- [ ] Reservations Staff calls the revenue endpoint: refused (T-105).
- [ ] Platform Manager calls a payout destination change: refused; Admin succeeds (T-108).
- [ ] Country Manager (Italy) lists a French club: not found (T-107).
- [ ] Organizer without the quotes grant tries to issue a quote: refused; after the owner grants it: allowed, history row written (T-106).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

the old image ignores the new tables; staff accounts keep working only as plain users, so tell owners before a rollback.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
