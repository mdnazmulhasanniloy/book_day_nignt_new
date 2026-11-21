# Project Docs Index

BookDiaNight: nightlife ticketing and club-booking platform. Three codebases in `D:\vive_codding\book_day_night\`:

| Codebase | Path | Notes |
|---|---|---|
| Backend (server, worker, scheduler, Prisma) | `backend/` | Express 5 + PostgreSQL/PostGIS + Redis/BullMQ, API under `/api/v1` |
| Admin dashboard | `admin/` | React 19 + Vite |
| Flutter mobile app | `BookingDiaNight/` | Read-only reference (the older prompt called it `mobile-app`) |

## 1. Documents in `project-docs/`

| File | Purpose | Status |
|---|---|---|
| `00-INDEX.md` | This index and the reading guide in section 3 | current |
| `01-discovery/new update.md` | Client review and completion tracker (consolidated review dated 6 Nov 2026): requirement IDs (P0, A1, A2 ...), expected behaviour per item, evidence rules, open product/payment decisions Q1 to Q6 | client source document, not code-verified |
| `02-product/change-requests.md` | 17 change requests (CR-01 to CR-17) grouped from the client tracker, with related known-issue IDs and blocking questions | DRAFT, all `Proposed`, none approved |
| `04-architecture/system-architecture.md` | Components, tech stack, auth flows, payments flow, queues and cron jobs, third-party integrations, config, 4 Mermaid diagrams | as-is, reverse-engineered |
| `04-architecture/data-model.md` | All 41 models and 26 enums, ERDs, DB-level rules (CHECKs, triggers, exclusion constraint), migration history, Redis and S3 notes | as-is, from `schema.prisma` and migrations |
| `04-architecture/api-spec.yaml` | OpenAPI 3.1 for all 151 operations (139 under `/api/v1` plus 12 root-level): auth chain, request and response fields, error codes | as-is, lints with 0 errors; response shapes partly unverified |
| `04-architecture/api-usage-map.md` | Which Flutter and Admin files call each endpoint, and which endpoints are unused | as-is, line numbers mostly unverified |
| `04-architecture/known-issues.md` | Bugs, dead code, security risks, missing validation (list only, nothing fixed) | as-is |

Empty folder (nothing written yet): `05-delivery/`. `backend/CLAUDE.md` expects `05-delivery/blockers.md` and a changelog there; neither exists.

Conventions in the architecture docs:
- Everything describes the **current** state, with no proposals.
- `⚠️ UNVERIFIED` marks anything not confirmed in code. `known-issues.md` also tags findings taken from a subagent scan.
- The code wins over any doc. If a doc and the code disagree, trust the code and record the difference in `known-issues.md`.

## 2. Docs outside `project-docs/` (secondary, may be out of date)

These were used only as cross-checks when the architecture docs were written; they are not verified.

| File | Purpose |
|---|---|
| `backend/CLAUDE.md` | Rules for Claude Code in the backend: stack, commands, contract-first and backward-compatibility rules. Its note that `04-architecture/` is empty is now outdated. |
| `backend/.agent/blueprint.md`, `architecture.md`, `rules.md`, `workflow.md`, `code-quality.md` | System map and repo contract. `blueprint.md` contains production host details; do not copy them into shared docs. |
| `backend/docs/` (`architecture.md`, `database.md`, `security.md`, `services.md`, `environment.md`, `flutter-api-integration-guide.md`, `developer-workflow.md`, `commit-convention.md`, `troubleshooting.md`, `observability.md`, `production-deployment.md`, `release-management.md`, `adr.md`, `ai-agent-guide.md`) | Developer-facing backend docs |
| `backend/openapi.yaml`, `backend/server/openapi.yaml` | Two identical, older OpenAPI files (about 70% of routes). Served by Swagger at `/api-docs`. Superseded for reading purposes by `04-architecture/api-spec.yaml`. |
| `backend/prisma/AGENTS.md`, `backend/server/AGENTS.md` | Rules for working in those folders (for example, no `migrate reset`, never edit merged migrations) |

## 3. What to read for each type of task

Read in the order listed. Stop when you have what you need.

### Backend task (new or changed endpoint, service, job, migration)
1. `04-architecture/system-architecture.md`: sections 5 to 8 (server pipeline, auth, payments, queues).
2. `04-architecture/api-spec.yaml`: the operations you touch (`x-auth` shows the exact middleware chain).
3. `04-architecture/data-model.md`: models involved, plus section 5 (DB rules that Prisma does not show).
4. `04-architecture/known-issues.md`: check whether the area has a known bug before building on it (for example 500-instead-of-404 patterns, `validateReqBody` skipping DELETE, the blacklist key mismatch).
5. `04-architecture/api-usage-map.md`: confirm which clients depend on the endpoint before changing it.
6. Then `backend/CLAUDE.md` and the nearest `AGENTS.md`.

Rules that apply (from `backend/CLAUDE.md`): update `api-spec.yaml` and `data-model.md` before changing endpoints or schema; a production Flutter app consumes the API, so never remove or rename response fields; migrations are forward-only.

### Admin task (dashboard page, admin endpoint)
1. `04-architecture/api-usage-map.md`: Admin column, and section 5 (pages still on mock data).
2. `04-architecture/api-spec.yaml`: `/admin/*`, `/recover/*` and `/media` operations. Admin uses cookie auth plus a CSRF header, so read `x-auth` carefully.
3. `04-architecture/system-architecture.md`: sections 6.5 (admin auth flow) and 11 (Admin client structure).
4. `04-architecture/known-issues.md`: sections 1 and 2, especially S-17 (password hash in `GET /admin/users`), B-17 and B-18 (admin 500s), S-22 (inconsistent CSRF).
5. `04-architecture/data-model.md`: `User`, `ApplicationCharge`, `ServiceCharge`, `Order` and the related models if you touch earnings or commission.

### Flutter integration (mobile app calling or consuming the API)
1. `04-architecture/api-spec.yaml`: the operations to integrate. Note the conventions in `info.description`: validation errors are HTTP 422, Decimals are strings, only some errors carry `traceId`.
2. `04-architecture/api-usage-map.md`: Flutter column, to find the existing repository file for the endpoint.
3. `04-architecture/system-architecture.md`: sections 6 (token types and device binding), 7 (purchase, payment intent, Stripe flow) and 11 (Flutter client structure).
4. `04-architecture/known-issues.md`: Flutter items (S-05, S-10 to S-13, B-07 to B-10) and API behaviours that affect clients (B-15 to B-17, R-06).
5. `backend/docs/flutter-api-integration-guide.md` (secondary, unverified) for extra context.

### Change request (new feature or requirement from the client)
1. `01-discovery/new update.md`: find the requirement ID (P0, A1, A2 ...), the baseline, expected behaviour, and open questions (Q1 to Q6). Resolve or record open questions before building.
2. `04-architecture/known-issues.md`: see whether the requirement touches a known defect (for example P0 authentication items overlap with S-03, S-04, B-08).
3. `04-architecture/api-usage-map.md`: find which endpoints and client files the change would affect, and whether any client depends on the current response shape.
4. `04-architecture/data-model.md` and `04-architecture/api-spec.yaml`: the models and operations affected. Update both before implementing, per `backend/CLAUDE.md`.
5. `04-architecture/system-architecture.md`: the flow the change fits into (auth, payments, jobs).
6. Record unclear requirements as blockers. `05-delivery/blockers.md` is the place named in `backend/CLAUDE.md`, but it does not exist yet. Create it only when needed and say so.

## 4. Keeping this index current

- When a doc is added, removed or renamed, update section 1 in the same change.
- When code changes endpoints or schema, update `api-spec.yaml`, `data-model.md` and `api-usage-map.md` in the same change, and remove entries from `known-issues.md` that the change fixes.
- Re-count rather than hand-edit the totals (41 models and 26 enums: `grep -c "^model \|^enum " backend/prisma/schema.prisma`; 139 routes: count `.get/.post/.put/.patch/.delete(` calls in `backend/server/src/app/modules/*/*.routes.ts`; 151 operations: operations in `api-spec.yaml`).
