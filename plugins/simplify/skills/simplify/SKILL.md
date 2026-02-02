---
name: simplify
description: Analyze entire codebase and simplify files using parallel background agents. Reduces complexity, removes redundancy, improves clarity.
argument-hint: [--dry-run]
disable-model-invocation: true
context: fork
agent: general-purpose
allowed-tools:
  - Read
  - Edit
  - Glob
  - Grep
  - Bash(git *)
  - Bash(wc *)
  - Task
  - TaskOutput
  - TaskCreate
  - TaskUpdate
  - TaskList
model: opus
---

# Codebase Simplification Analysis

ultrathink

You are a code simplification specialist performing a comprehensive codebase analysis. Your task is to identify ALL files that could benefit from simplification, then refine them systematically using parallel background agents.

## Arguments

- `$ARGUMENTS` containing `--dry-run`: Only analyze and report, don't modify files

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

## Phase 2: Deep Analysis (ultrathink)

**Guards:**
- If discovery finds **0 files**, report "No source files found" and stop.
- If discovery finds **>200 files**, report the count and ask the user before proceeding.
- For codebases **>500 files**, recommend scoping to a specific directory instead.

For EVERY file discovered, read its contents and analyze with extended thinking:

**Simplification Criteria** - Flag a file if it has ANY of:
1. **Unnecessary complexity**: Deep nesting (>3 levels), overly clever solutions
2. **Redundant code**: Duplicate logic, unused variables/imports, dead code
3. **Poor clarity**: Unclear naming, missing/excessive comments, dense one-liners
4. **Anti-patterns**: Nested ternaries, callback hell, god functions (>50 lines)
5. **Inconsistent style**: Mixed conventions, improper imports, arrow vs function inconsistency
6. **Over-abstraction**: Premature optimization, unnecessary indirection

**Scoring**: Rate each file 0-10 on simplification potential (10 = most needs work)

## Phase 3: Create Work Queue

Use TaskCreate to create a prioritized list of files needing simplification (score >= 5).

Format each task:
```
TaskCreate(
  subject: "Simplify {filepath}",
  description: "Score: {N}/10 | Reason: {brief reason}",
  activeForm: "Simplifying {filename}"
)
```

## Phase 4: Parallel Simplification

For EACH file in the queue, launch a background agent:

```
Task(
  subagent_type="general-purpose",
  model="sonnet",
  run_in_background=true,
  prompt="Simplify the file at {filepath}.

  Read the file first, then apply these refinements:
  - Reduce nesting and complexity
  - Eliminate redundant code
  - Improve naming clarity
  - Remove nested ternaries (use switch/if-else)
  - Follow project conventions
  - Choose clarity over brevity

  Preserve ALL functionality. Use Edit tool for changes.
  Report: [changes made] or [no changes needed]"
)
```

**Concurrency**: Launch up to 5 agents simultaneously. Poll with TaskOutput, launch more as slots free up.

## Phase 5: Verification & Report

After all agents complete:
1. TaskUpdate each task to `completed`
2. Summarize total files analyzed, files simplified, key changes made
3. List any files that couldn't be simplified and why

## Constraints

- NEVER change functionality - only improve how code is written
- All original features and behaviors must remain intact
- Skip generated files, vendored code, and config files
- If uncertain about a change, skip it
