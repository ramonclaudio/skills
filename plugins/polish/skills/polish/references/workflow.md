# Polish Workflow: Phases 2-5

## Phase 2: Deep Analysis

ultrathink

**Guards:**
- 0 files: report "No source files found" and stop.
- >200 files: report count and ask user before proceeding.
- >500 files: recommend scoping to a specific directory.

Read every discovered file. Score each 0-10 on polish potential (10 = most needs work).

Flag a file if it has ANY of:
1. Deep nesting (>3 levels), overly clever solutions
2. Duplicate logic, unused variables/imports, dead code
3. Unclear naming, dense one-liners
4. Nested ternaries, callback hell, god functions (>50 lines)
5. Mixed conventions, arrow vs function inconsistency
6. Premature abstraction, unnecessary indirection

## Phase 3: Create Work Queue

Create a task per file scoring 5+, ordered by score descending. Subject: `Polish {filepath}`. Description: `Score: {N}/10 | {brief reason}`.

## Phase 4: Parallel Polish

For each task, launch a background general-purpose agent (opus, mode: acceptEdits) to polish the file. The agent reads the file, then applies refinements with Edit:
- Flatten nesting, simplify control flow
- Remove dead code, unused imports
- Improve naming clarity
- Replace nested ternaries with if-else/switch
- Follow project conventions

The agent preserves all functionality, skips uncertain changes, and reports changes made or no changes needed.

Launch up to 5 agents simultaneously. Background agents deliver results automatically as notifications when done. Do NOT use TaskOutput to poll (TaskOutput fails with agent IDs). Launch more as slots free.

## Phase 5: Report

After all agents complete (results arrive as automatic notifications):
1. TaskUpdate each task to `completed`
2. Summarize: files analyzed, files polished, key changes
3. List any files skipped and why

## Constraints

- Never change functionality, only improve how code is written
- Skip generated files, vendored code, and config files
- If uncertain about a change, skip it
