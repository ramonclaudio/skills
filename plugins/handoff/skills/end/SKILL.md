---
name: end
description: "End session, save progress, create handoff. Triggers: wrap up, done for today, end session, save my work, save progress, close out. Runs health checks and captures resume point."
allowed-tools:
  - Bash(git *)
  - Bash(npm *)
  - Bash(bun *)
  - Bash(pnpm *)
  - Bash(yarn *)
  - Bash(cargo *)
  - Bash(go *)
  - Bash(mkdir *)
  - Bash(jq *)
  - Bash(test *)
  - Bash(date *)
  - Bash(hostname *)
  - Bash(trash *)
  - Read
  - Write
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskGet
  - TaskList
model: opus
disable-model-invocation: true
---

# Handoff End

ultrathink

<role>
Senior engineer closing a shift. Precise state capture: exact errors, specific file:line references, honest severity. Never vague, never ask the user.
</role>

## Pre-loaded State

### state.json
!`cat .handoff/state.json 2>/dev/null || echo "{}"`

### Git
!`git status -s 2>/dev/null`
!`git log -5 --format='%h %s' 2>/dev/null`

## Steps

1. **Bootstrap**: Create `.handoff/` if missing. Write `.handoff/.gitignore` with `state.json` and `sessions/` if missing.
2. **Health checks**: Detect package manager from lockfile (`bun.lock` -> bun, `package-lock.json` -> npm, `pnpm-lock.yaml` -> pnpm, `yarn.lock` -> yarn, `Cargo.lock` -> cargo, `go.sum` -> go). Run build, test, lint. Record pass/fail/null for each.
3. **Analyze session** from conversation + git log. DO NOT ask the user:
   - Severity: CRITICAL (build failing), IN_PROGRESS (tests failing, uncommitted work, mid-feature), READY (all green)
   - Done: commits and features completed `[{"description": "string", "ref": "hash"}]`
   - Blockers: external deps, missing credentials, pending decisions
   - Watch out for: gotchas, workarounds, edge cases
   - Resume: specific `file:line action`, files to read first, context
4. **Write state.json** via atomic write (`.tmp.$$` then `mv`):
   ```json
   {
     "severity": "READY|IN_PROGRESS|CRITICAL",
     "health": {"build": "pass|fail|null", "tests": "pass|fail|null", "lint": "pass|fail|null"},
     "resume": {"next": "file:line action", "files": ["string"], "context": "string"},
     "done": [{"description": "string", "ref": "string"}],
     "blockers": ["string"],
     "watch_out_for": ["string"],
     "hostname": "string",
     "session_id": "string",
     "timestamp": "ISO"
   }
   ```
5. **Create tasks**: Blocker tasks (metadata: `blocker: true, handoff: true`) + resume task blocked by blockers (metadata: `resume: true, handoff: true`).
6. **Output**:
   ```
   HANDOFF COMPLETE
   Severity: [emoji SEVERITY]
   Health: build=[status] tests=[status] lint=[status]
   Resume: [next action]
   Safe to end session.
   ```

## Severity

| Level | Condition |
|-------|-----------|
| CRITICAL | Build failing, prod down, security issue |
| IN_PROGRESS | Tests failing, uncommitted work, mid-feature |
| READY | All green, clean state |

## Anti-Patterns

DON'T: Skip health checks. Write vague resume ("keep working on X"). Leave READY with failing tests.
DO: Exact error messages. Specific file:line in resume. Honest severity.
