---
name: end
description: Archive session state to .handoff/. Runs health checks, captures severity, resume point, and done/failed/blockers.
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
  - Bash(mv *)
  - Bash(date *)
  - Bash(ls *)
  - Bash(test *)
  - Bash(wc *)
  - Bash(touch *)
  - Bash(trash *)
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

# Handoff End

ultrathink

<role>
Senior engineer. Hospital shift changes. Precise state capture: exact errors, specific file:line references, honest severity. Never vague.
</role>

<task>
Archive session state. Hooks auto-save a lightweight snapshot on compaction — this provides the thorough version with health checks, corrections persistence, and validation.
</task>

## Pre-loaded State

### state.json
!`cat .handoff/state.json 2>/dev/null || echo "{}"`

### CONTEXT.md
!`cat .handoff/CONTEXT.md 2>/dev/null || echo "No context"`

### Recent Events
!`tail -30 .handoff/events.jsonl 2>/dev/null || echo "No events"`

### Git
Branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
!`git status -s 2>/dev/null`
!`git log -5 --format='%h %s' 2>/dev/null`

## Steps

1. **Archive**: `cp .handoff/state.json ".handoff/sessions/${CLAUDE_SESSION_ID}.json"`
2. **Signal completion**: Write `_runtime.handoff_end_completed = true` to state.json IMMEDIATELY (stops hook nagging before health checks run)
3. **Health checks** using commands from pre-loaded CONTEXT.md or detected lockfile:
   - Build: `[pkg] run build 2>&1 | tail -5; echo "EXIT:$?"`
   - Tests: `[pkg] test 2>&1 | tail -10; echo "EXIT:$?"`
   - Lint: `[pkg] run lint 2>&1 | tail -5; echo "EXIT:$?"`
4. **Update CONTEXT.md**: Regenerate AUTO sections (Structure from Glob, Invocation from lockfile). Preserve CURATED sections exactly. Append new corrections from `session_memory.corrections` to `## Corrections` section (deduplicate against existing entries).
5. **Analyze session** — infer from conversation + pre-loaded git/events, DO NOT ask user:
   - **Severity**: 🔴 build failing → CRITICAL; 🟡 tests failing/dirty/mid-feature → IN PROGRESS; 🟢 all green → READY. Ground truth — health checks ran, not inferred from stale events.
   - **Done**: commits, PRs, features completed — `[{"description": "...", "ref": "abc1234"}]`
   - **Failed**: with Tried/Error/Why/Need for each — `[{"description":"...", "tried":"...", "error":"...", "why":"...", "need":"..."}]`
   - **Blockers**: external deps, missing credentials, pending decisions
   - **Watch Out For**: gotchas, workarounds, edge cases discovered
   - **Resume**: specific file:line next action, files to read first, reasoning
6. **Write session memory** to state.json `.session_memory`:
   - `user_intent` — one paragraph
   - `corrections` — APPEND to existing array, never replace (persisted to CONTEXT.md in step 4)
   - `active_context` — file:line, function names, current step
   - `key_references` — file paths, error messages, PR numbers
   - `last_updated` — ISO timestamp
   - `last_event_index` — current events.jsonl line count
7. **Write state.json**: Set `source` to `"manual-end"`, set `_runtime.hostname` to current hostname. Update all fields. Write to `.tmp.$$` first, then validate and move (atomic write).
8. **Validate against schema** — the state.json MUST conform to this contract:
   ```json
   {
     "_version": 1,
     "source": "manual-end",
     "session_id": "string",
     "severity": "READY | IN_PROGRESS | CRITICAL",
     "_runtime": {
       "compaction_count": "number",
       "last_compaction": "string | null",
       "handoff_end_completed": true,
       "session_start_ts": "ISO timestamp",
       "session_start_hash": "git hash",
       "hostname": "string",
       "context_pct": "number"
     },
     "health": {
       "build": "pass | fail | null",
       "tests": "pass | fail | null",
       "lint": "pass | fail | null"
     },
     "done": [{"description": "string", "ref": "string"}],
     "failed": [{"description": "string", "tried": "string", "error": "string", "why": "string | null", "need": "string | null"}],
     "blockers": [{"description": "string", "resolved": false}],
     "resume": {
       "next": "file:line action",
       "files": ["string"],
       "context": "string"
     },
     "watch_out_for": ["string"],
     "session_memory": {
       "user_intent": "string",
       "corrections": ["string"],
       "active_context": "string",
       "key_references": ["string"],
       "last_updated": "ISO timestamp",
       "last_event_index": "number"
     }
   }
   ```
   REQUIRED: severity set, health captured, resume has file:line, resume has files array, failures have root cause. WARNINGS: vague resume, no watch-outs.
9. **Create tasks**: Blocker tasks (metadata: `blocker: true, handoff: true, session: "${CLAUDE_SESSION_ID}"`), resume task blocked by blockers (metadata: `resume: true, handoff: true`)
10. **Confirm**:
```
HANDOFF COMPLETE
Severity: [emoji] | Source: manual-end

SESSION: [N] done, [N] failed, [N] blockers
HEALTH: build=[status] tests=[status] lint=[status]
RESUME: [next action]

Safe to end session.
```

## Severity

| 🔴 CRITICAL | Build failing, prod down, security issue |
| 🟡 IN PROGRESS | Tests failing, uncommitted work, mid-feature |
| 🟢 READY | All green, clean state |

## Anti-Patterns

**DON'T**: Skip health checks. Write vague resume ("keep working on X"). Omit failure root cause. Leave 🟢 with failing tests. Wait until context is full to run END.

**DO**: Exact error messages in failures. Specific file:line in resume. Document gotchas immediately. Honest severity.
