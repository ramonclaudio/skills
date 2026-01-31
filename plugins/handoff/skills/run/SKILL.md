---
name: run
description: Session continuity for Claude Code. Gather context at start, archive state at end.
argument-hint: init | start | end
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(npm *)
  - Bash(bun *)
  - Bash(pnpm *)
  - Bash(yarn *)
  - Bash(mkdir *)
  - Bash(cp *)
  - Bash(rm *)
  - Bash(date *)
  - Bash(ls *)
  - Bash(test *)
  - Bash(wc *)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskGet
  - TaskList
model: sonnet
---

# Handoff

ultrathink

<role>
You are a senior engineer who treats session continuity like hospital shift changes. Bad handoffs lose context, waste time, and repeat mistakes. You capture state precisely. Exact errors, specific file:line references, honest severity assessments. You never write vague resume points.
</role>

<task>
Manage session handoffs: gather context at start, archive state at end. Each handoff must be specific enough that a fresh session can resume without asking questions.

The plugin auto-handles most scenarios via hooks:
- **Auto-init**: SessionStart hook bootstraps .handoff/ for new git repos
- **Smart reinject**: SessionStart hook injects ranked context (blockers > resume > watch-outs)
- **Auto-save**: PreCompact hook captures lightweight session state before every compaction
- **Event capture**: PostToolUse hook logs bash errors, file edits, test/build runs
- **Git notes**: Auto-save writes session metadata as git notes on HEAD

The explicit commands below provide **thorough** versions of what hooks do automatically.
</task>

## Arguments

- `$ARGUMENTS` containing `init`: Run INIT (thorough project setup — hooks auto-bootstrap minimally)
- `$ARGUMENTS` containing `start` or empty: Run START (full context load — hooks smart-reinject for most cases)
- `$ARGUMENTS` containing `end`: Run END (thorough archive — hooks auto-save lightweight version)

## State Architecture

Two storage backends:
- `.handoff/.context-state` (key=value) — high-frequency context metrics (compaction count, context %, flags)
- `.handoff/state.json` (JSON) — structured session state (done, failed, blockers, resume, events)
- `.handoff/HANDOFF.md` — human-readable view generated from state.json

The END phase writes to state.json and generates HANDOFF.md from it. Hooks read both files.

## CONTEXT.md Design

CONTEXT.md has two types of sections:

**Auto-generated** (updated on INIT and END):
- `## Project` - name, description, links
- `## Structure` - current file tree
- `## Invocation` - entry points, commands

**Curated** (preserved, only manual edits):
- `## Stack` - technologies, versions
- `## Patterns` - how things work
- `## What Never Works` - gotchas, anti-patterns

## INIT

If `$ARGUMENTS` = "init":

```bash
mkdir -p .handoff/sessions
```

**Scan project structure:**
```bash
ls -la
```

Use Glob tool to find key files:
```
Glob: **/*.md, **/*.json, **/package.json, **/*.lock*
```

**Detect package manager:**
```bash
ls bun.lockb package-lock.json pnpm-lock.yaml yarn.lock 2>/dev/null | head -1
```

Write `.handoff/CONTEXT.md`:
```markdown
# [Project Name]

> [One-line description from package.json or README]

## Links

| Resource | URL |
|----------|-----|
| Repository | [from git remote] |
| Local | [pwd] |

## Stack

<!-- CURATED: Edit manually -->
| Layer | Tech | Version |
|-------|------|---------|
| Runtime | [detected] | |
| Framework | | |

## Structure

<!-- AUTO: Regenerated on END -->
```
[file tree from scan]
```

## Invocation

<!-- AUTO: Regenerated on END -->
| Method | Command | Purpose |
|--------|---------|---------|
| Dev | `[pkg] run dev` | Start dev server |
| Build | `[pkg] run build` | Production build |
| Test | `[pkg] test` | Run tests |
| Lint | `[pkg] run lint` | Lint check |

## Patterns

<!-- CURATED: Edit manually -->
Key patterns and conventions used in this codebase.

## What Never Works

<!-- CURATED: Edit manually -->
| Problem | Solution |
|---------|----------|
```

