---
name: handoff
description: Session continuity for Claude Code. Gather context at start, archive state at end. Use when user mentions handoff, saving progress, or resuming work.
argument-hint: start|end|init
allowed-tools:
  # Git & GitHub
  - Bash(git:*)
  - Bash(gh:*)
  # Package managers
  - Bash(npm:*)
  - Bash(bun:*)
  - Bash(pnpm:*)
  - Bash(yarn:*)
  # File operations (bash-only)
  - Bash(mkdir:*)
  - Bash(cp:*)
  - Bash(rm:*)
  - Bash(date:*)
  - Bash(ls:*)
  - Bash(test:*)
  - Bash(wc:*)
  # Dedicated tools (preferred over bash)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  # Task management (cross-session persistence)
  - TaskCreate
  - TaskUpdate
  - TaskGet
  - TaskList
  # External integrations
  - mcp__plugin_linear_linear__list_issues
---

# Handoff

Session continuity for Claude Code. Like hospital shift changes, bad handoffs lose context.

## Argument: $ARGUMENTS

---

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

---

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
**Next:** Run `/handoff start` to begin
**Files:** -
**Context:** Fresh initialization
```

Done. Run `/handoff start` to begin first session.

---

## START

If `$ARGUMENTS` is empty or = "start":

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

**3f. Linear Issues (if configured)**
```
mcp__plugin_linear_linear__list_issues
```
Filter to issues updated since last session.

**3g. Subagent Activity (if present)**
```bash
cat .handoff/.subagents.log 2>/dev/null | tail -20
```
Shows which subagents ran during previous session (logged by SubagentStart/SubagentStop hooks).

### Phase 4: Assess Current Health

Check if state has drifted since handoff:
- Did git status change? (new commits from elsewhere?)
- Are there uncommitted changes not in handoff?

### Phase 5: Complete Previous Handoff Tasks

Check for pending handoff tasks from previous session and mark them complete:

```
TaskList  # Check for existing handoff tasks
```

For any tasks with `handoff: true` metadata that are still pending, mark them complete:

```
TaskUpdate(taskId: "[id]", status: "completed")  # Previous resume point - session started
```

### Phase 6: Output Read-Back

```
╔══════════════════════════════════════════════════════════════╗
║  HANDOFF RECEIVED                                            ║
╠══════════════════════════════════════════════════════════════╣
║  Project: [name]                                             ║
║  Stack: [from CONTEXT.md]                                    ║
║  Severity: [🔴 CRITICAL | 🟡 IN PROGRESS | 🟢 READY]         ║
╚══════════════════════════════════════════════════════════════╝

[If drift detected:]
⚠️  CONTEXT DRIFT
[list of missing/new files]

SINCE LAST SESSION ([date], [N] days ago)
├─ Commits: [N]
├─ PRs: [N] merged, [N] opened, [N] open
└─ Issues: [N] updated

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

---

## END

If `$ARGUMENTS` = "end":

### Phase 1: Archive Current State

```bash
cp .handoff/HANDOFF.md ".handoff/sessions/${CLAUDE_SESSION_ID}.md"
```

Clear subagent activity log (will be regenerated during next session):
```bash
rm -f .handoff/.subagents.log 2>/dev/null
```

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

### Phase 6: Write HANDOFF.md

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

### Phase 8: Create Resume Task

Use TaskCreate to persist the resume point for the next session:

```
TaskCreate(
  subject: "[Resume point from HANDOFF.md]",
  description: "[Context and files to read]",
  activeForm: "Resuming: [brief description]",
  metadata: { "handoff": true, "session": "${CLAUDE_SESSION_ID}" }
)
```

This creates a persistent task visible in Claude Code's task list (`~/.claude/tasks`). The `handoff: true` metadata identifies it as a handoff resume point for the next session to mark complete.

### Phase 9: Confirm

```
╔══════════════════════════════════════════════════════════════╗
║  HANDOFF COMPLETE                                            ║
╠══════════════════════════════════════════════════════════════╣
║  Archived: sessions/${CLAUDE_SESSION_ID}.md                  ║
║  Severity: [emoji + label]                                   ║
╚══════════════════════════════════════════════════════════════╝

HEALTH
├─ Build: [status]
├─ Tests: [status]
└─ Lint: [status]

SESSION SUMMARY
├─ Done: [N] items
├─ Failed: [N] items (documented)
├─ Blockers: [N] active
└─ Watch-outs: [N] added

CONTEXT UPDATED
├─ Structure: [regenerated | unchanged]
├─ Invocation: [regenerated | unchanged]
└─ Curated sections: preserved

RESUME POINT
[Next action]

────────────────────────────────────────────────────────────────
Safe to end session.
```

---

## Severity Guide

| Level | When | Meaning |
|-------|------|---------|
| 🔴 CRITICAL | Production down, data loss risk, security issue | Drop everything, fix now |
| 🟡 IN PROGRESS | Mid-feature, tests failing, WIP | Continue current work |
| 🟢 READY | All green, clean state | Pick up new work |

---

## Health Check Commands

Detect from CONTEXT.md or infer from lockfile:

| Lockfile | Build | Test | Lint |
|----------|-------|------|------|
| bun.lockb | `bun run build` | `bun test` | `bun run lint` |
| package-lock.json | `npm run build` | `npm test` | `npm run lint` |
| pnpm-lock.yaml | `pnpm build` | `pnpm test` | `pnpm lint` |
| yarn.lock | `yarn build` | `yarn test` | `yarn lint` |

---

## Anti-Patterns

**DON'T:**
- Skip health checks on END (you're leaving blind)
- Write vague resume points ("keep working on auth")
- Omit failure root cause (next session repeats mistake)
- Ignore blockers (they don't disappear)
- Leave severity at 🟢 when tests are failing
- Let CONTEXT.md go stale (structure drift = confusion)

**DO:**
- Capture exact error messages in failures
- Reference specific file:line in resume
- Document gotchas immediately when discovered
- Be honest about severity
- Validate handoff before ending
- Update CONTEXT.md structure on END
