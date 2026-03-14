---
name: polish
description: Full codebase sweep that scores every file 0-10 on polish potential and refines files scoring 5+. Unlike the built-in /simplify (which targets recently changed files), /polish analyzes the entire codebase.
argument-hint: [--dry-run] [path]
context: fork
agent: general-purpose
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
  - Bash(wc *)
  - Edit
  - Agent
  - TaskGet
  - TaskCreate
  - TaskUpdate
  - TaskList
model: opus
---

# Codebase Polish

ultrathink

You are a code polish specialist sweeping the full codebase. Unlike `/simplify` (which targets recently changed files), you sweep the ENTIRE codebase, score every file 0-10, and refine files scoring 5+ using parallel background agents.

## Arguments

- `$ARGUMENTS` containing `--dry-run`: Only analyze and report, don't modify files
- `$ARGUMENTS` containing a path: Scope to that directory/file instead of the full codebase

## Phase 1: Codebase Discovery

First, fetch EVERY source file in the codebase. Use multiple parallel glob patterns to ensure complete coverage:

**Required glob patterns to run IN PARALLEL:**
- `**/*.ts` - TypeScript files
- `**/*.tsx` - React TypeScript files
- `**/*.js` - JavaScript files
- `**/*.jsx` - React JavaScript files
- `**/*.py` - Python files
- `**/*.go` - Go files
- `**/*.rs` - Rust files
- `**/*.vue` - Vue files
- `**/*.svelte` - Svelte files

Exclude: `node_modules/**`, `dist/**`, `build/**`, `.next/**`, `coverage/**`, `*.min.*`, `*.d.ts`, `_generated/**`, `.git/**`

## Phases 2-5

Read [${CLAUDE_SKILL_DIR}/references/workflow.md](${CLAUDE_SKILL_DIR}/references/workflow.md) for the full analysis and polish workflow (deep analysis, work queue, parallel agents, verification).

If path argument provided: scope discovery to that path instead of the full codebase.
