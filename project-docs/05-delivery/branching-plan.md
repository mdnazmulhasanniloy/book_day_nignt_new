# Branching and integration plan (as of 2026-11-22)

## Current state (verified with `git log --graph --all`)

History is a single line; nothing has diverged and no commit is unreachable.

```
b099bb6 main (origin/main)            first commit (code + old docs)
123a80a, 5f3bf93  client-update-v2    docs only: rebuilt project-docs (code identical to main)
6edae52, a9e54f7, 3ca7417, c9907f1, 061a6e5, f51bb4a   hotfix/security
                                      root CLAUDE.md, HF-002, HF-003, HF-004, T-001 baseline, roadmap
```

- `client-update-v2` is an ancestor of `hotfix/security`; everything in it is already in `hotfix/security`.
- `main` has none of the rebuilt docs, `CLAUDE.md`, task files or hotfix code. Backend code on `main` equals the base of the hotfixes.
- Only `main` and `client-update-v2` exist on `origin`. `hotfix/security` and every branch below are local only (not pushed).

## Branches created from this plan

| Branch | Based on | Contains | Why this base |
|---|---|---|---|
| `hotfix/security` | v2 line | HF-002..004, roadmap, T-001, HF-005 docs (`b13efb8`) | Existing work, kept intact |
| `hotfix/media-auth` | `main` | HF-005 code and tests only (`4540928`) | Independent code fix, so it can ship from `main` without the docs line |
| `feat/t-002-migration-rehearsal` | `hotfix/security` | T-002 script and SQL | Needs the T-001 reports that exist only on the docs line |
| `feat/t-003-test-harness` | `hotfix/security` | T-003 harness | The glob runner must pick up the HF tests that live on `hotfix/security`; task docs live there |
| `docs/flutter-early-tasks` | `hotfix/security` | FL-B07, FL-B08, FL-P01 task files, this plan | Docs follow the docs line |

Deviation from "branch every new work from `main`": `main` lacks the task docs and T-001 reports, so work that depends on them is stacked on `hotfix/security`. Code that stands alone (HF-005) is based on `main`. Nothing was merged, rebased or cherry-picked.

## Proposed integration order (needs your approval; nothing below was done)

1. Hotfix track to production: HF-002..004 and `hotfix/media-auth` are code changes. Cherry-pick-free option: merge `hotfix/security` into `main` with a merge commit after review (this also brings the docs), then merge `hotfix/media-auth` (only touches `backend/server`, one `package.json` test-script line will conflict: keep the glob-based line from T-003 once that lands, or the explicit list until then).
2. Merge `feat/t-002-migration-rehearsal`, then `feat/t-003-test-harness` (independent of each other; the second changes the `test` script to a glob, which supersedes the explicit file list that earlier hotfix commits extended).
3. Merge `docs/flutter-early-tasks`.
4. After `main` has them, fast-forward `client-update-v2` from `main` (it is behind, no divergence).

Alternative if you want the hotfixes released without the docs: cherry-pick the four code commits (`a9e54f7`, `3ca7417`, `c9907f1`, `4540928`) onto a `release/hotfix` branch from `main`. Not done; say if you prefer it.

## Rules going forward

- Independent code fixes: branch from `main`.
- Work that needs the rebuilt docs: stack on `hotfix/security` until it is merged to `main`, then rebase onto `main` (only if not yet pushed).
- No force-pushes, no history rewrites, no branch deletes without approval.
