# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

BookDiaNight is a nightlife ticketing and club-booking platform. This repo is a monorepo of three separate codebases plus planning docs. Actors: customer (`USER`), club manager (`CLUB_OWNER`), `ADMIN`.

| Folder | What | Own guidance |
|---|---|---|
| `backend/` | Express 5 API (`/api/v1`) + BullMQ worker + node-cron scheduler, one shared Prisma schema (PostgreSQL/PostGIS, Redis) | `backend/CLAUDE.md` (read it; strict rules on migrations, contract-first, backward compatibility) |
| `admin/` | React 19 + Vite + TypeScript admin dashboard | below |
| `flutter_app/` | Flutter mobile app (GetX, Dio, Stripe) | `flutter_app/CLAUDE.md` |
| `project-docs/` | Architecture, change requests, API spec, task plan | start at `project-docs/00-INDEX.md` |

Each codebase has its own dependencies and commands; there is no root package manifest. Run commands from inside the relevant folder.

## Where the truth lives

- `project-docs/00-INDEX.md` has a "what to read for each type of task" guide. Read it before non-trivial work. Tasks live in `project-docs/05-delivery/tasks/` (`HF-*` hotfixes, `T-*` tasks, `REL-*` release checkpoints); read the task file and only the docs it links.
- Docs are labelled AS-IS (current code) or TO-BE (approved target, not implemented). The code wins over any doc; record disagreements in `project-docs/04-architecture/known-issues.md`.
- Contract first: update `project-docs/04-architecture/api-spec.yaml` and `data-model.md` before changing endpoints or schema.
- A production Flutter app consumes the API: never remove or rename response fields; add fields or versioned (`/v2`) endpoints instead.
- Flutter work is the last milestone and not started; treat `flutter_app/` as read-only reference unless asked.
- Don't commit, push, tag or deploy without explicit approval. Current branch convention: work happens on feature/hotfix branches off `main`.

## Admin (`admin/`)

```bash
npm install
npm run dev      # vite
npm run build    # tsc -b && vite build
npm run lint     # eslint .
```
No test runner is configured.

- Requires `VITE_API_URL` in `admin/.env` (read via `getEnv` in `src/configs/env.configs.ts`).
- `src/apis/*.api.ts` are the axios endpoint wrappers; `src/features/<name>/{api,components,types}` hold per-feature UI. Some features (clubs, events, earnings) still use `api/mock.ts` instead of the real API; check `project-docs/04-architecture/api-usage-map.md` before assuming an endpoint is wired.
- Auth is cookie-based plus an `x-csrf-token` header. `src/configs/axios.configs.ts` attaches the CSRF token from the zustand `auth.store` and, on a 401, refreshes via `/admin/auth/refresh` with a queued retry (skipping login, refresh and `/recover/*`). Route guards: `components/guards/AuthGuard.tsx` and `GuestGuard.tsx`.
- UI is shadcn/Radix (`components/ui/`), data fetching via TanStack Query, forms via react-hook-form + Zod. Use `@/` path imports.
