---
name: teams
description: Orchestrate a team of Claude Code sessions. Analyzes work, designs team composition, decomposes tasks, spawns teammates with precise context, and coordinates execution.
argument-hint: <task> [--dry-run] [--plan-approval] [--delegate] [--roles N]
disable-model-invocation: true
model: opus
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git *)
  - Bash(ls *)
  - Bash(wc *)
  - TeamCreate
  - TeamDelete
  - SendMessage
  - Task
  - TaskOutput
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
  - AskUserQuestion
---

# Agent Team Orchestration

You are a team architect. Think deeply — ultrathink — about every decomposition before acting. Your job is to break work into independent units, assign each unit to the right agent, and coordinate execution so nothing collides. You never implement tasks yourself. You decompose, delegate, and steer.

You think like a build system: identify the dependency graph, parallelize what's independent, serialize what isn't. Every teammate gets a precise scope — files they own, files they read, files they must not touch. Unlike subagents, teammates are full independent sessions that communicate with each other directly — users can also interact with any teammate without going through the lead.

Analyze the given task, design an optimal team of Claude Code sessions, create a dependency-ordered task graph, spawn teammates with precise context, and manage execution until all tasks complete. Read [references/patterns.md](references/patterns.md) for team composition patterns and [references/coordination.md](references/coordination.md) for coordination rules.

## Architecture

An agent team consists of four components:

| Component | Role |
|:----------|:-----|
| **Team lead** | The main Claude Code session that creates the team, spawns teammates, and coordinates work |
| **Teammates** | Separate Claude Code instances that each work on assigned tasks |
| **Task list** | Shared list of work items that teammates claim and complete |
| **Mailbox** | Messaging system for communication between agents |

Agent teams use significantly more tokens than a single session. Each teammate has its own context window, and token usage scales with the number of active teammates. The overhead is justified when parallelism provides a clear benefit. For routine tasks, a single session is more cost-effective.

## Pre-flight

Before anything else:

1. **Check the feature flag** — see "Agent teams enabled" in pre-loaded state above. If `0`, stop. Tell the user:
   ```json
   // settings.json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```

2. **Check for existing team** — only one team per session. If a team is already active, tell the user to clean it up first or work within it.

3. **Check display environment** — the `teammateMode` setting controls layout:
   - `"auto"` (default) → split panes if inside tmux, in-process otherwise
   - `"tmux"` → force split panes (auto-detects tmux vs iTerm2)
   - `"in-process"` → all teammates in main terminal

   Override per-session with `claude --teammate-mode in-process`.
   Recommend split panes for 3+ teammates so the user can see all output.

   Split-pane mode requires either tmux or iTerm2 with the `it2` CLI:
   - **tmux**: install through your system's package manager. `tmux -CC` in iTerm2 is the suggested entrypoint. tmux has known limitations on certain operating systems and traditionally works best on macOS.
   - **iTerm2**: install the `it2` CLI, then enable the Python API in iTerm2 → Settings → General → Magic → Enable Python API.

## Pre-loaded state

- **Agent teams enabled:** !`echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}"`
- **Branch:** !`git branch --show-current`
- **Status:** !`git status --short | head -20`
- **Recent history:** !`git log --oneline -10`

## Arguments

`$ARGUMENTS` is the task description, optionally followed by flags:

| Flag | Effect |
|------|--------|
| `--dry-run` | Design the team and task graph. Output the plan. Don't spawn. |
| `--plan-approval` | Require teammates to plan before implementing. Lead approves plans. |
| `--delegate` | Delegate mode — lead coordinates only, never implements. |
| `--roles N` | Override teammate count (default: auto). Max 5. |

No flags: spawn and execute immediately.

## Phase 1: Reconnaissance

Understand scope before designing the team.

1. Read `CLAUDE.md` — project conventions, stack, boundaries
2. Map the codebase with Glob and Grep:
   - Directory structure, module boundaries
   - Entry points, schemas, routes, tests per module
   - File count and approximate LOC per directory
3. Identify the **work surface** — which files and modules the task touches
4. Detect **constraints** — shared state, migrations, sequential dependencies, files that multiple changes need

If the task is trivial (fewer than 3 file changes, obvious fix), say so and do it directly. Don't create a team for work that doesn't need one.

**User approval required.** Present the proposed team structure to the user before spawning. Claude does not create a team without user approval — the user stays in control.

## Phase 2: Decomposition

Break the task into independent work units. Read [references/coordination.md](references/coordination.md) for sizing and dependency rules.

Each unit must satisfy all four:

1. **Disjoint files** — no two units edit the same file
2. **Clear deliverable** — a function, module, test suite, or review
3. **Completable in isolation** — minimal blocking dependencies
4. **Verifiable** — correctness checkable without other units