Write `.handoff/HANDOFF.md`:
```markdown
# Handoff

> Session: YYYY-MM-DD HH:MM
> Severity: 🟢 READY

## Health
| Check | Status |
|-------|--------|
| Build | ⏸️ not run |
| Tests | ⏸️ not run |
| Lint | ⏸️ not run |

## Git
- Branch: main
- Status: clean

## Done
_Nothing yet._

## Failed
_None._

## Blockers
_None._

## Watch Out For
_None yet._

## Resume
**Next:** Run `/handoff:run start` to begin
**Files:** -
**Context:** Fresh initialization
```

**Check for project CLAUDE.md:**
```
Read CLAUDE.md
```

If CLAUDE.md exists, add a Compact Instructions section (if not present) so handoff resume points survive context compaction:
```markdown
<!-- Compact Instructions -->
<!-- Handoff: see .handoff/HANDOFF.md for session state -->
```

If no CLAUDE.md exists, note it — the user may want to create one with `/init`.

Done. Run `/handoff:run start` to begin first session.

## START

If `$ARGUMENTS` is empty or = "start":

### Phase 0: Detect Session Type

Determine how this session was started. This affects how much context the handoff needs to provide.

**Check for resumed/forked session:**
The conversation history may already contain prior context if the user ran `claude --continue`, `claude --resume`, or `claude --continue --fork-session`. Look for conversation messages above this skill invocation.

- **Fresh session** (no prior messages): Full handoff load — this is the primary use case. The handoff provides ALL context.
- **Resumed session** (`--continue`/`--resume`): Conversation history is preserved but may be compacted. Handoff provides supplementary context — focus on what may have been lost to compaction (blockers, resume point, watch-outs).
- **Forked session** (`--fork-session`): Conversation history preserved with new session ID. Tasks from the original session are NOT inherited. Re-hydrate tasks.

### Phase 1: Establish Timeline

```bash
ls -1 .handoff/sessions/*.md 2>/dev/null | sort -r | head -1
```

Session files use Claude session IDs (v1.1.0+) or timestamps (legacy).
If no sessions, this is first start - use all available history.

### Phase 2: Validate CONTEXT.md

**2a. Read CONTEXT.md**
```
Read .handoff/CONTEXT.md
```

**2b. Check for drift**
Extract file paths from `## Structure` section. Verify they exist:
```bash
# For each path in Structure section
test -e "[path]" && echo "✓ [path]" || echo "✗ MISSING: [path]"
```

**2c. Report drift**
If any files are missing or new files exist that aren't in Structure:
```
⚠️  CONTEXT DRIFT DETECTED
├─ Missing: [list of files in CONTEXT.md that don't exist]
├─ New: [list of key files not in CONTEXT.md]
└─ Run `/handoff end` to update, or edit CONTEXT.md manually
```

### Phase 3: Gather State

**3a. Project Identity**
```
Read .handoff/CONTEXT.md
```
Extract: stack, commands, critical paths, patterns, gotchas.

**3b. Last Handoff State**
```
Read .handoff/HANDOFF.md
```
Extract: severity, health status, done, failed, blockers, watch-out-for, resume point.

**3c. Current Git State**
```bash
git branch --show-current
git status -s | head -20
```

**3d. Commits Since Last Session**
```bash
git log --since="YYYY-MM-DD HH:MM" --format="%h %s%n%b" 2>/dev/null
```
If no session history, use `git log -10 --format="%h %s%n%b"`.

**3e. PR Activity Since Last Session**
```bash
# Currently open
gh pr list --state=open --json number,title,body,headRefName 2>/dev/null

# Merged since
gh pr list --state=merged --search "merged:>YYYY-MM-DD" --json number,title,body 2>/dev/null

# Opened since
gh pr list --state=all --search "created:>YYYY-MM-DD" --json number,title,body,state 2>/dev/null
```

**3f. Active Tasks (Hydration Check)**

Tasks are session-scoped — they don't persist across sessions by default. The handoff system uses HANDOFF.md as persistent truth and hydrates Tasks from it on START.

```
TaskList  # Check for tasks from current or shared task list
```

For each task found:
```
TaskGet(taskId: "[id]")  # Read full description and dependencies
```

Identify:
- Tasks with `handoff: true` metadata → resume points from prior sessions
- Tasks with `blocker: true` metadata → unresolved blockers
- Any other pending/in-progress tasks → ongoing work

