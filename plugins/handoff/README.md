# Handoff

Session continuity for Claude Code.

Every Claude session starts fresh. You remember what you were working on yesterday - what got done, what broke, where you left off. Claude doesn't. This plugin fixes that.

Think hospital shift change. Doctors don't try to remember everything about every patient. They do structured handoffs: current status, what happened, what to watch for, what's next. Same idea here.

Nothing fancy. Hope it's useful.

## Installation

Add the marketplace, then install:
```shell
/plugin marketplace add ramonclaudio/skills
/plugin install handoff@skills
```

## Usage

```shell
/handoff:handoff init    # First time: create .handoff/ structure
/handoff:handoff start   # Beginning of session: gather context
/handoff:handoff end     # End of session: archive state
```

## Structure

```text
.handoff/
├── CONTEXT.md       # Project: stack, commands, critical paths, gotchas
├── HANDOFF.md       # Session: severity, health, done, failed, blockers, resume
└── sessions/        # Archived handoffs by session ID
```

## How It Works

### START

1. Find last session archive
2. Read `CONTEXT.md` and `HANDOFF.md`
3. Get commits/PRs/issues since last session
4. Check for drift (state changed since handoff?)
5. Output structured summary

### END

1. Archive current `HANDOFF.md`
2. Run health checks (build/test/lint)
3. Capture git state
4. Document: done, failed (with why), blockers, watch-outs
5. Set severity and resume point
6. Validate handoff quality
7. Create resume Task (persists to `~/.claude/tasks`)

## Severity

| Level | Meaning |
|-------|---------|
| 🔴 CRITICAL | Production down, security issue |
| 🟡 IN PROGRESS | Mid-feature, tests failing |
| 🟢 READY | All green, clean state |

## Requirements

- Claude Code 2.1.16+ (uses Task system and `${CLAUDE_SESSION_ID}`)
- Git
- Optional: `gh` (GitHub CLI), Linear MCP

## License

[MIT](LICENSE)
