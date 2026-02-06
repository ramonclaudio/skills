# Teams Plugin

Orchestrate teams of Claude Code sessions working in parallel. One lead decomposes work, spawns teammates, assigns tasks with file ownership, and steers execution. Teammates work independently, each in its own context window, and communicate through a shared task list and direct messaging.

Unlike subagents, which run within a single session and can only report back to the main agent, you can also interact with individual teammates directly without going through the lead.

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled in settings.

## Usage

This skill provides flags for controlling team behavior. These flags are skill-specific — they are not built-in Claude Code CLI flags.

```bash
/teams:teams Refactor the auth module into separate concerns    # Spawn and execute
/teams:teams --dry-run Build a notification system                # Plan only
/teams:teams --plan-approval Migrate the database schema          # Teammates plan before implementing
/teams:teams --delegate Review PR #42 from three angles           # Lead never implements
/teams:teams --roles 3 Add caching to all API endpoints           # Force 3 teammates
```

## When to use

Agent teams are most effective for tasks where parallel exploration adds real value:

- **Research and review** — multiple teammates investigate different aspects simultaneously, then share and challenge each other's findings
- **New modules or features** — teammates each own a separate piece without stepping on each other
- **Debugging with competing hypotheses** — teammates test different theories in parallel and converge on the answer faster
- **Cross-layer coordination** — changes that span frontend, backend, and tests, each owned by a different teammate

If you're new to agent teams, start with tasks that have clear boundaries and don't require writing code: reviewing a PR, researching a library, or investigating a bug.

## When NOT to use

Don't create a team for:
- **Trivial work** — fewer than 3 files, obvious change
- **Sequential tasks** — steps must happen in order, no parallelism
- **Same-file edits** — two teammates editing one file causes overwrites
- **High dependency** — most tasks block on each other

For these cases, a single session or subagents are more effective.

## Architecture

An agent team consists of:

| Component | Role |
|:----------|:-----|
| **Team lead** | The main Claude Code session that creates the team, spawns teammates, and coordinates work |
| **Teammates** | Separate Claude Code instances that each work on assigned tasks |
| **Task list** | Shared list of work items that teammates claim and complete |
| **Mailbox** | Messaging system for communication between agents |

## How It Works

### Phase 1 — Reconnaissance

Reads `CLAUDE.md`, maps the codebase structure, identifies which files and modules the task touches, detects constraints (shared state, sequential dependencies).

### Phase 2 — Decomposition

Breaks work into independent units. Each unit touches a disjoint set of files, has a clear deliverable, and can be completed in isolation.

### Phase 3 — Team Design

Selects team composition from reference patterns:

| Pattern | When |
|:--------|:-----|
| Parallel Builders | New feature spanning multiple modules |
| Review Panel | Code review, security audit, PR review |
| Research Team | Evaluating options, exploring architecture |
| Adversarial Debug | Unknown root cause, competing hypotheses |
| Cross-Layer | Changes spanning frontend, backend, database |

### Phase 4 — Task Graph

Creates dependency-ordered tasks. Producers before consumers. Schemas before implementations. Interfaces before concrete types.

### Phase 5 — Spawn & Brief

Each teammate gets a spawn prompt with: role, owned files, context files, exclusions, task IDs, and communication rules. Teammates auto-load CLAUDE.md and MCP servers independently — the spawn prompt focuses on task-specific context.

### Phase 6 — Coordinate

Lead tracks progress, unblocks stuck teammates, redirects scope drift, and synthesizes results. Never implements.

### Flags

| Flag | Effect |
|:-----|:-------|
| `--dry-run` | Design team and task graph without spawning |
| `--plan-approval` | Require teammates to plan before implementing. Use for schema changes, API modifications, and critical code paths. Lead approves or rejects each plan with feedback. |
| `--delegate` | Restrict lead to coordination-only tools — no code editing |
| `--roles N` | Force specific teammate count (max 5) |

> [!TIP]
> Use `--dry-run` to preview the team plan and task graph before spawning.

> [!TIP]
> Use `--delegate` to prevent the lead from implementing tasks itself.

## Token cost

Agent teams use significantly more tokens than a single session. Each teammate has its own context window, and token usage scales with the number of active teammates. For research, review, and new feature work, the extra tokens are usually worthwhile. For routine tasks, a single session is more cost-effective.

## Limitations

Agent teams are experimental:

- `/resume` and `/rewind` do not restore teammates — spawn new ones after resuming
- Task status can lag — teammates sometimes forget to mark tasks completed
- Shutdown can be slow — teammates finish their current request or tool call before stopping
- One team per session — clean up before starting a new one
- No nested teams — teammates cannot spawn their own teams or teammates
- Lead is fixed — the session that creates the team leads it for its lifetime
- Permissions set at spawn — all teammates start with the lead's permission mode; changeable individually after spawning
- Split panes require tmux or iTerm2 (not supported in VS Code terminal, Windows Terminal, or Ghostty)

Teammates read `CLAUDE.md` from their working directory — use this to provide project-specific guidance to all teammates.

---

> [!IMPORTANT]
> Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled. Add to settings.json:
> ```json
> { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
> ```
