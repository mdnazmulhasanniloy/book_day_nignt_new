# REL-M8: Release checkpoint, M8 Flutter integration (M8a Phase 1, M8b Phase 2, M8c Phase 3)

| Field | Value |
|---|---|
| Stack | release |
| Phase | 1-3 |
| Depends on | FL-101, FL-102, FL-103, FL-104, FL-105, FL-106, FL-107, FL-108, FL-109, FL-110, FL-111, FL-112, FL-113, FL-114, FL-115, FL-116, FL-117, FL-118, FL-119, FL-120, FL-121, FL-122, FL-123, FL-124, FL-125, FL-126, FL-127, FL-128, FL-129, FL-130, FL-131, FL-132, FL-133, FL-134, FL-135, FL-B07, FL-B08, FL-P01 |
| Status | not started |

Do not start the next milestone until every box below is checked or explicitly waived by the product owner.

## Scope

All Flutter tasks. M8a (Phase 1): version gate, pending-approval screen, discovery, event page, artists, buckets, tier ids, plus the early fixes FL-B07 (401 handling), FL-B08 (refresh) and FL-P01 (date picker). M8b (Phase 2): fee preview, tables, chat, roles, cancellation, passes, scanner, settlement screens, venues, areas, age display, languages (en, it, fr, es). M8c (Phase 3): the remaining agreed languages. A Flutter task ships only after the backend release it depends on is in production. App store review time is not included in task sizes.

- FL-101 Flutter: version policy check at launch and the update-required screen (flutter, 0.5 day)
- FL-102 Flutter: signup change and pending-approval screen driven by partnerStatus and 423 (flutter, 0.5 day)
- FL-103 Flutter: city selector, radius 10-50 km (30 default), cityId on explore (flutter, 0.5 day)
- FL-104 Flutter: day grouping, date range, filters from /explore/filters, result total (flutter, 0.5 day)
- FL-105 Flutter: map view from /explore/map (flutter, 0.5 day)
- FL-106 Flutter: Interested button and count, recently viewed, most viewed, trending (flutter, 0.5 day)
- FL-107 Flutter: event page fields (club, map link, interested count, timezone display) (flutter, 0.5 day)
- FL-108 Flutter: artist list, profile, follow (flutter, 0.5 day)
- FL-109 Flutter: My tickets buckets (future, pending, past) and booking status (flutter, 0.5 day)
- FL-110 Flutter: send tier ids on event update, handle new error status codes (404/409/422) (flutter, 0.5 day)
- FL-111 Flutter: checkout uses the server-calculated total and shows fee lines per display mode (flutter, 0.5 day)
- FL-112 Flutter: remove the client-side fee calculation, keep one price source for all products (flutter, 0.5 day)
- FL-113 Flutter: French and Spanish complete across app flows, language inventory reconciled (flutter, 0.5 day; blocked: translations review)
- FL-114 Flutter: remaining agreed languages already listed in the app (after launch languages) (flutter, 0.5 day)
- FL-115 Flutter: table request screen, quote view with time left, withdrawn quote state (flutter, 0.5 day)
- FL-116 Flutter: card hold flow, pending status, release status, payment retry (flutter, 0.5 day)
- FL-117 Flutter: deposit options, balance and settlement terms, second payment (flutter, 0.5 day)
- FL-118 Flutter: table cancellation policy shown before payment, party size, attendance (flutter, 0.5 day)
- FL-119 Flutter: booking chat list and thread, read states (flutter, 0.5 day)
- FL-120 Flutter: protection message, WhatsApp support link, push handling (flutter, 0.5 day)
- FL-121 Flutter: role-aware navigation for staff and organizer permissions (flutter, 0.5 day)
- FL-122 Flutter: cancellation policy on checkout and cancel one ticket with refund preview (flutter, 0.5 day)
- FL-123 Flutter: refund status and event change notice with the refund route and deadline (flutter, 0.5 day)
- FL-124 Flutter: multi-day pass purchase and per-day availability (flutter, 0.5 day)
- FL-125 Flutter: per-day tickets and QR credential (flutter, 0.5 day)
- FL-126 Flutter: scanner uses the v2 scan endpoint, per-day and repeat results (flutter, 0.5 day)
- FL-127 Flutter: from-price, Last tickets badge and tier progression on event cards and page (flutter, 0.5 day)
- FL-128 Flutter: guest-list request, hold time, code entry (flutter, 0.5 day)
- FL-129 Flutter: purchase limit messages (flutter, 0.25 day)
- FL-130 Flutter owner screens: settlement states, expected transfer date, statements (flutter, 0.5 day)
- FL-131 Flutter: unregistered venue form and evidence upload, status, Presented-by label (flutter, 0.5 day)
- FL-132 Flutter: Cote d Azur area, empty-city text and no-result suggestions (flutter, 0.5 day)
- FL-133 Flutter: age rule on the event page and the 18+ warning before booking (flutter, 0.5 day; blocked: adviser confirmation (Q31))
- FL-134 Flutter owner: settlement proposal and organizer acceptance screens (flutter, 0.5 day)
- FL-135 Flutter owner: issue, edit and withdraw quotes; table policy settings (flutter, 0.5 day)

