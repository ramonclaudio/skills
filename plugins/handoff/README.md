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

## Requirements

- `git`
- Optional: `gh` (GitHub CLI)

## Version

1.0.0
