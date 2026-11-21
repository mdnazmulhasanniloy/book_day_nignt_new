# Codex Guide

Codex follows the repository's existing contract. [GEMINI.md](GEMINI.md) is
the detailed canonical agent contract; this file is its concise entry point,
not a replacement.

Before work, read the relevant material in:

- [.agent/blueprint.md](.agent/blueprint.md) first. Use it as the system map. Do not re-walk the whole repository unless the blueprint does not cover the area being changed. Update the blueprint when a change moves a boundary it records.
- [GEMINI.md](GEMINI.md)
- [.agent/workflow.md](.agent/workflow.md)
- [.agent/code-quality.md](.agent/code-quality.md)
- [.agent/rules.md](.agent/rules.md)
- [.agent/architecture.md](.agent/architecture.md)
- the relevant README, docs, package scripts, and closest implementation

Follow: clarify → read → understand → audit → analyze → plan → explicit
approval → implement → validate → diff review → report. Do not guess: stop
and ask when a material requirement or convention is unclear. Do not modify
files before explicit approval.

The current working tree is the source of truth. Preserve unrelated changes:
do not overwrite, revert, stage, or otherwise alter them without explicit
direction. Use repository generators when applicable.

Do not perform destructive database or infrastructure operations without
explicit approval. Do not commit, push, tag, release, or deploy without
explicit approval.

Scoped guidance:

- [server/AGENTS.md](server/AGENTS.md)
- [worker/AGENTS.md](worker/AGENTS.md)
- [scheduler/AGENTS.md](scheduler/AGENTS.md)
- [prisma/AGENTS.md](prisma/AGENTS.md)

Leaf `AGENTS.md` files add directory-specific guidance only; they must not
contradict GEMINI.md or the `.agent/` contract.
