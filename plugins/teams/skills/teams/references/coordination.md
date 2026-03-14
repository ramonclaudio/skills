# Coordination Rules

## File Ownership

Every file touched by the team has exactly one owner. No exceptions.

```
teammate-a owns: src/auth/**
teammate-b owns: src/api/**
shared (lead resolves): src/types.ts, schema.prisma
```

If two teammates need the same file:
1. Extract a shared interface file, owned by whoever goes first
2. Make the second teammate depend on the first
3. Or: assign both edits to one teammate

"Shared" files are edited by the lead only, or by one designated teammate, never two.

## Permissions

All teammates inherit the lead's permission settings at spawn. Pre-approve common operations before spawning to minimize prompt friction:

- File reads and writes in the project directory
- Git operations (status, diff, add, commit, push)
- Build and test commands (npm, bun, cargo, go, etc.)

### Per-teammate permission modes

Set `mode` on individual teammates (via the Agent tool's `mode` parameter) to control how they handle permission prompts:

| Mode | Behavior |
|------|----------|
| `default` | Standard permission checking with prompts |
| `acceptEdits` | Auto-accept file edits |
| `dontAsk` | Auto-deny prompts (explicitly allowed tools still work) |
| `bypassPermissions` | Skip all permission checks |
| `plan` | Read-only exploration mode |
| `auto` | Automatic permission decisions based on context |

If the lead runs with `bypassPermissions`, this takes precedence and cannot be overridden. If the lead runs with `--dangerously-skip-permissions`, all teammates inherit that setting. Be deliberate about the lead's permission mode before spawning.

## Display Mode

Split-pane mode requires either tmux or iTerm2 with the `it2` CLI:

- **tmux**: install through your system's package manager. See the tmux wiki for platform-specific instructions. `tmux -CC` in iTerm2 is the suggested entrypoint into tmux. tmux has known limitations on certain operating systems and traditionally works best on macOS.
- **iTerm2**: install the `it2` CLI, then enable the Python API in iTerm2 → Settings → General → Magic → Enable Python API.

Split-pane mode is not supported in VS Code's integrated terminal, Windows Terminal, or Ghostty.

## Teammate Isolation

Set `isolation: "worktree"` on a teammate to run it in a temporary git worktree. Each isolated teammate gets its own copy of the repository, eliminating file conflicts entirely. The worktree is cleaned up automatically if the teammate makes no changes.

Use isolation when:
- Multiple teammates need to edit files in overlapping directories
- Teammates run build/test commands that produce side effects
- You want full independence without file ownership constraints

Project configs and auto-memory are shared across git worktrees of the same repository, so isolated teammates still pick up CLAUDE.md and project settings.

`WorktreeCreate` and `WorktreeRemove` hooks fire when worktrees are created and removed, enabling custom setup/teardown (e.g., installing dependencies, seeding databases).

## Teammate Turn Limits

Set `maxTurns` on a teammate to cap the number of agentic turns before it stops. Use this to prevent runaway teammates or to enforce time-boxing on exploratory tasks.

## Teammate Memory

Set `memory` on a teammate to give it a persistent directory that survives across conversations. The teammate builds knowledge over time: codebase patterns, debugging insights, architectural decisions.

| Scope | Location | When to use |
|-------|----------|-------------|
| `user` | `~/.claude/agent-memory/<name>/` | Learnings across all projects |
| `project` | `.claude/agent-memory/<name>/` | Project-specific, shareable via VCS |
| `local` | `.claude/agent-memory-local/<name>/` | Project-specific, not checked in |

When memory is enabled, the teammate gets instructions to read/write its memory directory and the first 200 lines of `MEMORY.md` from that directory.

## Teammate MCP Servers

Set `mcpServers` on a teammate to scope specific MCP servers to it. Two forms:

- **Reference by name**: `"github"` reuses an already-configured server from the parent session
- **Inline definition**: full server config keyed by name, connected when the teammate starts and disconnected when it finishes

Inline servers stay out of the main conversation's context, reducing tool definition overhead for the lead.

## SubagentStart Hook

The `SubagentStart` hook event fires when any subagent (including teammates) begins execution. Use it with a matcher to target specific agent types:

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/setup-db.sh" }
        ]
      }
    ]
  }
}
```

Pair with `SubagentStop` for cleanup. These hooks run in the parent session's context, not inside the subagent.

## Task States

Tasks move through three states:

| State | Meaning |
|-------|---------|
| `pending` | Not started. May be blocked by dependencies. |
| `in_progress` | Claimed by a teammate, work underway. |
| `completed` | Done. Unblocks any tasks that depend on it. |

A pending task with unresolved dependencies cannot be claimed until those dependencies are completed. The system manages unblocking automatically.

## Task Claiming

Task claiming uses file locking to prevent races when multiple teammates try to claim the same task.

- **Assigned tasks**: teammates work through their assigned task IDs in order
- **Self-claim**: after finishing assigned work, a teammate picks up the next unassigned, unblocked task from the shared list
- **Idle**: if no tasks are available, the teammate messages the lead and waits

Teammates auto-notify the lead when they go idle. Messages arrive automatically, no polling needed.

## Task Sizing

| Too small | Right | Too large |
|-----------|-------|-----------|
| "Rename variable" | "Implement auth middleware with JWT validation" | "Build the entire backend" |
| "Fix typo in one file" | "Add error handling to all routes in src/api/" | "Refactor everything" |
| Single-line change | 1–5 files, clear deliverable | 20+ files, vague scope |

Target: 5–6 tasks per teammate.

## Dependency DAG

Express dependencies as a directed acyclic graph:

```
types/interfaces → implementation → tests
schema changes   → data layer     → API layer → UI layer
shared utilities → consumers
```

Rules:
- Producers before consumers
- Schemas before implementations
- Interfaces before concrete types
- Never circular

When a teammate completes a blocking task, dependent tasks unblock automatically. The teammate that owns the unblocked task can self-claim it.

## Storage

Teams and tasks are stored locally:

- **Team config:** `~/.claude/teams/{team-name}/config.json`: contains `members` array with each teammate's name, agent ID, and agent type
- **Task list:** `~/.claude/tasks/{team-name}/`

Teammates can read the team config to discover other team members.

## Communication Protocol

Use the `SendMessage` tool. Two addressing modes:
- **Direct**: `SendMessage({ to: "name", message: "text", summary: "5-10 word preview" })`, send to one specific teammate. Standard communication.
- **Broadcast**: `SendMessage({ to: "*", message: "text", summary: "5-10 word preview" })`, send to all teammates simultaneously. Token cost scales with team size. Use sparingly.

The `summary` field is **required**. It's shown as a UI preview.

Messages are delivered automatically. The lead does not need to poll.

**Idle state:** Teammates go idle after every turn. This is normal, not an error. Sending a message to an idle teammate wakes them up. When a teammate DMs another teammate, a brief summary appears in the idle notification so the lead has visibility into peer collaboration.

### Teammate → Lead

| Event | Do |
|-------|----|
| Task completed | Mark done, claim next |
| Blocked by another teammate | Message lead with what's needed |
| Found issue outside scope | Message lead with file, line, description |
| All tasks done | Message lead, wait for shutdown |

### Lead → Teammate

| Event | Do |
|-------|----|
| Teammate stuck | Provide guidance or reassign |
| Scope drift | Redirect with specific file paths |
| New task discovered | Create task, assign to appropriate teammate |
| Plan submitted | `SendMessage({ to: "name", message: { type: "plan_approval_response", request_id: "...", approve: true/false, feedback: "..." }, summary: "Approve/reject plan" })` |
| Work complete | `SendMessage({ to: "name", message: { type: "shutdown_request", reason: "..." }, summary: "Shutdown request" })` |

### Teammate → Teammate

| Event | Do |
|-------|----|
| Need their interface/type | Message them directly, cc lead |
| Found something relevant to their work | Message them with the finding |

### Broadcast

Only when:
- A shared convention changes mid-task
- A critical blocker affects all teammates
- Lead announces completion

Broadcasts cost tokens proportional to team size. Use sparingly.

## Conflict Resolution

| Conflict | Resolution |
|----------|------------|
| Two teammates claim same task | First one wins (file-lock) |
| Teammate edits unowned file | Lead intervenes, reverts if needed |
| Teammates disagree on approach | Lead decides, or escalates to user |
| Teammate stuck for extended time | Lead reassigns task to another teammate |

## Completion Protocol

1. All tasks marked completed in the shared task list
2. Lead verifies deliverables (for review teams: synthesize findings)
3. Lead sends shutdown request: `SendMessage({ to: "name", message: { type: "shutdown_request", reason: "All tasks complete" }, summary: "Shutdown request" })`. Teammates respond with `type: "shutdown_response"`, `request_id` (from the request), and `approve: true` (exit) or `approve: false` with `reason` explaining why. If rejected, wait and retry.
4. Teammates finish in-flight operations before exiting. This can be slow.
5. Wait for all teammates to stop. Cleanup fails if any teammate is still running.
6. Lead runs `TeamDelete` to clean up (only the lead should do this; teammates' team context may not resolve correctly).
7. Lead reports summary to user.

## Quality Gates

Hooks can enforce quality standards at key checkpoints:

| Hook | Trigger | Exit code 2 effect |
|------|---------|-------------------|
| `SubagentStart` | Subagent/teammate spawns | Can block spawn or run setup scripts |
| `TeammateIdle` | Teammate goes idle | Sends feedback to teammate and keeps them working |
| `TaskCompleted` | Task marked complete | Prevents completion with feedback, teammate must address issues |
| `SubagentStop` | Subagent finishes | Validates subagent output quality before results return to caller |

Exit code 0 = pass (proceed normally). Exit code 2 = reject (send stderr as feedback). Any other exit code is treated as a hook error.

`TeammateIdle` and `TaskCompleted` hooks also support JSON output with `{"continue": false, "stopReason": "..."}` to stop the teammate entirely, matching `Stop` hook behavior. Use this for hard quality gates where a teammate should not continue after a failure.

All hooks support matchers to target specific agent types by name. These hooks let the lead enforce standards without manual review of every task. Example: a `TaskCompleted` hook that runs the test suite and rejects tasks where tests fail.

## Spawn Prompt Template

Every teammate spawn prompt follows this structure:

```
You are {name}, {role description}.