## 1. Review

- [ ] Fee, version gate and Flutter change are released together (ADR-012): the new build is in the stores before the minimum version is raised and fee model v2 is switched on.
- [ ] No Flutter SDK has been used on the dev machine so far: `flutter analyze` and `flutter test` must run in CI or on a machine with the SDK before this checkpoint.
- [ ] Backward compatibility: the new app against the old backend (fields missing) and the old app against the new backend both work.
- [ ] All tasks listed under 'Depends on' are Done and merged; `api-spec.yaml`, `data-model.md`, `api-usage-map.md` and `known-issues.md` match what shipped; `x-status: planned` removed for shipped operations.
- [ ] Tests green in CI on the release commit (`npm test`, `npm run test:db`, `npm run build`; `flutter analyze` and `flutter test` for Flutter; `npm run lint` is non-blocking per the root CI).

## 2. Staging deploy

- [ ] Distribute the build through TestFlight and the Google Play internal track (access not yet confirmed received, checklist item 02).
- [ ] Rehearsal script passed on a fresh restore from the release commit (T-002) for every migration in this release.

## 3. Smoke list (run on staging, then the read-only subset on production)

- [ ] New build: sign up as a club owner: pending screen, no logout (FL-102).
- [ ] Old build on the new backend: checkout total equals the charged amount (legacy fee path).
- [ ] New build: buy 2 tickets of EUR 20: EUR 42.50 shown and charged (FL-111).
- [ ] Version policy: set minimum above the installed version on staging: the update screen blocks (FL-101).
- [ ] Explore: pick Rome, 30 km, group by day, open the map (FL-103 to FL-105).
- [ ] Switch the language to French and Spanish and walk signup and checkout (FL-113).

## 4. Production deploy

- [ ] Written approval from the product owner (nothing is deployed, tagged or pushed without it).
- [ ] Follow `backend/docs/release-management.md`: bump the root `package.json` version, `npm install` for the lockfile, commit to `main`, create the annotated tag `vX.Y.Z`, push the commit and the tag. The tag drives the CD pipeline.
- [ ] Pending Prisma migrations are applied by the `db-migrator` container before the services boot (`backend/docs/production-deployment.md`). Migrations are expand-only and ship BEFORE the code that uses them.
- [ ] Verify `/health` on production, then run the production subset of the smoke list (read-only calls and test accounts; never real customer data).
- [ ] Store release only after written approval; raise the minimum version last.
- [ ] Record the release tag, date, who deployed and the smoke results at the bottom of this file.

## 5. Rollback note

an app in the stores cannot be recalled: keep fee model v2 switchable on the server (REL-M3), keep the legacy fee path, and lower the minimum version setting if a new build is faulty.

General rule: Prisma has no down migrations (`backend/docs/release-management.md` section 4). Every migration in this plan is expand-only so that the previous image keeps working; rollback means re-pointing `IMAGE_TAG` to the previous tag, not undoing the schema.

## Release record

| Item | Entry |
|---|---|
| Tag | |
| Date | |
| Deployed by | |
| Smoke result | |