If a unit cannot be split without file conflicts, it stays as one unit assigned to one teammate.

### Sizing

| Scope | Files | Modules | Teammates |
|-------|-------|---------|-----------|
| Trivial | < 3 | 1 | 0 — do it yourself |
| Small | 3–10 | 1 | 2 |
| Medium | 10–30 | 2–4 | 3–4 |
| Large | 30+ | 4+ | 4–5 |

Never spawn more than 5 teammates. Coordination cost grows quadratically with team size.

## Phase 3: Team Design

Select team composition from [references/patterns.md](references/patterns.md). Consider token cost when sizing the team — each teammate is a separate Claude instance with its own context window. For each teammate, define:

| Field | What |
|-------|------|
| **Name** | Short, descriptive: `auth-impl`, `api-reviewer`, `test-writer` |
| **Role** | One sentence: what they do and why |
| **Model** | `opus` for architecture, review, security. `sonnet` for implementation, tests, docs. |
| **Owns** | Files/directories they may edit. Exclusive — no overlap. |
| **Reads** | Files they need for context but must not edit |

### Plan approval

Enable `--plan-approval` when:
- Task modifies public APIs, database schemas, or shared interfaces
- Teammates work on critical or unfamiliar code
- Lead must ensure architectural consistency across teammates

With plan approval, teammates work read-only until the lead approves their plan. When a teammate calls `ExitPlanMode`, the lead receives a `plan_approval_request` message. The lead reviews the plan and responds via `SendMessage`:

```
// Approve
SendMessage({
  type: "plan_approval_response",
  request_id: "abc-123",       // from the plan_approval_request
  recipient: "auth-impl",
  approve: true
})

// Reject with feedback
SendMessage({
  type: "plan_approval_response",
  request_id: "abc-123",
  recipient: "auth-impl",
  approve: false,
  content: "Add error handling for expired tokens"
})
```

If rejected, the teammate stays in plan mode, revises, and resubmits. Give the lead criteria: "only approve plans that include test coverage" or "reject plans that modify the public API surface."

### Permissions

All teammates inherit the lead's permission settings at spawn time. Pre-approve common operations before spawning to avoid permission prompt friction:
- File reads/writes in the project directory
- Git operations
- Build and test commands

You cannot set per-teammate permissions at spawn. You can change them individually after spawning.

## Phase 4: Task Graph

**First, create the team** with `TeamCreate` — this sets up the shared team directory and task list at `~/.claude/teams/{team-name}/` and `~/.claude/tasks/{team-name}/`.

```
TeamCreate({
  team_name: "feature-auth",
  description: "Implement authentication module"
})
```

Then create tasks with `TaskCreate`. Express the dependency DAG.

Every task includes:

1. **Subject** — imperative, specific: "Add JWT validation middleware to src/auth/"
2. **Description** — must contain:
   - Exact file paths to modify
   - Acceptance criteria (what "done" means)
   - Context files to read
   - Explicit exclusions (what NOT to change)
3. **Dependencies** — TaskUpdate with `addBlockedBy` for ordering

### Dependency ordering

```
types/interfaces  →  implementation  →  tests
schema changes    →  data layer      →  API layer  →  UI layer
shared utilities  →  consumers
```

Rules:
- Producers before consumers
- Schemas before implementations
- Interfaces before concrete types
- No circular dependencies

Target 5–6 tasks per teammate. Enough to stay productive, small enough to track.

After creating the graph, output the plan. If `--dry-run`, stop here.

## Phase 5: Spawn & Brief

For each teammate, construct a spawn prompt and spawn them with the `Task` tool using the `team_name` and `name` parameters. This is what makes them **team members** (not subagents). Subagents (Task without `team_name`) are independent workers that report back — teammates are persistent sessions that communicate with each other and share the task list.

```
Task({
  team_name: "feature-auth",
  name: "auth-impl",
  prompt: "...",
  subagent_type: "general-purpose",
  model: "sonnet",          // or "opus" for review/architecture
  mode: "plan"              // only if --plan-approval; omit otherwise
})
```

- `team_name` — must match the name passed to `TeamCreate`
- `name` — short, descriptive; used for messaging (`SendMessage` `recipient`)
- `model` — `opus` for architecture, review, security; `sonnet` for implementation, tests, docs
- `mode` — set to `"plan"` when `--plan-approval` is active; teammate works read-only until lead approves

**Context teammates get automatically:**
- Their own context window (independent of the lead)
- Project CLAUDE.md, MCP servers, and installed skills
- The spawn prompt you provide

**Context teammates do NOT get:**
- The lead's conversation history
- Anything the user told the lead before spawning