If `CLAUDE_CODE_TASK_LIST_ID` is set, tasks persist across sessions via a named task list in `~/.claude/tasks/`. Check for this:
```bash
echo "${CLAUDE_CODE_TASK_LIST_ID:-not set}"
```

### Phase 4: Assess Current Health

Check if state has drifted since handoff:
- Did git status change? (new commits from elsewhere?)
- Are there uncommitted changes not in handoff?

### Phase 5: Hydrate Tasks from HANDOFF.md

The hydration pattern: HANDOFF.md is persistent truth, Tasks are session-scoped execution.

**5a. Complete previous resume tasks**

For any existing tasks with `handoff: true` metadata, mark complete (session started = resume point achieved):
```
TaskUpdate(taskId: "[id]", status: "completed")
```

**5b. Hydrate blockers as Tasks**

For each unchecked blocker in HANDOFF.md `## Blockers` section, create a blocking task:
```
TaskCreate(
  subject: "[Blocker description]",
  description: "[Full context from HANDOFF.md]",
  activeForm: "Resolving: [brief]",
  metadata: { "blocker": true, "handoff": true, "session": "previous" }
)
```

If multiple blockers exist, set up dependencies between them using `addBlocks`/`addBlockedBy` where one blocker depends on another.

**5c. Hydrate resume point as Task**

Create a task for the resume point from HANDOFF.md `## Resume` section:
```
TaskCreate(
  subject: "[Next action from Resume]",
  description: "Files: [files to read]\nContext: [reasoning]",
  activeForm: "Resuming: [brief]",
  metadata: { "handoff": true, "resume": true }
)
```

If blockers were created, set the resume task as blocked by them:
```
TaskUpdate(taskId: "[resume-id]", addBlockedBy: ["[blocker-ids]"])
```

**5d. Report hydration**

Note how many tasks were hydrated for the read-back output.

### Phase 6: Output Read-Back

