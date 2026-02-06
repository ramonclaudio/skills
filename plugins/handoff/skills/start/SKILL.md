---
name: start
description: Deep session context hydration with task creation. Use when severity is CRITICAL, when there are unresolved blockers, or when the user asks about session state, handoff status, or what to work on next.
user-invocable: false
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(date *)
  - Bash(ls *)
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskGet
  - TaskList
model: sonnet[1m]
---

# Handoff Start

<role>
Senior engineer. Hospital shift changes. Read the chart, brief the incoming team. Precise, no fluff.
</role>

<task>
Analyze the pre-loaded state below, check for drift, hydrate tasks, and report. Hooks auto-inject a lightweight summary on session start — this provides the thorough version with task hydration and drift detection.
</task>

## Pre-loaded State

### state.json
!`cat .handoff/state.json 2>/dev/null || echo "No state found — run /handoff:end first"`

### CONTEXT.md
!`cat .handoff/CONTEXT.md 2>/dev/null || echo "No context found"`

### Git
Branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
!`git status -s 2>/dev/null`

Recent commits:
!`git log -10 --format='%h %s' 2>/dev/null || echo "No commits"`

### PRs
!`gh pr list --limit 5 2>/dev/null || echo "gh not available or no PRs"`

## Steps

1. **Check --resume availability**: Read `_runtime.hostname` from state.json. If it matches current hostname (`hostname -s`) and `session_id` differs from current session, the previous session may be resumable at protocol level. Note this in output: `Previous session resumable: claude --resume <session_id>`. This gives full context replay vs. lossy handoff rehydration.
2. **Analyze pre-loaded state** above. Check `source` field for confidence ("manual-end" > "auto-save" > "init")
3. **Check drift**: verify Structure paths from CONTEXT.md still exist (Glob), report missing/new files
4. **Check active tasks**: `TaskList`, `TaskGet` for each — identify handoff/blocker/resume metadata

**Hydrate tasks from state.json (idempotent):**
1. Check existing tasks first — if tasks with metadata `handoff: true` and matching `session` already exist for the current session, skip creation (prevents duplicates on repeated invocation)
2. Complete previous handoff tasks from prior sessions (`TaskUpdate status: "completed"`)
3. Create blocker tasks from blockers array (metadata: `blocker: true, handoff: true, session: "${CLAUDE_SESSION_ID}"`)
4. Create resume task from resume object (metadata: `resume: true, handoff: true, session: "${CLAUDE_SESSION_ID}"`)
5. Set dependencies: resume blocked by blockers

**Output read-back:**
```
╔═══════════════════════════════════════════╗
║  HANDOFF RECEIVED                         ║
║  Project: [name] | Stack: [stack]         ║
║  Severity: [emoji]                        ║
╚═══════════════════════════════════════════╝

💡 RESUMABLE: claude --resume <session_id>
   (only if hostname matches — full context replay vs lossy rehydration)

SINCE LAST SESSION
├─ Commits: [N] | PRs: [N] merged
└─ Tasks: [N] hydrated

⚠️  WATCH OUT FOR / 🚫 BLOCKERS / ❌ FAILED
[lists]

▶️  RESUME
[Next action, files, context]
────────────────────────────────────
Ready. What would you like to work on?
```