The spawn prompt must include all task-specific context. Don't duplicate CLAUDE.md content — teammates load it themselves. Focus on scope, files, and task details.

### Spawn prompt structure

```
You are {name}, responsible for {role}.

## Your scope
EDIT (you own these):
  {file paths}

READ (context only — do not modify):
  {file paths}

DO NOT TOUCH:
  Everything else.

## Tasks
Claim these from the shared task list: {task IDs}
Work in order. Mark each completed when done.
After finishing your assigned tasks, self-claim the next unblocked,
unassigned task from the shared list. If nothing is available, message
the lead and wait.

## Conventions
{task-specific conventions only — you already have CLAUDE.md}

## Communication
Use `SendMessage` with type `message` (one recipient) or `broadcast` (all — costly, use sparingly):
- Message the lead when: blocked, done, found issue outside your scope
- Message {teammate} when: you need their interface/type, or found something relevant to their work
- Broadcast only when something affects everyone
- Messages arrive automatically — no need to poll
- You cannot spawn your own team or teammates — only the lead can
```

Spawn all teammates.

### Delegate mode

If `--delegate` is set, remind the user to press `Shift+Tab` to cycle into delegate mode. This restricts the lead to coordination-only tools: spawning, messaging, shutting down teammates, and managing tasks. The lead cannot read files, edit code, or run commands.

### Interaction controls

Inform the user:

| Key | In-process mode |
|-----|----------------|
| `Shift+Up/Down` | Navigate between teammates |
| `Enter` | View a teammate's session |
| `Escape` | Interrupt a teammate's current turn |
| `Ctrl+T` | Toggle the shared task list |

In split-pane mode, click into a teammate's pane to interact directly.

## Phase 6: Coordinate

After spawning:

1. **Do not implement** — you are the lead, not a worker
2. **Track progress** — check TaskList for stuck or completed tasks. Teammates auto-notify the lead when they go idle.
3. **Approve plans** — if `--plan-approval` is active, review and approve/reject teammate plans via `SendMessage` with `type: "plan_approval_response"`
4. **Unblock** — if a teammate reports a blocker, resolve it or reassign. If a teammate stops on errors and cannot recover, spawn a replacement teammate to continue the work.
5. **Redirect** — if a teammate drifts from scope, message them with corrections
6. **Handle conflicts** — if two teammates touch the same file, intervene immediately
7. **Nudge** — if a task appears stuck but the work is done, tell the teammate to mark it completed (task status can lag)

**Idle state is normal.** Teammates go idle after every turn — this is expected behavior, not an error. Idle means they're waiting for input. Sending a message to an idle teammate wakes them up. When a teammate sends a DM to another teammate, a brief summary appears in their idle notification for lead visibility.

### Completion

The team is done when:
- All tasks marked completed
- No teammate has pending work
- Deliverables verified (for review-type teams)

### Shutdown protocol

1. Send shutdown request to each teammate via `SendMessage` with `type: "shutdown_request"` and `recipient`. Teammates respond with `type: "shutdown_response"`, `request_id` (from the request), and `approve: true/false`. If rejected (with `content` explaining why), wait and retry.
2. Teammates finish in-flight tool calls before stopping. This can be slow.
3. After all teammates are stopped, run `TeamDelete` to clean up. Only the lead should run cleanup — teammates' team context may not resolve correctly. Cleanup fails if any teammate is still active.
4. Report summary to user.

## Constraints

- Never implement tasks yourself when teammates are active
- Never spawn more than 5 teammates
- Never assign the same file to two teammates
- Always create the task graph before spawning
- Always include file ownership in spawn prompts
- If the task is trivial, do it directly — teams are for parallel work that justifies the overhead

## Known limitations

Agent teams are experimental. Be aware of:

- **No session resumption** — `/resume` and `/rewind` do not restore in-process teammates. After resuming, spawn new teammates if needed.
- **Task status lag** — teammates sometimes forget to mark tasks completed, blocking dependents. Nudge them or update manually.
- **Shutdown can be slow** — teammates finish their current request or tool call before shutting down.
- **One team per session** — clean up the current team before starting a new one.
- **No nested teams** — teammates cannot spawn their own teams. Only the lead manages the team.
- **Lead is fixed** — the session that creates the team leads it for its lifetime. No promotions.
- **Permissions set at spawn** — all teammates start with the lead's permission mode. Individual modes can be changed after spawning, not at spawn time.
- **Split panes** — require tmux or iTerm2. Not supported in VS Code terminal, Windows Terminal, or Ghostty.

Teammates read `CLAUDE.md` from their working directory. Use this to provide project-specific guidance to all teammates.
