# Handoff

Session quality gate for Claude Code. Runs health checks at session end, captures structured resume points, and syncs state across machines.

## Why This Exists

Built-in features handle most session continuity. Auto memory persists preferences and corrections. `--resume` reopens sessions. `CLAUDE.md` stores project context. This plugin adds the three things they don't: health checks (build/test/lint status), structured resume points (exact `file:line` + context), and cross-machine state (`.handoff/state.json`).

## Usage

```bash
/handoff:end     # Run at end of session. Health checks + resume capture.
/handoff:start   # Optional. Deep hydration: tasks, git activity, drift check.
```

`/handoff:end` is the primary skill. Run it when you're done working. It checks build/test/lint, captures what you did, and writes a resume point with specific next steps.

`/handoff:start` is optional. Hooks already inject the resume summary on startup. Use start when you want full hydration: task creation from blockers, git log review, file drift detection.

## What It Does

- Runs build, test, and lint. Records pass/fail for each.
- Sets severity: CRITICAL (build broken), IN_PROGRESS (tests failing, uncommitted work), READY (all green).
- Captures resume point with exact `file:line` action, files to read, and context.
- Records blockers, watch-outs, and completed work with commit refs.
- Writes `.handoff/state.json` for cross-machine pickup.

## Hooks

Two hooks run automatically:

- `SessionStart` (startup + resume): injects severity, resume point, blockers, and `--resume` hint from `state.json`.
- `PostCompact` (v2.1.76): re-injects the same context after compaction so nothing is lost.

Both run `resume-inject.sh`. Takes <1s. Skipped when `HANDOFF_DISABLED=1`.

## State File

`.handoff/state.json` schema:

```json
{
  "severity": "READY|IN_PROGRESS|CRITICAL",
  "health": { "build": "pass|fail|null", "tests": "pass|fail|null", "lint": "pass|fail|null" },
  "resume": { "next": "file:line action", "files": ["path"], "context": "string" },
  "done": [{ "description": "string", "ref": "commit-hash" }],
  "blockers": ["string"],
  "watch_out_for": ["string"],
  "hostname": "string",
  "session_id": "string",
  "timestamp": "ISO"
}
```

## Severity

| Level | Condition |
|:---|:---|
| CRITICAL | Build failing, prod down, security issue |
| IN_PROGRESS | Tests failing, uncommitted work, mid-feature |
| READY | All green, clean state |

## Install

Install at User scope. Project scope causes multi-user collision on `state.json`.

## Requirements

- `git`, `jq`
- Optional: `gh` (GitHub CLI, used by `/handoff:start` for PR list)

## Disable

Skip all hooks in headless or CI environments:

```bash
HANDOFF_DISABLED=1 claude -p "explain this function"
```
