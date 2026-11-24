# REL-M13: Release checkpoint, M13 Booking chat

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-165, T-166, T-167, T-168, T-169, T-170, T-171 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

In-app booking chat, flags, WhatsApp support link, retention job, admin review and push notifications (ADR-009). Migration 21 and new notification types.

- T-165 Migration: booking conversations, messages, flags, retention fields (backend, 0.5 day)
- T-166 Chat endpoints: owner, authorized staff, authorized organizers, customer; read states (backend, 0.5 day)
- T-167 Detect and flag attempts to move a booking elsewhere; protection message (backend, 0.5 day)
- T-168 Retention job: delete 30 days after booking closure, or after dispute closure (backend, 0.5 day; blocked: legal check of 30-day deletion (adviser))
- T-169 Support link setting: the single Bookdia WhatsApp number and the suggested text (backend, 0.25 day; blocked: WhatsApp number (Q6))
- T-170 Admin and platform-staff chat review and intervention endpoints (backend, 0.5 day)
- T-171 Push notifications for chat, quotes, holds, transfers and approvals (backend, 0.5 day; blocked: push account (item 03))

## 1. Review

- [ ] The adviser confirmed that deleting chat 30 days after closure fits dispute, tax and Italian record-keeping rules, or the retention job is deployed disabled.
- [ ] Notification enum values were confirmed (they cannot be removed).
- [ ] The WhatsApp Business number and the push account were supplied by the client (not confirmed received).
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; db-migrator applies migration 21 and the notification type migration; the retention job is registered disabled.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] Customer and owner exchange messages on a table request (T-166).
- [ ] A message with a phone number is flagged and saved; the response carries the protection notice (T-167).
- [ ] Event in 24 hours: the support link appears (T-169).
- [ ] Platform staff intervenes and the audit row exists (T-170).
- [ ] Retention job (staging, shortened period): a 31-day-old closed conversation is deleted, a disputed one is not (T-168).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

disable the retention job first (a rollback must not leave a job deleting data with older code); messages stay stored.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
