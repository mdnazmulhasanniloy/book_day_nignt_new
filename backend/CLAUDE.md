# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

BookDiaNight backend: a nightlife ticketing API. Actors are customer (`USER`), club manager (`CLUB_OWNER`) and `ADMIN`. There is no ORGANIZER role.

## 1. Stack & versions

- Node 22 (Docker `node:22-alpine`), TypeScript ^7.0.2, run with tsx + nodemon.
- server: Express ^5.2.1, Socket.IO ^4.8.3, Zod ^4.4.3, BullMQ ^5.67.2 (producer), ioredis ^5.6.0.
- worker: BullMQ ^5.67.2 consumer (nodemailer, Handlebars, FCM, pdfkit/puppeteer, Stripe).
- scheduler: node-cron ^4.5.0, BullMQ producer.
- DB: PostgreSQL + PostGIS via Prisma ^6.19.2 (`prisma-client-js`). Queue/cache: Redis (Valkey).

## 2. Folder structure

- `server/`: Express REST API (`/api/v1`) and Socket.IO. Modules in `server/src/app/modules/<name>/` (routes → middlewares → schema → controllers → services).
- `worker/`: BullMQ consumer only. Queues and handlers are discovered dynamically and must be idempotent.
- `scheduler/`: node-cron producer only. `*.tasks.ts` under `src/app/jobs/` enqueue work for the worker.
- `prisma/`: the single schema and migrations shared by all three services.
- `.agent/`: system map (`blueprint.md`) and repo contract. Read `blueprint.md` first.
- `docs/`: in-repo architecture, database, security and deployment docs.
- `scripts/`: root helper scripts (kebab-case names). `infrastructure/`, `.github/workflows/`, `scripts/vps-*.sh`: production only, don't touch without approval.

## 3. Commands

Run locally through Docker Compose only (API at `http://127.0.0.1:5005/api/v1`, Postgres `5440`, Redis `6382`):
```bash
docker compose up -d --build     # run everything
docker compose logs -f server
npm run prisma:migrate           # (root) prisma migrate dev: new migration + local DB
npm run prisma:generate          # (root) regenerate client for IDE types
npm run prisma:sync              # (root) prisma generate inside running containers
```
Inside `server/`, `worker/` or `scheduler/`: `npm run build`, `npm run lint`, `npm run format`, `npm test`.
- Only `server/` has tests (`tsx --test`). Single file: `npx tsx --test src/app/utils/otpPolicy.test.ts`.
- `server` build runs tests, then tsc. Its lint is not part of the build.
- Generators (root): `npm run create:module <name>`, `create:endpoint`, `create:queue`, `create:queue-job`, `create:job`, `create:emailTemp`. Use them instead of hand-writing scaffolds.

## 4. Docs location

External docs live in `../project-docs`. Read `../project-docs/00-INDEX.md` first.
Currently `04-architecture/` and `05-delivery/` there are empty, so `api-spec.yaml`, `data-model.md`, `blockers.md` and the changelog do not exist yet. Create them when a rule below requires them, and tell the user.

## 5. Rules

- Before any task, read the task file and only the docs it links.
- Contract first: update `../project-docs/04-architecture/api-spec.yaml` and `data-model.md` BEFORE changing endpoints or schema. Also keep `openapi.yaml` and `server/openapi.yaml` in sync with the implementation.
- Backward compatibility: a production Flutter app consumes this API. Never remove or rename response fields or change their types. Add new fields or create versioned endpoints instead.
- Never edit existing or merged migrations; always create new ones. Migrations are forward-only. Never run `prisma migrate reset`, `prisma db push`, `docker compose down -v` or `scripts/vps-apply-new-images.sh`.
- Never commit secrets or `.env` files.
- If a requirement is unclear, write it in `../project-docs/05-delivery/blockers.md`, mark the task blocked, and STOP. Never invent requirements.
- Done = tests pass + task status updated + changelog updated.
- Don't commit, push, tag or deploy without explicit approval. Commits follow `docs/commit-convention.md`.
- Server code: use `@/app/...` imports (never relative), camelCase file names, no new `any`, one destructured param object per service function. Scope owner and buyer queries to the token's user id.
- Optional OAuth env vars (`GOOGLE_OAUTH_CLIENT_IDS`, `GOOGLE_OAUTH_AUTHORIZED_PARTIES`, `APPLE_OAUTH_CLIENT_IDS`) must not go through `getEnv`, which throws when missing.
- Production (`https://api.bookdianight.com`) runs built images. Call a change live only after a request there shows it.