**Context-adaptive output:**
- **Fresh session**: Full verbose output (all sections below)
- **Resumed session** (`--continue`/`--resume`): Compact output — skip HEALTH AT HANDOFF and CURRENT STATE sections (user already has context). Focus on: severity, blockers, watch-outs, resume point, and any drift since handoff.
- **Forked session**: Full output + note that tasks were re-hydrated (original session's tasks not inherited)

The SessionStart hook already injected a brief summary. This full read-back adds detail.

```
╔══════════════════════════════════════════════════════════════╗
║  HANDOFF RECEIVED                                            ║
╠══════════════════════════════════════════════════════════════╣
║  Project: [name]                                             ║
║  Stack: [from CONTEXT.md]                                    ║
║  Session: [fresh | resumed | forked]                         ║
║  Severity: [🔴 CRITICAL | 🟡 IN PROGRESS | 🟢 READY]         ║
╚══════════════════════════════════════════════════════════════╝

[If drift detected:]
⚠️  CONTEXT DRIFT
[list of missing/new files]

SINCE LAST SESSION ([date], [N] days ago)
├─ Commits: [N]
├─ PRs: [N] merged, [N] opened, [N] open
└─ Tasks: [N] hydrated ([N] blockers, [N] resume)

HEALTH AT HANDOFF
├─ Build: [✓|✗|⏸️]
├─ Tests: [✓ N/N | ✗ N failed | ⏸️]
└─ Lint: [✓|✗|⏸️]

CURRENT STATE
├─ Branch: [branch]
├─ Status: [clean | N modified, N untracked]
└─ Drift: [none | ⚠️ changed since handoff]

⚠️  WATCH OUT FOR
[bulleted list from HANDOFF.md]

🚫 BLOCKERS ([N])
[bulleted list from HANDOFF.md]

❌ FAILED (Don't Retry)
[list of failed items with reasons]

▶️  RESUME
[Next action from HANDOFF.md]
[Files to read]
[Context/reasoning]

────────────────────────────────────────────────────────────────
Ready. What would you like to work on?
```

**Context loaded. Ready to proceed with user's task.**

## END

If `$ARGUMENTS` = "end":

### Phase 1: Archive Current State

```bash
cp .handoff/HANDOFF.md ".handoff/sessions/${CLAUDE_SESSION_ID}.md"
```

### Phase 1b: Signal Handoff Completion

Write `handoff_end_completed=true` to `.handoff/.context-state` so all auto-trigger hooks stop nagging immediately:

```bash
STATE_FILE=".handoff/.context-state"
if [ -f "$STATE_FILE" ]; then
  sed -i '' 's/^handoff_end_completed=.*/handoff_end_completed=true/' "$STATE_FILE"
else
  echo "handoff_end_completed=true" > "$STATE_FILE"
fi
```

This MUST happen early — before health checks or any long-running phase — so the Stop hook doesn't block mid-END.

### Phase 2: Capture Health Status

Run health checks using commands from CONTEXT.md:

```bash
# Build (capture exit code and last 5 lines)
npm run build 2>&1 | tail -5; echo "EXIT:$?"

# Tests (capture exit code and summary)
npm run test 2>&1 | tail -10; echo "EXIT:$?"

# Lint (capture exit code and issues)
npm run lint 2>&1 | tail -5; echo "EXIT:$?"
```

Detect package manager from lockfile:
- `bun.lockb` → bun
- `pnpm-lock.yaml` → pnpm
- `yarn.lock` → yarn
- `package-lock.json` → npm

### Phase 3: Capture Git State

```bash
git branch --show-current
git status -s | head -20
git log -5 --format="%h %s"
```

### Phase 4: Update CONTEXT.md (Auto Sections Only)

**4a. Scan current structure:**

Use Glob tool to get current file structure:
```
Glob: **/*.md, **/*.json, **/*.ts, **/*.js, **/*.py
```
(Glob automatically excludes node_modules and .git)

**4b. Read current CONTEXT.md:**
```
Read .handoff/CONTEXT.md
```

**4c. Update auto sections, preserve curated:**

Parse CONTEXT.md and identify sections by `<!-- AUTO: -->` and `<!-- CURATED: -->` markers.

- **Preserve**: `## Stack`, `## Patterns`, `## What Never Works` (curated)
- **Regenerate**: `## Structure`, `## Invocation` (auto)

Write updated CONTEXT.md with:
- New `## Structure` reflecting current file tree
- Updated `## Invocation` if commands changed
- All curated sections preserved exactly

### Phase 5: Analyze Session (Automated)

**⚠️ Compaction warning:** If the conversation has been compacted (auto or manual), early context may be lost. The analysis below works best when END is run BEFORE context fills up. If compaction has occurred, rely more heavily on git log, task list, and file changes rather than conversation memory.

**Pre-compact snapshot:** Check if `.handoff/.pre-compact` exists (written by the PreCompact hook). If present, use it to supplement conversation memory with git state captured before compaction:
```
Read .handoff/.pre-compact
```

**Infer from conversation context - DO NOT ASK USER:**

1. **Severity** - Derive from health checks:
   - 🔴 CRITICAL - Build failing OR tests failing with blocking errors
   - 🟡 IN PROGRESS - Tests failing OR uncommitted work OR mid-feature
   - 🟢 READY - Build ✓, Tests ✓, Lint ✓, git clean

2. **Done** - Extract from session:
   - Commits made this session (from git log)
   - PRs created/merged
   - Files successfully modified
   - Features/fixes completed

3. **Failed** - Extract from session:
   - Commands that returned non-zero exit codes
   - Error messages encountered
   - Approaches that were abandoned
   - ALWAYS include: Tried / Error / Why / Need

4. **Blockers** - Extract from session:
   - External dependencies mentioned as unavailable
   - Permissions/credentials that were missing
   - Decisions that couldn't be made
   - APIs/services that were down

5. **Watch Out For** - Extract from session:
   - Gotchas discovered (things that surprised us)
   - Workarounds that were needed
   - Environment-specific behaviors
   - Edge cases encountered

6. **Resume Point** - Derive from session:
   - If mid-feature: next logical step in current work
   - If blocked: what to do when blocker resolves
   - If complete: next item from backlog/issues
   - ALWAYS include specific file:line when possible

### Phase 6: Write state.json + HANDOFF.md

**6a. Write state.json** (machine-readable source of truth):

```bash
# Read .handoff/state.json, update all fields:
```

Use jq or Write tool to update `.handoff/state.json` with:
- `session_id` → `${CLAUDE_SESSION_ID}`
- `severity` → `"CRITICAL"` | `"IN_PROGRESS"` | `"READY"`
- `health` → `{"build": "✓ pass", "tests": "✓ 12/12", "lint": "✓ clean"}`
- `done` → array of `{"description": "...", "ref": "abc1234"}`
- `failed` → array of `{"description": "...", "tried": "...", "error": "...", "why": "...", "need": "..."}`
- `blockers` → array of `{"description": "...", "resolved": false}`
- `resume` → `{"next": "...", "files": ["..."], "context": "..."}`
- `watch_out_for` → array of strings
- `git` → `{"branch": "...", "status": "clean|dirty"}`
- Keep `events` array intact (captured by PostToolUse hook)

**6b. Generate HANDOFF.md** from state.json:

The HANDOFF.md format below is generated from state.json for human readability.

### Phase 6 Template: HANDOFF.md

```markdown
# Handoff

> Session: ${CLAUDE_SESSION_ID}
> Severity: [🔴 CRITICAL | 🟡 IN PROGRESS | 🟢 READY]

## Health
| Check | Status | Detail |
|-------|--------|--------|
| Build | [✓\|✗\|⏸️] | [pass/fail/error message] |
| Tests | [✓\|✗\|⏸️] | [N/N passing or failure info] |
| Lint | [✓\|✗\|⏸️] | [clean/N warnings/N errors] |

## Git
- Branch: [branch]
- Status: [clean/dirty]
- Last commits:
  ```
  [hash] [message]
  [hash] [message]
  [hash] [message]
  ```

## Done
- [x] [Concrete accomplishment with PR/commit ref]
- [x] [Another accomplishment]

## Failed
### [Issue Name]
- **Tried:** [What was attempted]
- **Error:** [Exact error message]
- **Why:** [Root cause analysis]
- **Need:** [What would fix it]

## Blockers
- [ ] [Blocker with context]
- [ ] [Another blocker]

## Watch Out For
- [Gotcha or warning]
- [Another gotcha]

## Resume
**Next:** [Specific action at file:line]
**Files:** [comma-separated list of files to read first]
**Context:** [Why this is the right next step]
```

### Phase 6b: Sync Resume to CLAUDE.md

The resume point is the most critical piece of the handoff. Write it to CLAUDE.md's Compact Instructions section so it survives context compaction and auto-loads at session start — even without running `handoff start`.

```
Read CLAUDE.md
```

If CLAUDE.md exists, update (or create) the Compact Instructions section:
```markdown
<!-- Compact Instructions -->
<!-- Handoff resume: [Next action from Resume] -->
<!-- Handoff severity: [CRITICAL|IN PROGRESS|READY] -->
<!-- Handoff files: [files to read] -->
<!-- See .handoff/HANDOFF.md for full state -->
```

If Compact Instructions already exists with non-handoff content, append — don't overwrite.

This ensures:
- Fresh sessions see the resume point even before running `handoff start`
- Compacted sessions retain the resume point through auto-compaction
- The full handoff state lives in .handoff/ — CLAUDE.md just has the pointer

### Phase 7: Validate Handoff Quality

**REQUIRED (fail if missing):**
- [ ] Severity is set
- [ ] Health status captured
- [ ] Resume has specific file:line
- [ ] Resume has files to read
- [ ] If failures exist, they have root cause analysis

**WARNINGS:**
- [ ] File exceeds 100 lines (bloat risk)
- [ ] Resume is vague ("continue working on X")
- [ ] No watch-out-for items (really nothing learned?)
- [ ] Health checks all skipped

### Phase 8: Create Handoff Tasks

Create Tasks that persist the session state for the next session. Tasks are stored in `~/.claude/tasks/` and visible via `Ctrl+T`.

**8a. Create blocker tasks**

For each item in `## Blockers`, create a task:
```
TaskCreate(
  subject: "BLOCKER: [description]",
  description: "[Full context, what's needed to resolve]",
  activeForm: "Resolving: [brief]",
  metadata: { "blocker": true, "handoff": true, "session": "${CLAUDE_SESSION_ID}" }
)
```

**8b. Create resume task**

```
TaskCreate(
  subject: "[Next action from ## Resume]",
  description: "Files: [files from Resume]\nContext: [reasoning from Resume]",
  activeForm: "Resuming: [brief description]",
  metadata: { "handoff": true, "resume": true, "session": "${CLAUDE_SESSION_ID}" }
)
```

**8c. Set up dependencies**

If blockers were created, the resume task should be blocked by them:
```
TaskUpdate(taskId: "[resume-id]", addBlockedBy: ["[blocker-ids]"])
```

This creates a dependency graph: blockers must be resolved before the resume point can be started. The next session's START will hydrate these and show the blocked/unblocked state.

### Phase 8c: Write Git Notes

Attach session metadata to the current HEAD commit as a git note:

```bash
git notes --ref=handoff add -f -m "handoff: [SEVERITY] | session ${CLAUDE_SESSION_ID} | [timestamp]
resume: [next action]
done: [N] items | failed: [N] | blockers: [N]" HEAD
```

This enables `git log --notes=handoff` to show full session history inline with commits. Session history lives in git, not just files.

### Phase 9: Confirm

Check `.handoff/.context-state` for `compaction_count`. If >= 2, this was likely auto-triggered and context is degraded — note it in output.

```
╔══════════════════════════════════════════════════════════════╗
║  HANDOFF COMPLETE                                            ║
╠══════════════════════════════════════════════════════════════╣
║  Archived: sessions/${CLAUDE_SESSION_ID}.md                  ║
║  Severity: [emoji + label]                                   ║
[If compaction_count >= 2:]
║  ⚠️  Auto-triggered (context was degraded)                    ║
╚══════════════════════════════════════════════════════════════╝

HEALTH
├─ Build: [status]
├─ Tests: [status]
└─ Lint: [status]

SESSION SUMMARY
├─ Done: [N] items
├─ Failed: [N] items (documented)
├─ Blockers: [N] active
├─ Watch-outs: [N] added
└─ Tasks created: [N] ([N] blockers + resume)

CONTEXT UPDATED
├─ Structure: [regenerated | unchanged]
├─ Invocation: [regenerated | unchanged]
├─ Curated sections: preserved
└─ CLAUDE.md: [resume synced | not found | unchanged]

RESUME POINT
[Next action]

TIP: Run /rename to name this session for easy retrieval.
────────────────────────────────────────────────────────────────
Safe to end session.
```

## Severity Guide

| Level | When | Meaning |
|-------|------|---------|
| 🔴 CRITICAL | Production down, data loss risk, security issue | Drop everything, fix now |
| 🟡 IN PROGRESS | Mid-feature, tests failing, WIP | Continue current work |
| 🟢 READY | All green, clean state | Pick up new work |

## Health Check Commands

Detect from CONTEXT.md or infer from lockfile:

| Lockfile | Build | Test | Lint |
|----------|-------|------|------|
| bun.lockb | `bun run build` | `bun test` | `bun run lint` |
| package-lock.json | `npm run build` | `npm test` | `npm run lint` |
| pnpm-lock.yaml | `pnpm build` | `pnpm test` | `pnpm lint` |
| yarn.lock | `yarn build` | `yarn test` | `yarn lint` |

## Anti-Patterns

**DON'T:**
- Skip health checks on END (you're leaving blind)
- Write vague resume points ("keep working on auth")
- Omit failure root cause (next session repeats mistake)
- Ignore blockers (they don't disappear)
- Leave severity at 🟢 when tests are failing
- Let CONTEXT.md go stale (structure drift = confusion)
- Wait until context is full to run END (compaction loses detail)
- Forget to sync resume to CLAUDE.md (it won't survive compaction otherwise)
- Wait for auto-trigger to force END (context is already degraded by then)

**DO:**
- Capture exact error messages in failures
- Reference specific file:line in resume
- Document gotchas immediately when discovered
- Be honest about severity
- Validate handoff before ending
- Update CONTEXT.md structure on END
- Run END before context fills up (check with `/context`)
- Sync critical resume state to CLAUDE.md Compact Instructions
- Run END proactively at the first compaction notice

## Automatic Behavior

The plugin runs entirely via hooks. No manual commands needed for basic operation.

### Hook Lifecycle

| Event | Hook | What It Does |
|-------|------|-------------|
| Session start | `session-start.sh` | Auto-init new repos, smart reinject from state.json |
| Every tool use | `event-capture.sh` | Logs bash errors, file edits, test/build runs to state.json |
| Before compaction | `pre-compact.sh` | Git snapshot + auto-save (lightweight END) |
| After compaction | `compact-reinject.sh` | Ranked context reinject + escalating warnings |
| Every prompt | `prompt-reminder.sh` | Context degradation reminders via additionalContext |
| Claude stops | `stop-gatekeeper.sh` | Blocks at critical threshold, forces END |
| `/clear` | `session-clear.sh` | Resets all counters |

### Auto-Init

On session start in a git repo without `.handoff/`:
- Creates `.handoff/` structure
- Detects project name, runtime, remote from package.json/lockfile/git
- Generates minimal CONTEXT.md
- Initializes state.json
- No user action required. `/handoff:run init` provides thorough setup.

### Auto-Save

On every PreCompact (before context compaction):
- Infers done items from git commits since session start
- Infers failures from bash error events captured by PostToolUse
- Infers resume from recently modified files
- Writes state.json + generates HANDOFF.md
- Writes git notes on HEAD
- No user action required. `/handoff:run end` provides thorough archive with health checks.

### Smart Reinject

On session start/resume:
- Reads state.json, outputs context ranked by priority:
  1. Severity
  2. Blockers (highest priority)
  3. Resume point
  4. Watch-outs
  5. Failed items
  6. Health summary
- Only forces `/handoff:run start` for CRITICAL severity or 3+ blockers
- Most sessions don't need explicit start

### Event Capture

PostToolUse hook logs to state.json events array:
- `bash_error` — non-zero exit codes
- `test_run` — test command executions
- `build_run` — build command executions
- `file_edit` / `file_write` — file modifications
- Capped at 50 events. Used by auto-save to infer session state.

### Escalation Ladder

| Level | Trigger | Action |
|-------|---------|--------|
| Notice | 1 compaction OR 75%+ context | Gentle reminder via additionalContext |
| Urgent | 2+ compactions OR 85%+ context | Directive to invoke `/handoff:run end` |
| Critical | 3+ compactions OR (2+ AND 90%+) | Stop hook blocks, forces END |

### Git Notes

Session metadata stored as git notes on HEAD:
```bash
git log --notes=handoff  # View session history inline with commits
```

### Edge Cases

| Case | Handling |
|------|----------|
| No `.handoff/` + git repo | Auto-init creates it |
| No `.handoff/` + no git | All hooks exit silently |
| `/clear` | Resets counters, clears events, keeps state.json structure |
| Manual `/handoff:run end` | Sets `handoff_end_completed=true`, all hooks exit early |
| Stop hook loop | `stop_hook_active` flag allows at most one block per cycle |
| No status line bridge | Falls back to compaction count only |
| Stale bridge data (>60s) | Hooks ignore `context_pct`, use compaction count alone |
| Old .handoff/ (no state.json) | Hooks create state.json, fallback to HANDOFF.md parsing |

## Task API Reference

Tasks are session-scoped by default. HANDOFF.md is the persistent truth; Tasks are the session execution layer. This is the **hydration pattern**: persistent files → session Tasks on START, session Tasks → persistent files on END.

To share tasks across sessions, set `CLAUDE_CODE_TASK_LIST_ID`:
```bash
CLAUDE_CODE_TASK_LIST_ID=my-project claude
```

### TaskCreate

| Field | Required | Description |
|-------|----------|-------------|
| `subject` | yes | Imperative title ("Fix auth bug", "Resolve blocker") |
| `description` | yes | Full context, acceptance criteria, file references |
| `activeForm` | no | Present continuous for spinner ("Fixing auth bug") |
| `metadata` | no | Arbitrary key-value pairs for filtering |

Handoff metadata conventions:
- `handoff: true` — created by handoff skill
- `resume: true` — this is the resume point
- `blocker: true` — this is an unresolved blocker
- `session: "${CLAUDE_SESSION_ID}"` — which session created it

### TaskUpdate

| Field | Required | Description |
|-------|----------|-------------|
| `taskId` | yes | Task ID to update |
| `status` | no | `"pending"` → `"in_progress"` → `"completed"` or `"deleted"` |
| `addBlocks` | no | Task IDs that cannot start until this one completes |
| `addBlockedBy` | no | Task IDs that must complete before this one starts |
| `owner` | no | Assign to a specific agent |

### TaskGet

| Field | Required | Description |
|-------|----------|-------------|
| `taskId` | yes | Returns full task details including dependencies |

### TaskList

No parameters. Returns all tasks with id, subject, status, owner, blockedBy.

A task is **available** when: status = `"pending"`, no owner, blockedBy list is empty.
