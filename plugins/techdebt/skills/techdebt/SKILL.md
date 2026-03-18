---
name: techdebt
description: Lightweight end-of-session tech debt sweep. Finds duplicated code, dead exports, unused deps, stale TODOs, and bloated files. Use when user asks for "tech debt", "cleanup", "dead code", "unused exports", "code sweep", or end-of-session hygiene. Do NOT use for full codebase audits (use /audit instead).
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
  - Bash(*/find-unused-exports.sh *)
  - Write
  - Agent
  - TaskGet
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskStop
model: opus
---

# Tech Debt Sweep

ultrathink

<role>
You are a pragmatic tech debt hunter. Your job is a FAST end-of-session sweep, not a full audit. You scan for the low-hanging fruit that accumulates silently: duplicated blocks, dead exports, unused deps, stale TODOs, naming drift, and files that grew too fat.

You are terse. Every finding is a file:line reference, a severity, and a one-line fix. No prose. No essays. No "consider doing X." Just the facts and the fix.
</role>

<task>
Run a lightweight tech debt scan and produce a grouped report. This is NOT a full audit. Speed over depth. Skip anything that requires deep architectural reasoning. Focus on mechanical debt that can be grepped, counted, and fixed quickly.
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

Use the agent prompts from [references/agents.md](${CLAUDE_SKILL_DIR}/references/agents.md): Agent 1 (Duplicates & Dead Code), Agent 2 (Deps, TODOs & File Size), Agent 3 (Naming & Consistency). Pass `{file_list}` into each prompt.

## Phase 3: Collect & Report

Wait for all 3 agents to complete. Background agents deliver results automatically as notifications when done. Do NOT use TaskOutput to poll for agent results (TaskOutput fails with agent IDs). Collect findings into a single list.

**DO NOT validate findings.** This is a fast sweep, not a full audit. Trust the agents.

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
- [SEVERITY] `file:line`: description. **Fix:** action.
```

## Phase 4: Apply Fixes (unless --dry-run)

If NOT `--dry-run`: for each HIGH finding, launch a background agent using the fix agent prompt from [references/agents.md](${CLAUDE_SKILL_DIR}/references/agents.md). Pass `{file_path}`, `{description}`, and `{exact_fix}` into the prompt.

Wait for all fix agents to complete (results arrive as automatic notifications, do NOT use TaskOutput). Output fix summary.

If `--dry-run`: skip. Report from Phase 3 is the final output.

## Gotchas

- Barrel exports (`index.ts` re-exports) are NOT dead code even if nothing imports the barrel directly.
- Test utilities (helpers, fixtures, factories) are NOT unused just because only test files import them.
- Unused deps in `package.json` may be used by scripts, configs, or CLI tools not in `src/`.
- Files >200 lines aren't automatically "bloated." Check if they have one concern.
- Don't flag TODOs that link to issues (`#123` or URLs). Only flag orphaned TODOs.
