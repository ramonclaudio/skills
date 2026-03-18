---
name: polish
description: Full codebase sweep scoring every file 0-10 on polish potential, refining files scoring 5+ via parallel agents. Unlike /simplify (recently changed files only), /polish sweeps the entire codebase.
argument-hint: [--dry-run] [path]
context: fork
agent: general-purpose
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - TaskGet
  - TaskCreate
  - TaskUpdate
  - TaskList
model: opus
---

# Codebase Polish

ultrathink

You coordinate a full codebase polish. You score every source file 0-10 on polish potential and dispatch parallel background agents to refine files scoring 5+.

You are a coordinator. You read and analyze files, create tasks, and spawn worker agents. You do NOT edit files directly.

## Arguments

- `$ARGUMENTS` containing `--dry-run`: analyze and report only, no modifications
- `$ARGUMENTS` containing a path: scope to that directory/file

## Phase 1: Codebase Discovery

Glob all source files using parallel patterns:

- `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx`
- `**/*.py`, `**/*.go`, `**/*.rs`
- `**/*.vue`, `**/*.svelte`

Exclude: `node_modules/**`, `dist/**`, `build/**`, `.next/**`, `coverage/**`, `*.min.*`, `*.d.ts`, `_generated/**`, `.git/**`

If path argument provided, scope discovery to that path.

## Phases 2-5

Read [${CLAUDE_SKILL_DIR}/references/workflow.md](${CLAUDE_SKILL_DIR}/references/workflow.md) for the analysis, work queue, parallel agents, and verification workflow.

## Gotchas

- Generated files (`*.d.ts`, `_generated/`, codegen output) get picked up by glob patterns. The exclusion list must be checked before scoring or agents will "polish" auto-generated code.
- Polishing test files can silently break assertions. Renaming variables, simplifying ternaries, or removing "dead" setup code in tests often changes behavior. Score test files conservatively.
- Agents run in parallel and can conflict if two files import from each other. One agent renaming an export while another reads the old name causes build failures.
- 5 simultaneous agents on a large codebase can hit Claude rate limits. If agents start failing, reduce concurrency to 2-3.
