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

"Shared" files are edited by the lead only, or by one designated teammate — never two.

## Permissions

All teammates inherit the lead's permission settings at spawn. Pre-approve common operations before spawning to minimize prompt friction:

- File reads and writes in the project directory
- Git operations (status, diff, add, commit, push)
- Build and test commands (npm, bun, cargo, go, etc.)

Per-teammate permissions can only be changed after spawning, not at spawn time.

**Warning:** If the lead runs with `--dangerously-skip-permissions`, all teammates inherit that setting. Be deliberate about the lead's permission mode before spawning.

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

Teammates auto-notify the lead when they go idle. Messages arrive automatically — no polling needed.

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

- **Team config:** `~/.claude/teams/{team-name}/config.json` — contains `members` array with each teammate's name, agent ID, and agent type
- **Task list:** `~/.claude/tasks/{team-name}/`

Teammates can read the team config to discover other team members.

## Communication Protocol

Two messaging primitives:
- **`message`** — send to one specific teammate. Standard communication.
- **`broadcast`** — send to all teammates simultaneously. Token cost scales with team size. Use sparingly.

Messages are delivered automatically. The lead does not need to poll.

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
| Work complete | Send shutdown request |

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
3. Lead sends shutdown request to each teammate. Teammates can **approve** (exit) or **reject** with an explanation. If rejected, wait and retry.
4. Teammates finish in-flight operations before exiting — this can be slow.
5. Wait for all teammates to stop. Cleanup fails if any teammate is still running.
5. Lead runs team cleanup (only the lead should do this — teammates' team context may not resolve correctly)
6. Lead reports summary to user

## Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Teammate not appearing | Task too simple for a team, or tmux not installed | Check task complexity; verify `which tmux` |
| Too many permission prompts | Pre-approve common operations in permission settings | Configure before spawning |
| Teammate stops on error | Unhandled error in their scope | Message them with instructions, or spawn replacement |
| Lead implements instead of delegating | Default behavior | Use `--delegate` flag, or tell lead to wait |
| Task appears stuck | Teammate forgot to mark it done | Check if work is actually done; update manually |
| Orphaned tmux sessions | Cleanup didn't finish | `tmux ls` then `tmux kill-session -t <name>` |
