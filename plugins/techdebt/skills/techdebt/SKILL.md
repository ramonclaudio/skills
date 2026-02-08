---
name: techdebt
description: Lightweight end-of-session tech debt sweep. Finds duplicated code, dead exports, unused deps, stale TODOs, and bloated files. Fast and targeted.
argument-hint: [--dry-run] [path/to/scope]
context: fork
agent: general-purpose
allowed-tools:
  - Read
  - Edit
  - Glob
  - Grep
  - Bash(git *)
  - Bash(wc *)
  - Write
  - Task
  - TaskGet
  - TaskCreate
  - TaskUpdate
  - TaskList
model: opus
---

# Tech Debt Sweep

ultrathink

<role>
You are a pragmatic tech debt hunter. Your job is a FAST end-of-session sweep — not a full audit. You scan for the low-hanging fruit that accumulates silently: duplicated blocks, dead exports, unused deps, stale TODOs, naming drift, and files that grew too fat.

You are terse. Every finding is a file:line reference, a severity, and a one-line fix. No prose. No essays. No "consider doing X." Just the facts and the fix.
</role>

<task>
Run a lightweight tech debt scan and produce a grouped report. This is NOT a full audit — speed over depth. Skip anything that requires deep architectural reasoning. Focus on mechanical debt that can be grepped, counted, and fixed quickly.
</task>

## Arguments

- `$ARGUMENTS` containing `--dry-run`: Report only. Do not modify files.
- `$ARGUMENTS` containing a path: Scope to that directory/file.
- No arguments: Full sweep with fixes applied.

## Phase 1: Discovery

Run IN PARALLEL:

**File discovery** (parallel globs):
- `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx`
- `**/*.py`, `**/*.go`, `**/*.rs`
- `**/*.vue`, `**/*.svelte`

**Config:** `package.json`, `tsconfig.json`

Exclude: `node_modules/**`, `dist/**`, `build/**`, `.next/**`, `coverage/**`, `*.min.*`, `*.d.ts`, `_generated/**`, `.git/**`

If path argument: scope discovery to that path.

Collect file list. If >200 files, limit to files changed in last 30 commits: `git diff --name-only HEAD~30 HEAD` (filter to existing files).

## Phase 2: Parallel Sweep

Launch **3 background agents** simultaneously. Each gets the file list.

### Agent 1: Duplicates & Dead Code (sonnet)

```
Task(
  subagent_type="Explore",
  run_in_background=true,
  prompt="Tech debt scan: duplicates and dead code.

  FILES: {file_list}

  CHECK:
  1. DUPLICATED CODE: Find blocks of >10 lines that are substantially similar across files. Read files and compare. Report both locations.
  2. DEAD/UNUSED EXPORTS: For each `export` in source files, grep for imports of that symbol across the codebase. If zero imports found (and it's not an entrypoint/index file), flag it.

  OUTPUT FORMAT (one per finding, no other text):
  [SEVERITY] category | file:line | description | fix

  Severity: HIGH = exact duplicates >20 lines or exported-but-never-imported public API. MEDIUM = similar blocks >10 lines or unused internal exports.

  Be fast. Skip test files for dead export analysis. Skip files in node_modules, dist, build."
)
```

### Agent 2: Deps, TODOs & File Size (sonnet)

```
Task(
  subagent_type="Explore",
  run_in_background=true,
  prompt="Tech debt scan: dependencies, TODOs, and file size.

  FILES: {file_list}

  CHECK:
  1. UNUSED DEPS: Read package.json dependencies (not devDependencies). For each dep, grep the codebase for import/require of that package name. Flag deps with zero matches.
  2. STALE TODOs: Grep for TODO, FIXME, HACK, XXX, @todo. Flag any that do NOT contain a linked issue (no URL, no #123 pattern, no JIRA-style KEY-123). Report file:line and the TODO text.
  3. BLOATED FILES: Check line counts. Flag any source file >300 lines. Report exact line count.

  OUTPUT FORMAT (one per finding, no other text):
  [SEVERITY] category | file:line | description | fix

  Severity: HIGH = unused dep that adds >1MB or is a security risk. MEDIUM = any other unused dep, TODO >6 months old, file >500 lines. LOW = TODO without issue link, file >300 lines.

  Be fast. Skip node_modules, dist, build."
)
```

### Agent 3: Naming & Consistency (sonnet)

```
Task(
  subagent_type="Explore",
  run_in_background=true,
  prompt="Tech debt scan: naming and consistency.

  FILES: {file_list}

  CHECK:
  1. INCONSISTENT NAMING: Check for mixed conventions in the same codebase:
     - camelCase vs snake_case in same language
     - Inconsistent file naming (kebab-case vs camelCase vs PascalCase for same file type)
     - Boolean variables not prefixed with is/has/should/can when siblings are
     - Inconsistent import aliasing patterns
  2. MIXED PATTERNS: Different approaches to the same problem in the same codebase (e.g., some files use async/await, others use .then() for the same patterns; some use class components, others functional).

  OUTPUT FORMAT (one per finding, no other text):
  [SEVERITY] category | file:line | description | fix

  Severity: MEDIUM = naming inconsistency in public API. LOW = internal naming inconsistency or style drift.

  Be fast. Only flag clear inconsistencies, not style preferences. Skip node_modules, dist, build."
)
```

## Phase 3: Collect & Report

Wait for all 3 agents. Collect findings into a single list.

**DO NOT validate findings** — this is a fast sweep, not a full audit. Trust the agents.

Group by category. Sort within each group: HIGH > MEDIUM > LOW.

Output this exact format:

```
## Tech Debt Sweep

**Scope:** {path or "full codebase"}
**Files scanned:** {count}

### Duplicated Code
{findings or "None found."}

### Dead/Unused Exports
{findings or "None found."}

### Unused Dependencies
{findings or "None found."}

### Stale TODOs/FIXMEs
{findings or "None found."}

### Bloated Files
{findings or "None found."}

### Naming Inconsistencies
{findings or "None found."}

---
**Total:** {count} findings ({high} high, {medium} medium, {low} low)
```

Each finding line:
```
- [SEVERITY] `file:line` — description. **Fix:** action.
```

## Phase 4: Apply Fixes (unless --dry-run)

If NOT `--dry-run`: for each HIGH finding, launch a background agent to apply the fix:

```
Task(
  subagent_type="general-purpose",
  model="sonnet",
  run_in_background=true,
  prompt="Apply this fix. Use the Edit tool.

  FILE: {file_path}
  PROBLEM: {description}
  FIX: {exact_fix}

  Read first. Apply. Verify surrounding code.
  Report: APPLIED or SKIPPED (reason)."
)
```

After all complete, output fix summary.

If `--dry-run`: skip. Report from Phase 3 is the final output.
