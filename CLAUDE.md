# BADANE — CLAUDE MASTER RULES

## Mission
Make this repository production-ready without unnecessary rewrites. Stack: Flutter/Dart mobile + FastAPI backend + Offline-First architecture.

## Mandatory session start
1. Read `MEMORY.md` completely.
2. Read only the relevant sections of `docs/BADANE_MASTERPLAN.md`, `docs/ROADMAP.md`, `docs/PLAN.md`, and `docs/DESIGN_REFERENCE.md`.
3. Inspect git status and current branch.
4. Establish a compact baseline before changing code.

## Evidence rule
Every factual project claim must be marked internally as `(user)`, `(verified: source)`, or `[assumed: ...]`. Never invent project state.

## Token rule
Use targeted search before reading files. Never reread unchanged files, dump full logs, or load unrelated skills. Prefer small patches and focused tests. Load only the skills needed for the task.

## Change rule
Preserve working architecture and user changes. Prefer the smallest correct change. No speculative rewrites, unnecessary dependencies, or unrelated cleanup.

## Validation rule
Implement → compile → targeted tests → diagnose → minimal fix → retest → broader validation when risk requires it. Never claim fixed/complete without evidence. If verification is impossible, say `NOT VERIFIED` and why.

## Quality gates
Check correctness, offline behavior, lifecycle, state, errors, security, privacy, performance, accessibility, tests, CI, and release implications as relevant.

## Project-specific safety
The product is fitness/wellness, not a medical diagnostic tool. Do not introduce diagnostic claims. Protect user data. Anonymous pilot exports must contain no identity data.

## Git
Never destroy unrelated work. Use a dedicated branch for substantial work. Review the final diff before completion.

## Autonomous behavior
Do not ask unnecessary questions. If the repository contains enough evidence, decide and continue. Ask only for material ambiguity, missing credentials/permissions, destructive actions, or choices that materially change the product.

## Final report
Changed / Validated / Result / Remaining. Keep it concise.

## Skill routing
Use the smallest relevant set from `.claude/skills/`. Typical feature flow: project-memory → project-analyzer → product-spec → flutter-architect → flutter-engineer → flutter-tester → code-reviewer. Add backend/security/performance/release skills only when relevant.
