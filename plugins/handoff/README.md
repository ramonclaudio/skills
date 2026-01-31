# Handoff Plugin

Session continuity for Claude Code.

Every Claude session starts fresh. You remember what you were working on yesterday - what got done, what broke, where you left off. Claude doesn't. This plugin fixes that.

Think hospital shift change. Doctors don't try to remember everything about every patient. They do structured handoffs: current status, what happened, what to watch for, what's next. Same idea here.

## Usage

```bash
/handoff:run init    # First time: create .handoff/ structure
/handoff:run start   # Beginning of session: gather context
/handoff:run end     # End of session: archive state
```

## How It Works

### INIT

Creates `.handoff/` structure with `CONTEXT.md` (project info) and `HANDOFF.md` (session state). Scans project to auto-populate stack, structure, and invocation commands.

### START

1. Find last session archive
2. Read `CONTEXT.md` and `HANDOFF.md`
3. Get commits/PRs/issues since last session
4. Check for drift (state changed since handoff?)
5. Output structured summary

### END

1. Archive current `HANDOFF.md` to `sessions/`
2. Run health checks (build/test/lint)
3. Capture git state
4. Document: done, failed (with why), blockers, watch-outs
5. Set severity and resume point
6. Validate handoff quality
7. Create resume Task (persists to `~/.claude/tasks`)

## Structure

```text
.handoff/
├── CONTEXT.md       # Project: stack, commands, critical paths, gotchas
├── HANDOFF.md       # Session: severity, health, done, failed, blockers, resume
└── sessions/        # Archived handoffs by session ID
```

## Severity

| Level | Meaning |
|-------|---------|
| CRITICAL | Production down, security issue |
| IN PROGRESS | Mid-feature, tests failing |
| READY | All green, clean state |

## Hooks (Automatic)

The plugin ships with lifecycle hooks that run without manual invocation:

| Hook | Event | What it does |
|------|-------|-------------|
| `session-start.sh` | SessionStart (startup) | Auto-injects severity, resume point, and blockers from `.handoff/HANDOFF.md` into fresh sessions |
| `compact-reinject.sh` | SessionStart (compact) | Re-injects handoff context after compaction so resume state survives |
| `pre-compact.sh` | PreCompact | Snapshots git state to `.handoff/.pre-compact` before compaction destroys conversation detail |

This means every fresh session automatically sees the handoff resume point — even without running `/handoff:run start`. The full START is still available for deep hydration (tasks, git activity, drift check).

## CLAUDE.md Integration

On INIT and END, the plugin syncs the resume point to CLAUDE.md's Compact Instructions section. This ensures:
- Fresh sessions see the resume point before any skill runs
- Compacted sessions retain it through auto-compaction
- Full state lives in `.handoff/` — CLAUDE.md just has the pointer

## Task Integration

END creates Tasks with metadata (`handoff: true`, `resume: true`, `blocker: true`) visible via `Ctrl+T`. START hydrates blockers and resume points from HANDOFF.md into Tasks with `addBlockedBy` dependencies. For cross-session task sharing:

```bash
CLAUDE_CODE_TASK_LIST_ID=my-project claude
```

## Requirements

- `git`
- Optional: `gh` (GitHub CLI)

## Version

1.0.0