## Your scope
EDIT: {paths the teammate may modify}
READ: {paths for context only}
DO NOT TOUCH: {paths that are off-limits}

## Tasks
Claim task #{N} from the shared task list.

## {Steps/What to do}
{Detailed instructions with specific commands, file lists, or checklists}

## Communication
Send findings to lead via SendMessage when done.
Mark task #{N} as completed.
```

Rules:

- **EDIT/READ/DO NOT TOUCH is mandatory** for every teammate spawn prompt. No exceptions.
- **EDIT paths** grant exclusive file ownership. No two teammates share EDIT paths.
- **READ paths** provide context without edit permission. Teammates can read these but must not modify them.
- **DO NOT TOUCH** prevents accidental changes to shared files or other teammates' files. Default to "Everything else" when scope is narrow.
- **Tasks section** always references the shared task list with a specific task number.
- **Communication section** always includes `SendMessage` to lead and `TaskUpdate` to mark complete.
- For **read-only teammates** (researchers, auditors, reviewers), set `EDIT: NONE`.
- For **fixer teammates**, list every file they may edit explicitly. No wildcards unless the teammate owns an entire directory.

## Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Teammate not appearing | Task too simple for a team, or tmux not installed | Check task complexity; verify `which tmux` |
| Too many permission prompts | Pre-approve common operations in permission settings | Configure before spawning |
| Teammate stops on error | Unhandled error in their scope | Message them with instructions, or spawn replacement |
| Lead implements instead of delegating | Default behavior | Use `--delegate` flag, or tell lead to wait |
| Task appears stuck | Teammate forgot to mark it done | Check if work is actually done; update manually |
| Orphaned tmux sessions | Cleanup didn't finish | `tmux ls` then `tmux kill-session -t <name>` |
