# Handoff Plugin

Session continuity for Claude Code.

Every Claude session starts fresh. You remember what you were working on yesterday - what got done, what broke, where you left off. Claude doesn't. This plugin fixes that.

Think hospital shift change. Doctors don't try to remember everything about every patient. They do structured handoffs: current status, what happened, what to watch for, what's next. Same idea here.

[Usage](#usage) / [How It Works](#how-it-works) / [Structure](#structure) / [Hooks](#hooks-automatic)

## Usage

```bash
/handoff:end     # End of session: archive state
/handoff:start   # Optional: deep context hydration (tasks, git, drift)
```

Hooks handle everything else automatically: auto-init on first run, context injection on startup, auto-save before compaction.

## How It Works

### Skills

| Skill | Model | Side effects | Model-invocable |
|:---|:---|:---|:---|
| `/handoff:start` | opus | Light (reads + tasks) | Yes (auto for CRITICAL) |
| `/handoff:end` | opus | Heavy (health, writes) | No (user-only) |

### START

1. Read `CONTEXT.md` and `state.json`
2. Get commits/PRs/issues since last session
3. Check for drift (state changed since handoff?)
4. Hydrate tasks from blockers/resume
5. Output structured summary

### END

1. Archive current `state.json` to `sessions/`
2. Run health checks (build/test/lint)
3. Capture git state
4. Document: done, failed (with why), blockers, watch-outs
5. Set severity (reflects current state) and resume point
6. Persist corrections to `CONTEXT.md`
7. Validate handoff quality
8. Create resume Task (persists to `~/.claude/tasks`)

## Structure

```text
.handoff/
├── CONTEXT.md       # Project: stack, commands, critical paths, gotchas, corrections
├── state.json       # Single source of truth (structured state + runtime counters)
├── events.jsonl     # Append-only raw event log (bash cmd/exit, file writes/edits)
└── sessions/        # Archived state + event logs by session ID
```

## Severity

| Level | Meaning |
|:---|:---|
| CRITICAL | Production down, security issue |
| IN PROGRESS | Mid-feature, tests failing |
| READY | All green, clean state |

<details open>
<summary>Hooks (Automatic)</summary>

The plugin ships with lifecycle hooks that run without manual invocation:

| Hook | Event | What it does |
|:---|:---|:---|
| `session-start.sh` | SessionStart (startup/resume) | Auto-inits projects, injects severity, resume point, and blockers |
| `compact-reinject.sh` | SessionStart (compact) | Re-injects handoff context after compaction with escalating suggestions |
| `session-clear.sh` | SessionStart (clear) | Resets runtime counters, archives events, preserves corrections |
| `pre-compact.sh` | PreCompact | Triggers auto-save before compaction |
| `event-capture.sh` | PostToolUse | Appends raw tool events (cmd/exit/file) to `events.jsonl` |
| `session-start.sh` | SubagentStart | Injects handoff context (severity, resume, blockers) into subagents |
| `prompt-reminder.sh` | UserPromptSubmit | Escalating context degradation suggestions |
| `pre-compact.sh` | SessionEnd (logout/exit) | Auto-saves session state before exit |

> [!TIP]
> Every fresh session automatically sees the handoff resume point, even without running `/handoff:start`. The full START is still available for deep hydration (tasks, git activity, drift check).

</details>

<details>
<summary>Task Integration</summary>

END creates Tasks with metadata (`handoff: true`, `resume: true`, `blocker: true`) visible via `Ctrl+T`. START hydrates blockers and resume points from `state.json` into Tasks with `addBlockedBy` dependencies. For cross-session task sharing:

```bash
CLAUDE_CODE_TASK_LIST_ID=my-project claude
```

</details>

---

> [!IMPORTANT]
> **Install at User scope.** The plugin writes per-session state to `.handoff/state.json`. Project scope causes multi-user collision, last writer wins. `.handoff/CONTEXT.md` can be committed for team context sharing; transient state is auto-gitignored.
>
> Requires `git` and `jq`. Optional: `gh` (GitHub CLI).

## Handoff vs Auto-Memory

| | Auto-Memory (built-in) | Handoff |
|:---|:---|:---|
| Scope | Cross-session, durable | Session-scoped working state |
| Storage | `~/.claude/projects/` (per-user) | `.handoff/` (per-project) |
| Content | User preferences, feedback, project context | What happened, what broke, what's next |
| Sharing | Private to the user | `CONTEXT.md` committable for team sharing via git |

They complement each other. Auto-memory tracks persistent preferences and corrections. Handoff captures session continuity: current status, blockers, resume points.

## Troubleshooting

If session-end auto-save is truncated, increase `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (milliseconds) in your environment or `settings.json` env block.

---

**Headless / CI**: Set `HANDOFF_DISABLED=1` to skip all hooks:

```bash
HANDOFF_DISABLED=1 claude -p "explain this function"
```
