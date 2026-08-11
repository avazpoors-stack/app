# Project Analyzer

## Goal
Build a compact, evidence-based map of the repository before implementation.

## Inspect in this order
1. `MEMORY.md`
2. relevant product docs
3. `git status` / branch
4. top-level tree
5. Flutter/Dart manifests and entrypoints
6. backend manifests and entrypoints when relevant
7. tests and CI relevant to the task

## Token rules
- Search filenames/symbols before opening files.
- Read only relevant sections.
- Never dump generated files, lockfiles, build output, or full logs unless required.
- Do not reread unchanged files.

## Determine
- app modules/packages
- architecture and state management
- local persistence
- API boundaries
- offline/online behavior
- authentication
- test strategy
- CI/CD
- affected files

## Baseline
If practical, run the smallest build/test command that establishes current status. Separate pre-existing failures from task failures.

## Output
Return only:
`Architecture | Affected area | Relevant files | Existing tests | Baseline | Constraints | Next action`

Never invent repository facts.