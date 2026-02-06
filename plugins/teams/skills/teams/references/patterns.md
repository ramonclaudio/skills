# Team Composition Patterns

Pick the pattern that matches the work. Adapt as needed — these are starting points, not liturgy.

**Cost:** Agent teams use significantly more tokens than a single session. Each teammate has its own context window, and total usage scales with the number of active teammates. The overhead is justified when parallelism provides a clear benefit. For routine tasks, a single session is cheaper and faster.

## When NOT to use teams

Use a single session or subagents instead when:
- **Sequential work** — steps must happen in order, no parallelism possible
- **Same-file edits** — multiple changes to one file cause overwrites
- **High dependency** — most tasks block on each other, teammates wait more than they work
- **Small scope** — fewer than 3 files, obvious change

## Teams vs subagents

| | Subagents | Agent teams |
|--|-----------|-------------|
| **Context** | Own window; results return to caller | Own window; fully independent |
| **Communication** | Report back to main agent only | Message each other directly |
| **Coordination** | Main agent manages all work | Shared task list, self-coordination |
| **Best for** | Focused tasks where only the result matters | Complex work requiring discussion between workers |
| **Cost** | Lower — results summarized to main context | Higher — each teammate is a separate instance |

Use subagents when you need quick, focused workers that report back. Use teams when workers need to share findings, challenge each other, and coordinate independently.

---

## Parallel Builders

**When:** New feature spanning multiple modules with clean boundaries.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Decompose, assign, review |
| builder-{module} | sonnet | Implement one module end-to-end |
| test-writer | sonnet | Write tests after builders finish |

**Task flow:** Interface tasks (unblocked) → builder tasks (blocked by interfaces) → test tasks (blocked by builders).

**Example:**
```
Create a team to build the notification system.
- builder-api: owns src/api/notifications/
- builder-ui: owns src/components/notifications/
- builder-data: owns src/db/notifications/
- test-writer: owns tests/notifications/ (blocked by all builders)
```

---

## Review Panel

**When:** Code review, security audit, PR review.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Synthesize findings |
| reviewer-{lens} | opus/sonnet | Review through one lens |

**Task flow:** All reviewers work in parallel (no dependencies). Lead collects and synthesizes.

**Example:**
```
Review PR #142 with three reviewers:
- reviewer-security (opus): auth, injection, data exposure
- reviewer-perf (sonnet): N+1, memory, bundle size
- reviewer-tests (sonnet): coverage gaps, edge cases, assertion quality
```

---

## Research Team

**When:** Evaluating options, investigating architecture, exploring a problem space.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Frame questions, synthesize |
| researcher-{angle} | sonnet | Explore one angle in depth |

**Task flow:** Researchers work in parallel. Lead synthesizes findings, may spawn follow-up researchers.

---

## Adversarial Debug

**When:** Root cause unknown, multiple plausible theories.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Frame hypotheses, judge evidence |
| investigator-{theory} | sonnet | Gather evidence, attempt to disprove other theories |

**Task flow:** Investigators work in parallel. Each tries to prove their theory AND disprove others. The theory that survives scrutiny is likely correct.

Sequential debugging anchors on the first plausible explanation. Parallel adversarial investigation resists that bias.

---

## Cross-Layer

**When:** Changes spanning frontend, backend, database, tests.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Define interfaces between layers |
| data | sonnet | Schema, migrations, queries |
| backend | sonnet | API routes, business logic |
| frontend | sonnet | UI components, client state |
| tests | sonnet | Integration and e2e |

**Task flow:**
```
data ──→ backend ──→ frontend
                         ↓
                      tests (also blocked by backend)
```

Lead defines the interface contracts first. Each layer teammate works within those contracts.

---

## Anti-patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| >5 teammates | Coordination dominates. O(n^2) messaging. | Merge roles. Use subagents for subtasks within a teammate. |
| Overlapping file ownership | Merge conflicts, lost work, silent overwrites | One owner per file. No exceptions. |
| No task graph | Teammates duplicate work or skip work | Always create tasks with dependencies before spawning |
| Vague spawn prompts | Teammates waste tokens exploring the codebase | Include specific file paths, acceptance criteria, and exclusions |
| Lead implements | Teammates sit idle while lead does the work | Use `--delegate` mode. The lead coordinates. |
| No plan approval on risky work | Teammates make irreversible changes | Use `--plan-approval` for schema, API, and infrastructure changes |
| Team for trivial work | Overhead exceeds benefit | If < 3 files change, just do it |
