# REL-M14: Release checkpoint, M14 Languages and age rules

| Field | Value |
|---|---|
| Stack | release |
| Phase | 2 |
| Depends on | T-088, T-172, T-173, T-174 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

Backend texts in English, Italian, French and Spanish; legal documents per language; event age rule (display only). The sign-up age stays 18+ until the client adviser confirms in writing (decision 2026-11-24).

- T-088 Language inventory of the Flutter app and backend texts (emails, push, errors) for EN, IT, FR, ES (backend, 0.5 day)
- T-172 Backend texts (emails, push, error messages) in EN, IT, FR, ES with per-user language (backend, 0.5 day)
- T-173 Legal document versions per language in the admin module (backend, 0.5 day; blocked: final legal texts (item 08))
- T-174 Event age rule field and the age warning text key; signup keeps 18+ (no code change to the minimum) (backend, 0.5 day; blocked: adviser written confirmation (Q31))

## 1. Review

- [ ] A 17-year-old signup is still rejected (regression test).
- [ ] Translations were reviewed by the client; machine text is marked as draft.
- [ ] Final legal texts exist for booking, refund and venue authorization terms (client item 08) or the language is served with a marked draft.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Deploy; apply the migration for the user language column if it was added.
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] OTP e-mail arrives in Italian for an Italian user and English by default (T-172).
- [ ] `GET /terms?lang=fr` returns French or falls back to English with the header (T-173).
- [ ] Event with `minAge` 21 shows it on the event page; signup of a 17-year-old is refused (T-174).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

text catalogues and the nullable columns are harmless to old code.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
