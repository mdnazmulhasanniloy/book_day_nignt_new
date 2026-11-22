# Project Docs Index

BookDiaNight: nightlife ticketing and club-booking platform. Three codebases in `D:\vive_codding\book_day_night\`:

| Codebase | Path | Notes |
|---|---|---|
| Backend (server, worker, scheduler, Prisma) | `backend/` | Express 5 + PostgreSQL/PostGIS + Redis/BullMQ, API under `/api/v1` |
| Admin dashboard | `admin/` | React 19 + Vite |
| Flutter mobile app | `flutter_app/` | Read-only reference for now (Flutter work is the last milestone, not started). The folder was renamed to `flutter_app/`; all docs now use that name, but line numbers in the as-is docs were written before the rename and were not re-checked |

## 1. Documents in `project-docs/`

State labels: **AS-IS** = describes the code as it is today. **TO-BE** = approved target state for the change requests (nothing implemented yet). Mixed files say which parts are which.

| File | Purpose | State / status |
|---|---|---|
| `00-INDEX.md` | This index and the reading guide in section 3 | current |
| `01-discovery/new update.md` | Client review and completion tracker (consolidated review dated 6 Nov 2026): requirement IDs (P0, A1, A2 ...), expected behaviour per item, evidence rules, open product/payment decisions Q1 to Q6 | client source document, not code-verified |
| `02-product/change-requests.md` | 17 change requests (CR-01 to CR-17) grouped from the client tracker, each with Status, Decision note, Decided by, Date, plus a Decision log | TO-BE decisions recorded 2026-11-21: Approved 8, Partial 8 (CR-01, 02, 04, 06, 07, 08, 15, 16), Deferred 1 (CR-05) |
| `04-architecture/system-architecture.md` | Components, tech stack, auth flows, payments flow, queues and cron jobs, third-party integrations, config, 4 Mermaid diagrams | AS-IS, reverse-engineered |
| `04-architecture/data-model.md` | **Sections 1 to 7 AS-IS:** all 41 models and 26 enums, ERDs, DB-level rules, migration history, Redis and S3 notes. **Sections 8 to 9 TO-BE:** new and changed tables, fields and indexes tagged with CR/BUG IDs, a TO-BE ERD (8.7), and 13 ordered migrations with backfill rules and risk (migration 1 is deferred) | AS-IS (1-7) + TO-BE (8-9) |
| `04-architecture/api-spec.yaml` | OpenAPI 3.1. 151 AS-IS operations plus 47 TO-BE operations (198 total). TO-BE operations carry `x-requirement`, `x-status: planned` and `x-change`; v2 operations live under `/v2/...` with a path-level `servers` override. Operations without `x-status` are AS-IS | AS-IS + TO-BE |
| `04-architecture/api-spec-changelog.md` | "Changes in v2" at the top: every added, changed and deprecated operation, compatibility rules, what is not in this release | TO-BE |
| `04-architecture/api-spec-diff-v2.md` | Every change to an existing v1 operation, each with "breaking for the live Flutter app? yes/no + reason", plus deprecated and added operations | TO-BE |
| `04-architecture/adr/` | ADR-001 API versioning and deprecation; ADR-002 organizer as a profile (no new role); ADR-003 pricing rules with effective dates; ADR-004 tier update matching (`PUT /event` fallback) | TO-BE decisions |
| `04-architecture/api-usage-map.md` | Which Flutter and Admin files call each endpoint, and which endpoints are unused | AS-IS, line numbers mostly unverified |
| `04-architecture/known-issues.md` | Bugs, dead code, security risks, missing validation (list only, nothing fixed); its IDs are the BUG-xx tags in the CRs | AS-IS |
| `05-delivery/blockers.md` | Questions for the client in plain English (Q1 to Q6, Q8, Q9, D1): why it matters, what it blocks, options, a recommended default; client notices; and the content we need from the client (genre/mood list, city seed list). Ready to send | open, none answered |
| `05-delivery/reports/stock-leak.sql` | Read-only SQL report: per event tier, `soldCount` vs paid persons; corrected value for events with one active tier. SELECT only | TO-BE (run on a copy first) |
| `05-delivery/roadmap.md` | Overview of the whole plan (2026-11-22): current state, priority groups, issue-by-issue roadmap for every tracker ID, gaps with no task, milestones, testing strategy | TO-BE plan |
| `05-delivery/implementation-plan.md` | Milestones HF and M0 to M8: backend first, then admin, Flutter integration last (not started); milestone-to-task and migration-to-task maps; traceability tables (CR and BUG to tasks to tests); flags for approved requirements with no task; Admin endpoint coverage note | TO-BE plan |
| `05-delivery/tasks/` | `README.md` (task list: ID, title, stack, depends on, status) and one file per task (`HF-001` to `HF-004`, `T-001` to `T-079`): stack, CR/BUG IDs, dependencies, docs to read, steps, done criteria with tests, status. `REL-HF` and `REL-M1` to `REL-M7` are release checkpoints (review, staging deploy, smoke list, production deploy, rollback note) | TO-BE plan |
| `05-delivery/patches/HF-001.md` | Backup of the S-17 patch (already in the baseline code); the task file is `tasks/HF-001.md` | reference |

`backend/CLAUDE.md` expects a changelog under `05-delivery/`; the API changelog lives in `04-architecture/api-spec-changelog.md` instead.

Conventions in the architecture docs:
- Files and sections labelled AS-IS describe the **current** state, with no proposals. TO-BE files and sections (data-model 8 to 9, TO-BE operations in `api-spec.yaml`, the changelog, the diff, the ADRs) describe the approved target and are tagged with CR/BUG IDs.
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
0. Start with `02-product/change-requests.md` (status of the CR and its Decision note), then `04-architecture/api-spec-diff-v2.md` and the relevant ADR in `04-architecture/adr/`. `05-delivery/blockers.md` lists what still waits on the client.
1. `01-discovery/new update.md`: find the requirement ID (P0, A1, A2 ...), the baseline, expected behaviour, and open questions (Q1 to Q6). Resolve or record open questions before building.
2. `04-architecture/known-issues.md`: see whether the requirement touches a known defect (for example P0 authentication items overlap with S-03, S-04, B-08).
3. `04-architecture/api-usage-map.md`: find which endpoints and client files the change would affect, and whether any client depends on the current response shape.
4. `04-architecture/data-model.md` and `04-architecture/api-spec.yaml`: the models and operations affected. Update both before implementing, per `backend/CLAUDE.md`.
5. `04-architecture/system-architecture.md`: the flow the change fits into (auth, payments, jobs).
6. Record unclear requirements as blockers in `05-delivery/blockers.md` (the place named in `backend/CLAUDE.md`).

## 4. Keeping this index current

- When a doc is added, removed or renamed, update section 1 in the same change.
- When code changes endpoints or schema, update `api-spec.yaml`, `data-model.md` and `api-usage-map.md` in the same change, and remove entries from `known-issues.md` that the change fixes.
- Re-count rather than hand-edit the totals (41 models and 26 enums: `grep -c "^model \|^enum " backend/prisma/schema.prisma`; 139 routes: count `.get/.post/.put/.patch/.delete(` calls in `backend/server/src/app/modules/*/*.routes.ts`; operations in `api-spec.yaml`: 151 AS-IS, 198 with the TO-BE additions). When a TO-BE item ships, remove its `x-status: planned` tag and move the data-model text from section 8 into sections 2 to 6.
